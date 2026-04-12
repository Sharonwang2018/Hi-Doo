/**
 * 火山语音合成 HTTP 非流式：`https://openspeech.bytedance.com/api/v1/tts`
 * - 大模型参数见：https://www.volcengine.com/docs/6561/1257584
 * - 旧版说明见：https://www.volcengine.com/docs/6561/79820
 * 注意：V1 HTTP 不支持部分「语音合成 2.0」音色（如 zh_female_vv_uranus_bigtts），需改用 V3 流式接口。
 */
import { randomUUID } from 'crypto';
import { Router } from 'express';
import { quotaPreCheck } from '../middleware/quota.js';

const OPENAI_TTS_URL = 'https://api.openai.com/v1/audio/speech';
const VOLC_TTS_URL = 'https://openspeech.bytedance.com/api/v1/tts';

const router = Router();

/** 文档限制单次文本 1024 字节（UTF-8），非 1024 字符 */
function truncateUtf8(text, maxBytes) {
  const buf = Buffer.from(text, 'utf8');
  if (buf.length <= maxBytes) return text;
  return buf.subarray(0, maxBytes).toString('utf8');
}

const VOLC_FETCH_MS = Number(process.env.VOLC_TTS_FETCH_TIMEOUT_MS || 90000);

async function synthesizeVolcTts(text) {
  const t0 = Date.now();
  const appid = String(process.env.VOLC_TTS_APP_ID ?? '').trim();
  const token =
    process.env.VOLC_TTS_ACCESS_TOKEN?.trim() || process.env.VOLC_TTS_API_KEY?.trim();
  const cluster = process.env.VOLC_TTS_CLUSTER || 'volcano_tts';
  const voiceType = process.env.VOLC_TTS_VOICE_TYPE || 'BV700_streaming';
  const model = process.env.VOLC_TTS_MODEL?.trim();

  const hasCjk = /[\u4e00-\u9fff]/.test(text);
  // 大模型音色用 explicit_language；旧版精品音（如 BV700_streaming）沿用 language cn/en（79820）
  const legacyBv = /^BV\d+_/i.test(voiceType);
  const audio = {
    voice_type: voiceType,
    encoding: 'mp3',
    speed_ratio: 1.0,
    ...(legacyBv
      ? { language: hasCjk ? 'cn' : 'en' }
      : { explicit_language: hasCjk ? 'zh-cn' : 'en' }),
  };
  const body = {
    app: {
      appid,
      token,
      cluster,
    },
    user: {
      uid: 'echo-reading',
    },
    audio,
    request: {
      reqid: randomUUID(),
      text: truncateUtf8(text, 1024),
      operation: 'query',
      ...(model ? { model } : {}),
    },
  };

  const resp = await fetch(VOLC_TTS_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer;${token}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(Math.max(10000, VOLC_FETCH_MS)),
  });

  const raw = await resp.text();
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    throw new Error(`volc 非 JSON 响应 http=${resp.status} body=${raw.slice(0, 240)}`);
  }
  if (Number(data.code) !== 3000 || !data.data) {
    const msg = data.message || JSON.stringify(data) || resp.statusText;
    throw new Error(msg);
  }

  const buf = Buffer.from(data.data, 'base64');
  console.log(
    `[tts] volc ok ${Date.now() - t0}ms voice=${voiceType} mp3=${buf.length}b logid=${resp.headers.get('x-tt-logid') || '-'}`
  );
  return buf;
}

const OPENAI_TTS_MODEL = process.env.OPENAI_TTS_MODEL?.trim() || 'tts-1';
const OPENAI_TTS_VOICE = process.env.OPENAI_TTS_VOICE?.trim() || 'shimmer';

/** OpenAI Speech: https://platform.openai.com/docs/guides/text-to-speech — input max 4096 chars */
async function synthesizeOpenAiTts(text) {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY missing');
  }
  const t0 = Date.now();
  const input = text.length <= 4096 ? text : text.slice(0, 4096);
  const resp = await fetch(OPENAI_TTS_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: OPENAI_TTS_MODEL,
      input,
      voice: OPENAI_TTS_VOICE,
    }),
    signal: AbortSignal.timeout(Math.max(15000, Number(process.env.OPENAI_TTS_TIMEOUT_MS || 90000))),
  });

  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(err || resp.statusText || String(resp.status));
  }

  const audioBuf = Buffer.from(await resp.arrayBuffer());
  console.log(
    `[tts] openai ok ${Date.now() - t0}ms model=${OPENAI_TTS_MODEL} voice=${OPENAI_TTS_VOICE} bytes=${audioBuf.length}`,
  );
  return audioBuf;
}

router.post('/', quotaPreCheck('tts'), async (req, res, next) => {
  const routeT0 = Date.now();
  try {
    const text = String(req.body?.text ?? '').trim();
    if (!text) {
      return res.status(400).json({ error: 'invalid_text', message: 'text 不能为空' });
    }

    const openaiKey = process.env.OPENAI_API_KEY?.trim();
    if (openaiKey) {
      try {
        const audioBuf = await synthesizeOpenAiTts(text);
        res.set('Content-Type', 'audio/mpeg');
        res.send(audioBuf);
        console.log(`[tts] response sent ${Date.now() - routeT0}ms bytes=${audioBuf.length}`);
        return;
      } catch (e) {
        console.warn('[tts] OpenAI TTS failed, retry once:', e?.message || e);
        try {
          await new Promise((r) => setTimeout(r, 400));
          const audioBuf = await synthesizeOpenAiTts(text);
          res.set('Content-Type', 'audio/mpeg');
          res.send(audioBuf);
          console.log(`[tts] response sent ${Date.now() - routeT0}ms bytes=${audioBuf.length} (retry)`);
          return;
        } catch (e2) {
          console.warn('[tts] OpenAI retry failed, trying Volc if configured:', e2?.message || e2);
        }
      }
    }

    const volcApp = process.env.VOLC_TTS_APP_ID?.trim();
    const volcTok =
      process.env.VOLC_TTS_ACCESS_TOKEN?.trim() || process.env.VOLC_TTS_API_KEY?.trim();
    if (volcApp && volcTok) {
      try {
        const audioBuf = await synthesizeVolcTts(text);
        res.set('Content-Type', 'audio/mpeg');
        res.send(audioBuf);
        console.log(`[tts] response sent ${Date.now() - routeT0}ms bytes=${audioBuf.length}`);
        return;
      } catch (e) {
        console.warn('[tts] 豆包语音失败，重试一次:', e?.message || e);
        try {
          await new Promise((r) => setTimeout(r, 400));
          const audioBuf = await synthesizeVolcTts(text);
          res.set('Content-Type', 'audio/mpeg');
          res.send(audioBuf);
          console.log(`[tts] response sent ${Date.now() - routeT0}ms bytes=${audioBuf.length} (retry)`);
          return;
        } catch (e2) {
          console.warn('[tts] 豆包语音重试仍失败:', e2?.message || e2);
        }
      }
    }

    return res.status(503).json({
      error: 'tts_not_configured',
      message:
        'Configure OPENAI_API_KEY for OpenAI TTS (preferred), or VOLC_TTS_APP_ID + token for Volc. See api/.env.example.',
    });
  } catch (err) {
    console.warn('[tts] error', err?.message || err);
    next(err);
  }
});

export default router;
