/**
 * 对话/视觉：优先火山方舟（豆包），否则 OpenRouter。
 * 方舟需在控制台创建推理接入点，将 ep-xxxx 填为 ARK_*_ENDPOINT_ID。
 */

const ARK_DEFAULT_BASE = 'https://ark.cn-beijing.volces.com/api/v3';
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

function arkChatUrl() {
  const base = (process.env.ARK_BASE_URL || ARK_DEFAULT_BASE).replace(/\/$/, '');
  return `${base}/chat/completions`;
}

/** @returns {{ url: string, apiKey: string, model: string, provider: 'ark' } | { url: string, apiKey: string, model: string, provider: 'openrouter' } | null} */
export function resolveChatProvider() {
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

/** @returns {{ url: string, apiKey: string, model: string, provider: 'ark' } | { url: string, apiKey: string, model: string, provider: 'openrouter' } | null} */
export function resolveVisionProvider() {
  const arkKey = process.env.ARK_API_KEY;
  const arkEp = process.env.ARK_VISION_ENDPOINT_ID || process.env.ARK_ENDPOINT_ID;
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
      model: process.env.OPENROUTER_VISION_MODEL || process.env.OPENROUTER_MODEL || 'openrouter/free',
    };
  }
  return null;
}
