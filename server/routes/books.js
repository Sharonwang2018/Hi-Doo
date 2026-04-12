import { Router } from 'express';
import { query } from '../db.js';
import { v4 as uuidv4 } from 'uuid';
import { optionalAuth } from '../middleware/auth.js';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { isbn } = req.query;
    if (!isbn) {
      return res.status(400).json({ error: 'missing_isbn', message: '需要 isbn 参数' });
    }
    const result = await query(
      'SELECT id, isbn, title, author, cover_url, summary FROM books WHERE isbn = $1',
      [isbn]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found', message: '未找到该书籍' });
    }
    const row = result.rows[0];
    res.json({
      id: row.id,
      isbn: row.isbn,
      title: row.title,
      author: row.author,
      cover_url: row.cover_url,
      summary: row.summary,
    });
  } catch (e) {
    next(e);
  }
});

// 书目元数据（ISBN/书名）为全局表，与具体用户无关；勿强制 JWT，避免访客/过期 token 导致「确认后无法保存」。
router.post('/', optionalAuth, async (req, res, next) => {
  try {
    const { isbn, title, author, cover_url, summary } = req.body || {};
    if (!isbn || !title || !author) {
      return res.status(400).json({ error: 'missing_fields', message: '需要 isbn、title、author' });
    }

    const existing = await query('SELECT id, isbn, title, author, cover_url, summary FROM books WHERE isbn = $1', [isbn]);
    if (existing.rows.length > 0) {
      const row = existing.rows[0];
      await query(
        'UPDATE books SET title = $1, author = $2, cover_url = $3, summary = $4 WHERE id = $5',
        [title, author, cover_url || null, summary || null, row.id]
      );
      return res.json({
        id: row.id,
        isbn: row.isbn,
        title,
        author,
        cover_url: cover_url || row.cover_url,
        summary: summary || row.summary,
      });
    }

    const id = uuidv4();
    await query(
      'INSERT INTO books (id, isbn, title, author, cover_url, summary) VALUES ($1, $2, $3, $4, $5, $6)',
      [id, isbn, title, author, cover_url || null, summary || null]
    );
    res.json({ id, isbn, title, author, cover_url: cover_url || null, summary: summary || null });
  } catch (e) {
    next(e);
  }
});

export default router;
