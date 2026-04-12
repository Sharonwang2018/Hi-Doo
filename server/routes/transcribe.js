import { Router } from 'express';
import FormData from 'form-data';
import multer from 'multer';
import { quotaPreCheck } from '../middleware/quota.js';

// 使用 OpenAI Whisper（OpenRouter 不提供 ASR）
const OPENAI_WHISPER_URL = 'https://api.openai.com/v1/audio/transcriptions';
const router = Router();
const upload = multer({ storage: multer.memoryStorage() });

router.post('/', quotaPreCheck('transcribe'), upload.single('file'), async (req, res, next) => {
  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey || !apiKey.length) {
      return res.status(503).json({
        error: 'transcribe_not_configured',
        message: '请配置 OPENAI_API_KEY 用于语音转写（见 docs）',
      });
    }

    let file = req.file;
    if (!file && req.body?.audio_base64) {
      const buf = Buffer.from(req.body.audio_base64, 'base64');
      file = { buffer: buf, originalname: 'audio.webm', mimetype: req.body.content_type || 'audio/webm' };
    }
    if (!file || !file.buffer || file.buffer.length === 0) {
      return res.status(400).json({ error: 'invalid_audio', message: '请上传音频文件或提供 audio_base64' });
    }

    const form = new FormData();
    form.append('file', file.buffer, {
      filename: file.originalname || 'audio.webm',
      contentType: file.mimetype || 'audio/webm',
    });
    form.append('model', 'whisper-1');
    form.append('response_format', 'text');

    const resp = await fetch(OPENAI_WHISPER_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        ...form.getHeaders(),
      },
      body: form,
    });

    if (resp.status !== 200) {
      const err = await resp.text();
      return res.status(resp.status).json({ error: 'transcribe_failed', message: err || resp.statusText });
    }

    const text = await resp.text();
    res.json({ text: (text || '').trim() });
  } catch (err) {
    next(err);
  }
});

export default router;
