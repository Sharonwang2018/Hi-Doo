import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { authMiddleware, rejectGuestWrite } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, '..', 'uploads');
const AUDIO_DIR = path.join(UPLOAD_DIR, 'audio');

if (!fs.existsSync(AUDIO_DIR)) {
  fs.mkdirSync(AUDIO_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, AUDIO_DIR),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || '.webm';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
});

const router = Router();

router.post('/audio', authMiddleware, upload.single('file'), (req, res, next) => {
  try {
    if (rejectGuestWrite(req, res)) return;
    if (!req.file) {
      return res.status(400).json({ error: 'no_file', message: '未上传文件' });
    }
    const proto = req.get('X-Forwarded-Proto') || req.protocol || 'http';
    const host = req.get('Host') || `localhost:${process.env.PORT || 3000}`;
    const baseUrl = process.env.API_BASE_URL || `${proto}://${host}`;
    const url = `${baseUrl}/audio/${req.file.filename}`;
    res.json({ url, filename: req.file.filename });
  } catch (e) {
    next(e);
  }
});

export default router;
export { AUDIO_DIR };
