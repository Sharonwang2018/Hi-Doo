import './load-env.js';
import express from 'express';
import http from 'http';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
import authRoutes from './routes/auth.js';
import booksRoutes from './routes/books.js';
import readLogsRoutes from './routes/read_logs.js';
import uploadRoutes from './routes/upload.js';
import ttsRoutes from './routes/tts.js';
import chatRoutes from './routes/chat.js';
import visionRoutes from './routes/vision.js';
import transcribeRoutes from './routes/transcribe.js';
import bookLookupRoutes from './routes/book_lookup.js';
import { attachWsToServer } from './routes/asr_stream.js';
import { resolveChatProvider, resolveVisionProvider } from './lib/llm_providers.js';

const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, 'uploads');
const AUDIO_DIR = path.join(UPLOAD_DIR, 'audio');
const WEB_BUILD = path.join(__dirname, '..', 'build', 'web');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
// JSON 体积上限：OCR/vision 会传 base64 图片，默认 100kb 很容易触发 request entity too large
app.use(express.json({ limit: '20mb' }));

// Request logging (skip static assets for readability)
app.use((req, res, next) => {
  if (!req.path.startsWith('/auth') && !req.path.startsWith('/books') && !req.path.startsWith('/read-logs') && !req.path.startsWith('/upload') && !req.path.startsWith('/api/') && req.path !== '/health') return next();
  const t = new Date().toISOString();
  console.log(`[${t}] ${req.method} ${req.path}`);
  next();
});

// API routes (must be before static to avoid conflict)
app.use('/auth', authRoutes);
app.use('/books', booksRoutes);
app.use('/read-logs', readLogsRoutes);
app.use('/upload', uploadRoutes);
app.use('/api/tts', ttsRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/vision', visionRoutes);
app.use('/api/transcribe', transcribeRoutes);
app.use('/api/book-lookup', bookLookupRoutes);
// Serve uploaded audio files
if (!fs.existsSync(AUDIO_DIR)) fs.mkdirSync(AUDIO_DIR, { recursive: true });
app.use('/audio', express.static(AUDIO_DIR));

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

// 配置检查（不暴露 key，仅用于排查）
app.get('/api/status', (req, res) => {
  const chat = resolveChatProvider();
  const vision = resolveVisionProvider();
  res.json({
    ark: !!(process.env.ARK_API_KEY && process.env.ARK_API_KEY.length),
    openrouter: !!(process.env.OPENROUTER_API_KEY && process.env.OPENROUTER_API_KEY.length),
    llm_chat: chat?.provider ?? null,
    llm_vision: vision?.provider ?? null,
    openai: !!(process.env.OPENAI_API_KEY && process.env.OPENAI_API_KEY.length > 0),
  });
});

app.get('/api/asr-stream-ready', (req, res) => {
  // 流式 ASR 已移除豆包，仅支持浏览器语音识别
  res.json({ ok: false });
});

// Serve Flutter web build (UI + API from same origin = Device A always reaches backend)
if (fs.existsSync(path.join(WEB_BUILD, 'index.html'))) {
  app.use(express.static(WEB_BUILD));
  app.get('*', (_req, res) => res.sendFile(path.join(WEB_BUILD, 'index.html')));
}

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_error', message: err.message || '服务器错误' });
});

const useHttps = process.env.HTTPS === '1' || process.env.HTTPS === 'true';
const certDir = path.join(__dirname, 'certs');
const keyPath = path.join(certDir, 'key.pem');
const certPath = path.join(certDir, 'cert.pem');

let server;
if (useHttps && fs.existsSync(keyPath) && fs.existsSync(certPath)) {
  const options = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath),
    // 兼容 macOS LibreSSL / 老旧客户端
    minVersion: 'TLSv1.2',
    maxVersion: 'TLSv1.3',
  };
  server = https.createServer(options, app);
} else {
  if (useHttps) {
    console.warn('HTTPS requested but certs missing. Run: ./scripts/gen_certs.sh');
  }
  server = http.createServer(app);
}
server.listen(PORT, '0.0.0.0', () => {
  attachWsToServer(server);
  const chat = resolveChatProvider();
  const vision = resolveVisionProvider();
  console.log(useHttps
    ? `Hi-Doo HTTPS at https://10.0.0.138:${PORT}`
    : `Hi-Doo API at http://10.0.0.138:${PORT}`);
  console.log(`LLM 对话/点评: ${chat ? `${chat.provider} (${chat.model})` : '未配置'}`);
  console.log(`LLM 拍照读页: ${vision ? `${vision.provider} (${vision.model})` : '未配置'}`);
});
