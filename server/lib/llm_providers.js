/**
 * LLM routing: **Groq first** when GROQ_API_KEY is set (US-friendly default).
 * Fallback: Volcengine Ark, then OpenRouter.
 */

const ARK_DEFAULT_BASE = 'https://ark.cn-beijing.volces.com/api/v3';
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

function arkChatUrl() {
  const base = (process.env.ARK_BASE_URL || ARK_DEFAULT_BASE).replace(/\/$/, '');
  return `${base}/chat/completions`;
}

/** @returns {{ url: string, apiKey: string, model: string, provider: 'groq' } | { url: string, apiKey: string, model: string, provider: 'ark' } | { url: string, apiKey: string, model: string, provider: 'openrouter' } | null} */
export function resolveChatProvider() {
  const groqKey = process.env.GROQ_API_KEY?.trim();
  if (groqKey) {
    return {
      provider: 'groq',
      url: GROQ_URL,
      apiKey: groqKey,
      model: (process.env.GROQ_MODEL || 'llama-3.3-70b-versatile').trim(),
    };
  }
  const arkKey = process.env.ARK_API_KEY;
  const arkEp = process.env.ARK_CHAT_ENDPOINT_ID || process.env.ARK_ENDPOINT_ID;
  if (arkKey && arkEp) {
    return {
      provider: 'ark',
      url: arkChatUrl(),
      apiKey: arkKey,
      model: arkEp,
    };
  }
  const orKey = process.env.OPENROUTER_API_KEY;
  if (orKey) {
    return {
      provider: 'openrouter',
      url: OPENROUTER_URL,
      apiKey: orKey,
      model: process.env.OPENROUTER_MODEL || 'google/gemma-3-27b-it:free',
    };
  }
  return null;
}
