import http from 'http';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { app } from './app.js';
import { attachWsToServer } from './routes/asr_stream.js';
import { resolveChatProvider } from './lib/llm_providers.js';
import { quotaEnabled } from './lib/usage_quota.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 3000;

const useHttps = process.env.HTTPS === '1' || process.env.HTTPS === 'true';
const certDir = path.join(__dirname, 'certs');
const keyPath = path.join(certDir, 'key.pem');
const certPath = path.join(certDir, 'cert.pem');

let server;
if (useHttps && fs.existsSync(keyPath) && fs.existsSync(certPath)) {
  const options = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath),
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
  const publicBase = process.env.PUBLIC_BASE_URL?.trim();
  const displayUrl =
    publicBase || (useHttps ? `https://localhost:${PORT}` : `http://localhost:${PORT}`);
  console.log(`Hi-Doo | Think & Retell → ${displayUrl}`);
  console.log(`LLM chat/review: ${chat ? `${chat.provider} (${chat.model})` : 'not configured'}`);
  console.log(
    quotaEnabled()
      ? 'API quota: ON (set QUOTA_* limits in .env)'
      : 'API quota: OFF (default; set QUOTA_ENABLED=1 to enable daily limits)',
  );
});
