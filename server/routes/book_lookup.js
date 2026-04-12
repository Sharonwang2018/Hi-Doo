/**
 * 浏览器直连 Open Library 在部分移动网络 / WebKit 下会 ClientException: Load failed；
 * 由服务端代请求，客户端只访问同源 /api/book-lookup。
 */
import { Router } from 'express';

const router = Router();

const FETCH_MS = Math.max(5000, Number(process.env.OPENLIBRARY_FETCH_TIMEOUT_MS || 20000));

router.get('/', async (req, res, next) => {
  try {
    const isbn = String(req.query.isbn || '').trim();
    if (!isbn) {
      return res.status(400).json({ error: 'missing_isbn', message: '需要 isbn 参数' });
    }

    const url = `https://openlibrary.org/api/books?bibkeys=ISBN:${encodeURIComponent(isbn)}&format=json&jscmd=data`;
    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), FETCH_MS);
    let r;
    try {
      r = await fetch(url, {
        signal: ac.signal,
        headers: { Accept: 'application/json' },
      });
    } finally {
      clearTimeout(timer);
    }

    if (!r.ok) {
      console.warn(`[book-lookup] openlibrary http=${r.status} isbn=${isbn}`);
      return res.status(502).json({
        error: 'openlibrary_http',
        message: `Open Library 返回 ${r.status}`,
      });
    }

    const data = await r.json();
    const key = `ISBN:${isbn}`;
    const rawBook = data[key];
    if (!rawBook || typeof rawBook !== 'object') {
      return res.status(404).json({ error: 'not_found', message: 'Open Library 无此 ISBN' });
    }

    const title = String(rawBook.title || '').trim();
    if (!title) {
      return res.status(404).json({ error: 'not_found', message: '无书名' });
    }

    const authors = Array.isArray(rawBook.authors)
      ? rawBook.authors.map((a) => (a && typeof a === 'object' ? String(a.name || '').trim() : '')).filter(Boolean)
      : [];

    const cover = rawBook.cover && typeof rawBook.cover === 'object' ? rawBook.cover : {};
    const descriptionRaw = rawBook.notes ?? rawBook.description;
    let summary = null;
    if (typeof descriptionRaw === 'string') {
      summary = descriptionRaw.trim();
    } else if (descriptionRaw && typeof descriptionRaw === 'object' && descriptionRaw.value != null) {
      summary = String(descriptionRaw.value).trim();
    }

    const coverUrl = cover.large || cover.medium || cover.small || null;

    res.json({
      isbn,
      title,
      author: authors.length ? authors.join(', ') : 'Unknown Author',
      cover_url: coverUrl,
      summary: summary && summary.length ? summary : 'No summary available.',
    });
  } catch (e) {
    if (e?.name === 'AbortError') {
      return res.status(504).json({ error: 'openlibrary_timeout', message: '查询 Open Library 超时' });
    }
    next(e);
  }
});

export default router;
