import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();

/**
 * User-reported quiz / MCQ content issues (for review and model improvement).
 * Body: { book_id: string, question_id: number (1-based slot), bad_content: boolean }
 */
router.post('/', authMiddleware, (req, res) => {
  const { book_id, question_id, bad_content } = req.body || {};

  if (book_id == null || typeof book_id !== 'string' || book_id.trim().length === 0) {
    return res.status(400).json({
      error: 'invalid_book_id',
      message: 'book_id is required',
    });
  }

  const qid = Number(question_id);
  if (!Number.isFinite(qid) || qid < 1 || qid > 99) {
    return res.status(400).json({
      error: 'invalid_question_id',
      message: 'question_id must be a number from 1 to 99',
    });
  }

  const flag = bad_content === true || bad_content === 'true';
  if (!flag) {
    return res.status(400).json({
      error: 'invalid_bad_content',
      message: 'bad_content must be true for a content report',
    });
  }

  const payload = {
    type: 'quiz_content_report',
    user_id: req.userId,
    is_guest: req.isGuest === true,
    book_id: book_id.trim(),
    question_id: qid,
    bad_content: true,
    at: new Date().toISOString(),
  };
  console.log('[quiz_report]', JSON.stringify(payload));

  return res.status(200).json({ ok: true });
});

export default router;
