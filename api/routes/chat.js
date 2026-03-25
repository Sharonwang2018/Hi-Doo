import { Router } from 'express';
import { resolveChatProvider } from '../lib/llm_providers.js';

const router = Router();

router.post('/', async (req, res, next) => {
  try {
    const cfg = resolveChatProvider();
    if (!cfg) {
      console.warn('[chat] 未配置 ARK_* 或 OPENROUTER_API_KEY，请检查 api/.env');
      return res.status(503).json({
        error: 'chat_not_configured',
        message: '请配置火山方舟 ARK_API_KEY + ARK_ENDPOINT_ID，或 OPENROUTER_API_KEY（见 docs）',
      });
    }

    const { messages, temperature = 0.6, max_tokens: maxTokensBody } = req.body || {};
    const max_tokens =
      typeof maxTokensBody === 'number' && maxTokensBody > 0
        ? Math.min(4096, Math.floor(maxTokensBody))
        : 1024;
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'invalid_messages', message: 'messages 不能为空' });
    }

    const resp = await fetch(cfg.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${cfg.apiKey}`,
      },
      body: JSON.stringify({ model: cfg.model, messages, temperature, max_tokens }),
    });
    const data = await resp.json();
    if (resp.status !== 200) {
      const msg = data?.error?.message || data?.message || resp.statusText;
      console.warn('[chat] LLM 错误:', cfg.provider, resp.status, msg);
      return res.status(resp.status).json({ error: 'chat_failed', message: msg });
    }
    const content = data?.choices?.[0]?.message?.content?.trim() ?? '';
    res.json({ content });
  } catch (err) {
    next(err);
  }
});

export default router;
