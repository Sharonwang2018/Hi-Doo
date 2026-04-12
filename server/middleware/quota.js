import { optionalAuth } from './auth.js';
import { checkQuota, consumeQuota } from '../lib/usage_quota.js';

const kindLabels = {
  transcribe: 'transcription',
  tts: 'read-aloud',
  chat: 'chat / feedback',
  assessment: 'guided questions / listener (Groq)',
};

/**
 * optionalAuth, then daily quota; consume on response finish by status code.
 * @param {'transcribe'|'tts'|'chat'|'assessment'} kind
 */
export function quotaPreCheck(kind) {
  return (req, res, next) => {
    optionalAuth(req, res, () => {
      const q = checkQuota(req, kind);
      if (!q.ok) {
        return res.status(429).json({
          error: 'quota_exceeded',
          message: q.message || `今日${kindLabels[kind] || kind}次数已用完`,
          kind,
          limit: q.limit,
          used: q.used,
        });
      }
      res.once('finish', () => {
        consumeQuota(req, kind, res.statusCode);
      });
      next();
    });
  };
}
