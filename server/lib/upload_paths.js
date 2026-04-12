import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let _cached = null;

/**
 * Resolves upload root and `audio` subdirectory.
 * On Vercel the filesystem under `/var/task` is read-only; default to `os.tmpdir()`.
 */
export function resolveUploadDirs() {
  if (_cached) return _cached;

  const onVercel = process.env.VERCEL === '1';
  let uploadDir = process.env.UPLOAD_DIR?.trim();

  if (!uploadDir) {
    uploadDir = onVercel
      ? path.join(os.tmpdir(), 'hi-doo-uploads')
      : path.join(__dirname, '..', 'uploads');
  } else if (!path.isAbsolute(uploadDir)) {
    uploadDir = path.resolve(process.cwd(), uploadDir);
  }

  const audioDir = path.join(uploadDir, 'audio');
  _cached = { uploadDir, audioDir, onVercel };
  return _cached;
}

export function getAudioDir() {
  return resolveUploadDirs().audioDir;
}

/** Create `audio` directory if missing (safe on Vercel when under `/tmp`). */
export function ensureAudioDir() {
  const { audioDir } = resolveUploadDirs();
  if (!fs.existsSync(audioDir)) {
    fs.mkdirSync(audioDir, { recursive: true });
  }
  return audioDir;
}
