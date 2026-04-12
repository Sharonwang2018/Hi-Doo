import './load-env.js';
import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';

import booksRoutes from './routes/books.js';
import readLogsRoutes from './routes/read_logs.js';
import uploadRoutes from './routes/upload.js';
import ttsRoutes from './routes/tts.js';
import chatRoutes from './routes/chat.js';
import assessmentRoutes from './routes/assessment.js';
import transcribeRoutes from './routes/transcribe.js';
import bookLookupRoutes from './routes/book_lookup.js';
import quizReportsRoutes from './routes/quiz_reports.js';
import { resolveChatProvider } from './lib/llm_providers.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, 'uploads');
const AUDIO_DIR = path.join(UPLOAD_DIR, 'audio');
const WEB_BUILD = path.join(__dirname, '..', 'build', 'web');

const app = express();

// Vercel `rewrites` → `/api` can leave `req.url` as `/api`; restore the browser path for Express routing.
if (process.env.VERCEL === '1') {
  app.use((req, _res, next) => {
    const raw = req.headers['x-vercel-original-url'];
    if (typeof raw === 'string' && raw.startsWith('/') && (req.url === '/api' || req.url?.startsWith('/api?'))) {
      try {
        const u = new URL(raw, 'http://localhost');
        req.url = u.pathname + (u.search || '');
      } catch {
        /* keep req.url */
      }
    }
    next();
  });
}

if (!process.env.SUPABASE_JWT_SECRET?.trim()) {
  console.warn(
    '⚠️  SUPABASE_JWT_SECRET missing — /read-logs, /upload, etc. return 503 until set (Supabase Dashboard → API → JWT Secret).',
  );
}

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// Request logging (skip static assets for readability)
app.use((req, res, next) => {
  if (
    !req.path.startsWith('/books') &&
    !req.path.startsWith('/read-logs') &&
    !req.path.startsWith('/upload') &&
    !req.path.startsWith('/api/') &&
    req.path !== '/health'
  ) {
    return next();
  }
  const t = new Date().toISOString();
  console.log(`[${t}] ${req.method} ${req.path}`);
  next();
});

app.use('/books', booksRoutes);
app.use('/read-logs', readLogsRoutes);
app.use('/upload', uploadRoutes);
app.use('/api/tts', ttsRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/assessment', assessmentRoutes);
app.use('/api/transcribe', transcribeRoutes);
app.use('/api/book-lookup', bookLookupRoutes);
app.use('/api/quiz-reports', quizReportsRoutes);

if (!fs.existsSync(AUDIO_DIR)) fs.mkdirSync(AUDIO_DIR, { recursive: true });
app.use('/audio', express.static(AUDIO_DIR));

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/api/status', (req, res) => {
  const chat = resolveChatProvider();
  const groqKey = !!(process.env.GROQ_API_KEY && process.env.GROQ_API_KEY.trim().length > 0);
  res.json({
    ark: !!(process.env.ARK_API_KEY && process.env.ARK_API_KEY.length),
    openrouter: !!(process.env.OPENROUTER_API_KEY && process.env.OPENROUTER_API_KEY.length),
    groq: groqKey,
    groq_assessment: groqKey,
    llm_chat: chat?.provider ?? null,
    openai: !!(process.env.OPENAI_API_KEY && process.env.OPENAI_API_KEY.length > 0),
  });
});

app.get('/api/asr-stream-ready', (req, res) => {
  res.json({ ok: false });
});

// Local Node: serve Flutter build from disk. Vercel: static files come from outputDirectory + CDN.
const indexPath = path.join(WEB_BUILD, 'index.html');
const onVercel = process.env.VERCEL === '1';
if (!onVercel && fs.existsSync(indexPath)) {
  const indexStat = fs.statSync(indexPath);
  console.log(
    `Flutter UI: ${WEB_BUILD} (index.html ${indexStat.mtime.toISOString()}) — after Dart/UI edits run: flutter build web`,
  );
  app.use(
    express.static(WEB_BUILD, {
      setHeaders(res, filePath) {
        const base = path.basename(filePath);
        if (base === 'index.html' || base === 'flutter_bootstrap.js') {
          res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        }
      },
    }),
  );
  app.get('*', (_req, res) => {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.sendFile(indexPath);
  });
} else if (!onVercel) {
  console.warn(`No Flutter bundle at ${WEB_BUILD} — run "flutter build web" from repo root, then restart.`);
}

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_error', message: err.message || 'Server error' });
});

export { app };
