/**
 * 火山语音合成 HTTP 非流式：`https://openspeech.bytedance.com/api/v1/tts`
 * - 大模型参数见：https://www.volcengine.com/docs/6561/1257584
 * - 旧版说明见：https://www.volcengine.com/docs/6561/79820
 * 注意：V1 HTTP 不支持部分「语音合成 2.0」音色（如 zh_female_vv_uranus_bigtts），需改用 V3 流式接口。
 */
import { randomUUID } from 'crypto';
import { Router } from 'express';

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

router.post('/', async (req, res, next) => {
  const routeT0 = Date.now();
  try {
    const text = String(req.body?.text ?? '').trim();
    if (!text) {
      return res.status(400).json({ error: 'invalid_text', message: 'text 不能为空' });
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
          console.warn('[tts] 豆包语音重试仍失败，尝试 OpenAI:', e2?.message || e2);
        }
      }
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey || !apiKey.length) {
      return res.status(503).json({
        error: 'tts_not_configured',
        message:
          '请配置豆包语音 VOLC_TTS_APP_ID +（VOLC_TTS_ACCESS_TOKEN 或 VOLC_TTS_API_KEY），或 OPENAI_API_KEY（见 docs）',
      });
    }

    const resp = await fetch(OPENAI_TTS_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'tts-1',
        input: text,
        voice: 'alloy',
      }),
    });

    if (!resp.ok) {
      const err = await resp.text();
      return res.status(resp.status).json({ error: 'tts_failed', message: err || resp.statusText });
    }

    const audioBuf = Buffer.from(await resp.arrayBuffer());
    res.set('Content-Type', 'audio/mpeg');
    res.send(audioBuf);
    console.log(`[tts] openai ok ${Date.now() - routeT0}ms bytes=${audioBuf.length}`);
  } catch (err) {
    console.warn('[tts] error', err?.message || err);
    next(err);
  }
});

export default router;
