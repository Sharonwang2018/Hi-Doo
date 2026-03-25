import { Router } from 'express';
import { resolveVisionProvider } from '../lib/llm_providers.js';

const router = Router();

router.post('/', async (req, res, next) => {
  const cfg = resolveVisionProvider();
  console.log('[vision] 开始识别, provider=', cfg?.provider, 'model=', cfg?.model, 'imageSize=', req.body?.image?.length || 0);
  try {
    if (!cfg) {
      return res.status(503).json({
        error: 'vision_not_configured',
        message: '请配置火山方舟 ARK_API_KEY + ARK_ENDPOINT_ID（或 ARK_VISION_ENDPOINT_ID），或配置 OPENROUTER_API_KEY（见 docs）',
      });
    }

    const imageBase64 = req.body?.image;
    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return res.status(400).json({ error: 'invalid_image', message: '请提供 image (base64)' });
    }

    const imageUrl = imageBase64.startsWith('data:') ? imageBase64 : `data:image/jpeg;base64,${imageBase64}`;
    const messages = [
      {
        role: 'user',
        content: [
          { type: 'image_url', image_url: { url: imageUrl } },
          {
            type: 'text',
            text: 'Act as an OCR engine. Output only story/dialogue/body text on the page, line by line. Skip page numbers, corner numbers, ISBN, copyright, publisher boilerplate, and headers like "第x页". NO reasoning. NO markdown. Plain text only.',
          },
        ],
      },
    ];

    const resp = await fetch(cfg.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${cfg.apiKey}`,
      },
      body: JSON.stringify({ model: cfg.model, messages, max_tokens: 2048 }),
    });
    const data = await resp.json();
    if (resp.status !== 200) {
      const msg = data?.error?.message || data?.message || JSON.stringify(data?.error) || resp.statusText;
      console.log('[vision] LLM 失败 status=', resp.status, 'msg=', msg);
      return res.status(resp.status).json({ error: 'vision_failed', message: msg });
    }
    const msg = data?.choices?.[0]?.message;
    let text = (msg?.content ?? '').trim();
    if (!text) {
      const r = msg?.reasoning ?? msg?.reasoning_details?.[0]?.text ?? '';
      if (r) {
        const str = String(r);
        const match = str.match(/(?:可能的文字提取顺序|文字提取顺序|提取顺序|extraction order|text to extract)[：:\s]*([\s\S]+?)(?:\n\n|$)/i);
        const block = match ? match[1] : str;
        const lines = block.split(/\n+/)
          .map((s) => s.replace(/^[-*]\s*/, '').replace(/\s*[（(][^)）]*[)）]\s*$/, '').trim())
          .filter((s) => s.length > 0 && s.length < 200);
        if (lines.length > 0) text = lines.join('\n');
      }
    }
    if (!text) {
      console.log('[vision] 模型返回空内容 model=', cfg.model, 'finish_reason=', msg?.finish_reason);
      return res.status(422).json({ error: 'no_text', message: '未识别到文字内容' });
    }
    console.log('[vision] 识别成功 len=', text.length);
    res.json({ text });
  } catch (err) {
    console.log('[vision] 异常:', err?.message || err);
    next(err);
  }
});

export default router;
