import { Router } from 'express';
import { resolveChatProvider } from '../lib/llm_providers.js';
import { quotaPreCheck } from '../middleware/quota.js';

const router = Router();

router.post('/', quotaPreCheck('chat'), async (req, res, next) => {
  try {
    const cfg = resolveChatProvider();
    if (!cfg) {
      console.warn('[chat] No LLM: set GROQ_API_KEY (recommended) or ARK_* / OPENROUTER_API_KEY');
      return res.status(503).json({
        error: 'chat_not_configured',
        message:
          'Configure GROQ_API_KEY, or ARK_* / OPENROUTER_API_KEY. See api/.env.example.',
      });
    }

    const { messages, temperature = 0.6, max_tokens: maxTokensBody } = req.body || {};
    const max_tokens =
      typeof maxTokensBody === 'number' && maxTokensBody > 0
        ? Math.min(4096, Math.floor(maxTokensBody))
        : 1024;
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'invalid_messages', message: 'messages array is required.' });
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
      console.warn('[chat] LLM error:', cfg.provider, resp.status, msg);
      return res.status(resp.status).json({ error: 'chat_failed', message: msg });
    }
    const content = data?.choices?.[0]?.message?.content?.trim() ?? '';
    res.json({ content });
  } catch (err) {
    next(err);
  }
});

export default router;
