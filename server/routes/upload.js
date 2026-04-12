import { Router } from 'express';
import fs from 'fs';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { authMiddleware, rejectGuestWrite } from '../middleware/auth.js';
import { ensureAudioDir, getAudioDir } from '../lib/upload_paths.js';

const AUDIO_DIR = getAudioDir();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
});

const router = Router();

router.post('/audio', authMiddleware, upload.single('file'), (req, res, next) => {
  try {
    if (rejectGuestWrite(req, res)) return;
    const file = req.file;
    if (!file?.buffer?.length) {
      return res.status(400).json({ error: 'no_file', message: '未上传文件' });
    }

    const ext = path.extname(file.originalname) || '.webm';
    const filename = `${uuidv4()}${ext}`;
    const dir = ensureAudioDir();
    const destPath = path.join(dir, filename);
    fs.writeFileSync(destPath, file.buffer);

    const proto = req.get('X-Forwarded-Proto') || req.protocol || 'http';
    const host = req.get('Host') || `localhost:${process.env.PORT || 3000}`;
    const baseUrl = process.env.API_BASE_URL || `${proto}://${host}`;
    const url = `${baseUrl}/audio/${filename}`;
    res.json({ url, filename });
  } catch (e) {
    next(e);
  }
});

export default router;
export { AUDIO_DIR };
