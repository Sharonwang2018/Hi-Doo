import { Router } from 'express';
import { quotaPreCheck } from '../middleware/quota.js';

const router = Router();
const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

function groqConfig() {
  const apiKey = process.env.GROQ_API_KEY?.trim();
  // Default: Groq-supported Llama 3.3 70B (llama3-70b-8192 deprecated). Override with GROQ_MODEL.
  const model = (process.env.GROQ_MODEL || 'llama-3.3-70b-versatile').trim();
  if (!apiKey) return null;
  return { apiKey, model };
}

function stripJsonFence(raw) {
  let s = String(raw ?? '').trim();
  if (s.startsWith('```')) {
    const firstNl = s.indexOf('\n');
    if (firstNl !== -1) s = s.slice(firstNl + 1);
    const end = s.indexOf('```');
    if (end !== -1) s = s.slice(0, end).trim();
  }
  if (s.toLowerCase().startsWith('json')) s = s.slice(4).trim();
  return s;
}

const SYSTEM_RETELLING_LISTENER = `You are a curious, encouraging listener helping a child practice retelling a story—not an examiner or harsh critic. Your tone supports the same literacy goals as CCSS Speaking & Listening in the early grades: clear expression, recalling details, and building on ideas in conversation.

Rules:
- Write in English only.
- Sound genuinely interested: brief warm reaction + one natural follow-up that nudges them to say more (like: "That sounds interesting! What happened after the boy found the key?").
- Do NOT scold or list mistakes. Stay positive and conversational (2–5 short sentences total, easy to read aloud).
- You may use the book summary only as quiet context; focus feedback on what the child actually said.
- Do not cite standard numbers or say "Common Core" in the reply—keep it natural for a child and family.

Return ONLY valid JSON:
{"comment":"<your listener response>","logic_score":<integer 1-5>}

logic_score: 1–5 for overall retelling effort and coherence (5 = strong, clear; 1 = very brief or unclear)—judge gently for elementary age.`;

const SYSTEM_BOOK_QUIZ = `You are a FUN READING COACH for U.S. grades 1–3 (ages ~6–8): playful, simple, never stuffy. You do NOT have the full book text—only title, optional summary, and metadata from the user message.

LANGUAGE (mandatory): Regardless of the language of any input fields, EVERY user-facing string you output in JSON must be ENGLISH only: key_facts, book_context, every quiz "question", every "options" string, and every "explanation".

PRIORITY: Almost always produce a quiz. If the summary is very short or empty after removing catalog placeholders, you MUST still write 3 fun, easy MCQs using (a) any real detail from the summary AND/OR (b) the book title to ask fair, grade-1–3-appropriate questions grounded in obvious real-world or "type of book" common sense (e.g. a title about dinosaurs → simple dino-themed questions; a famous fairy-tale title → very generic, non-spoiler questions about that kind of tale). Do NOT invent specific plot scenes that a reader would only know from reading the book—stay with title + summary + safe general knowledge.

quiz_unavailable: Return this ONLY when the title is missing or not a usable book title AND the summary is empty or a useless placeholder—i.e. you truly cannot form any reasonable, honest questions. If there is ANY recognizable title topic, prefer 3 simple English questions over quiz_unavailable.

QUIZ STYLE:
- Wording: very short sentences, concrete, maybe a tiny bit silly or game-like—still clear for early readers.
- Three levels: (1) Literal easy win, (2) simple inferential "why/how" still tied to your key_facts, (3) light feelings or connection—still grounded.
- Each MCQ: exactly 3 options (A/B/C). "answer" is exactly "A", "B", or "C".
- NEVER ask about the author, ISBN, or catalog metadata. No meta-questions about "summary" or "description" existing.

explanation (each item): A SHORT encouraging mini-comment in English—one or two brief sentences max (roughly under 220 characters). Cheer the child, confirm why the chosen letter fits, and do NOT contradict the letter in "answer". Do not write long paragraphs.

MANDATORY JSON ORDER:
1) "key_facts": 1–3 short English strings you can honestly support from summary and/or title (and safe common sense when summary is tiny).
2) "book_context": one short English sentence.
3) "quiz": exactly 3 objects with id 1 Literal, 2 Inferential, 3 Emotional; each has question, options (3 strings), answer, explanation.

RESPONSE FORMAT (JSON ONLY, no markdown):
{
  "key_facts": ["...", "..."],
  "book_context": "...",
  "quiz": [
    { "id": 1, "level": "Literal", "question": "...", "options": ["A) ...", "B) ...", "C) ..."], "answer": "A", "explanation": "Short upbeat English—one or two sentences." },
    { "id": 2, "level": "Inferential", "question": "...", "options": ["A) ...", "B) ...", "C) ..."], "answer": "B", "explanation": "..." },
    { "id": 3, "level": "Emotional", "question": "...", "options": ["A) ...", "B) ...", "C) ..."], "answer": "C", "explanation": "..." }
  ]
}

If and ONLY if you cannot form any honest quiz per quiz_unavailable rule above, respond ONLY with:
{"quiz_unavailable":true,"fallback_message":"I'm still learning about this story, let's try a Retell challenge instead!","book_context":"","key_facts":[],"quiz":[]}`;

const SYSTEM_BOOK_STORYTELLER = `Act as a warm listener helping a child retell a story—not an examiner.
You only know the book title, author, and optional catalog summary—not the full text. Never invent page-specific plot you cannot support.

Output ONLY valid JSON (no markdown):
{
  "coach_intro": "<one very short encouraging line (max ~12 words), English>",
  "retelling_prompt": "<ONE central inviting question only, e.g. Can you tell me what happened in the story from beginning to end?>",
  "retelling_keywords": ["First", "Next", "Then", "Finally"],
  "questions": [],
  "retelling_hints": []
}

Rules:
- retelling_prompt: exactly ONE child-friendly question in English—no bullet list, no multiple separate prompts.
- retelling_keywords: exactly 4 short scaffold words in order: First, Next, Then, Finally (those words only unless a synonym is equally simple).
- retelling_hints: always [] (do not use).
- English only; warm and simple for ages roughly 5–10.`;

const SYSTEM_BOOK_BOTH = `You combine two roles: (1) the same FUN grade 1–3 English reading coach as in the quiz-only system for MCQs, and (2) a warm retelling listener. You only know title, author, optional summary—not full page text.

1) Quiz: All quiz strings MUST be ENGLISH. Use playful, simple MCQs; explanations are short encouraging English (one or two brief sentences each). If summary is very thin, still build 3 questions from title + any summary + safe common sense—avoid quiz_unavailable unless the title is unusable and summary is empty (same bar as quiz-only). Never quiz author/ISBN/catalog meta.

2) Storyteller: retelling_prompt = ONE central inviting question in English; retelling_keywords: ["First","Next","Then","Finally"]; retelling_hints: [].

RESPONSE FORMAT (JSON ONLY, no markdown):
{
  "key_facts": ["...", "..."],
  "book_context": "...",
  "quiz": [ { "id": 1, "level": "Literal", "question": "...", "options": ["A) ...","B) ...","C) ..."], "answer": "A", "explanation": "..." }, ... 3 total ... ],
  "retelling_prompt": "<ONE central question>",
  "retelling_keywords": ["First", "Next", "Then", "Finally"],
  "retelling_hints": []
}`;

function truncateText(s, max) {
  const t = String(s ?? '').trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max)}\n…`;
}

/** Strip only whole-string catalog placeholders; pass through short real summaries (e.g. ~20 chars of story text). */
function summaryTextForQuiz(raw) {
  const t = String(raw ?? '').trim();
  if (!t) return '';
  const normalized = t.replace(/\s+/g, ' ').trim();
  if (/^no summary available\.?\s*$/i.test(normalized)) return '';
  return t;
}

function normalizeMcqItem(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const question = String(raw.question ?? raw.prompt ?? '').trim();
  let options = Array.isArray(raw.options)
    ? raw.options.map((x) => String(x ?? '').trim()).filter((s) => s.length > 0)
    : [];
  if (options.length < 3 && raw.a != null) {
    const a = String(raw.a).trim();
    const b = String(raw.b).trim();
    const c = String(raw.c).trim();
    if (a && b && c) options = [a, b, c];
  }
  if (options.length !== 3 || !question) return null;
  let ci = Number(raw.correct_index);
  if (!Number.isFinite(ci)) {
    const L = String(raw.correct ?? '').trim().toUpperCase();
    if (L === 'A') ci = 0;
    else if (L === 'B') ci = 1;
    else if (L === 'C') ci = 2;
    else return null;
  } else {
    ci = Math.round(ci);
    if (ci < 0 || ci > 2) return null;
  }
  return { question, options, correct_index: ci };
}

function normalizeMcqList(arr) {
  if (!Array.isArray(arr)) return [];
  return arr.map(normalizeMcqItem).filter(Boolean);
}

function stripMcqOptionLabel(s) {
  let t = String(s ?? '').trim();
  const m = t.match(/^([ABC])[\).\s]\s*/i);
  if (m) t = t.slice(m[0].length).trim();
  return t;
}

function normalizeReadingCoachQuizItem(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const question = String(raw.question ?? '').trim();
  let options = Array.isArray(raw.options)
    ? raw.options.map(stripMcqOptionLabel).filter((s) => s.length > 0)
    : [];
  if (options.length !== 3 || !question) return null;
  const ansRaw = String(raw.answer ?? raw.correct ?? '')
    .trim()
    .toUpperCase()
    .replace(/[^ABC]/g, '');
  const letter = ansRaw.charAt(0);
  let ci;
  if (letter === 'A') ci = 0;
  else if (letter === 'B') ci = 1;
  else if (letter === 'C') ci = 2;
  else return null;
  const explanation = String(raw.explanation ?? '').trim();
  const level = String(raw.level ?? '').trim();
  const out = { question, options, correct_index: ci };
  if (explanation) out.explanation = explanation;
  if (level) out.level = level;
  return out;
}

function normalizeReadingCoachQuizList(quizArr) {
  if (!Array.isArray(quizArr)) return [];
  const paired = quizArr
    .map((raw) => {
      const id = Number(raw?.id);
      const item = normalizeReadingCoachQuizItem(raw);
      return { id: Number.isFinite(id) ? id : 1e9, item };
    })
    .filter((p) => p.item);
  paired.sort((a, b) => a.id - b.id);
  return paired.map((p) => p.item);
}

/** Min length for each quiz explanation (attempts 0–1); final attempt skips this check. */
const MIN_QUIZ_EXPLANATION_CHARS = 12;
/** Max length to keep explanations short and encouraging (attempts 0–1). */
const MAX_QUIZ_EXPLANATION_CHARS = 320;

/** Strip hyphens/spaces from ISBN before sending to the model (catalog context only). */
function normalizeIsbnForAi(raw) {
  return String(raw ?? '')
    .replace(/-/g, '')
    .replace(/\s/g, '')
    .trim();
}

/** Groq calls when MCQ JSON fails validation (strict checks, then one more relaxed pass). */
const MAX_MCQ_COMPREHENSION_ATTEMPTS = 3;

/**
 * Detect if explanation text explicitly names a different MCQ letter as correct.
 */
function explanationContradictsAnswerLetter(explanation, correctLetter) {
  const exp = String(explanation ?? '').toLowerCase();
  const c = String(correctLetter ?? '')
    .trim()
    .toUpperCase()
    .charAt(0);
  if (!['A', 'B', 'C'].includes(c)) return false;
  for (const L of ['A', 'B', 'C']) {
    if (L === c) continue;
    const l = L.toLowerCase();
    const badPatterns = [
      `${l} is correct`,
      `${l} is the correct`,
      `${l} is the answer`,
      `${l} is right`,
      `answer is ${l}`,
      `correct answer is ${l}`,
      `the answer is ${l}`,
      `choose ${l} because`,
      `option ${l} is correct`,
      `${l}) is correct`,
    ];
    for (const p of badPatterns) {
      if (exp.includes(p)) return true;
    }
  }
  return false;
}

/**
 * Validate raw quiz[] from the model before normalization (self-correction / consistency).
 * @param {{ minExplanationChars?: number, skipExplanationLength?: boolean }} [opts] — final attempt: skipExplanationLength true (letter contradiction + A/B/C only).
 */
function validateQuizSelfCorrection(rawQuiz, opts = {}) {
  const minExpl = opts.minExplanationChars ?? MIN_QUIZ_EXPLANATION_CHARS;
  const maxExpl = opts.maxExplanationChars ?? MAX_QUIZ_EXPLANATION_CHARS;
  const skipLen = opts.skipExplanationLength === true;
  const reasons = [];
  if (!Array.isArray(rawQuiz) || rawQuiz.length !== 3) {
    return { ok: false, reasons: ['quiz must be an array of exactly 3 items'] };
  }
  for (let i = 0; i < 3; i++) {
    const raw = rawQuiz[i];
    if (!raw || typeof raw !== 'object') {
      reasons.push(`quiz[${i}]: invalid item`);
      continue;
    }
    const exp = String(raw.explanation ?? '').trim();
    if (!skipLen && exp.length < minExpl) {
      reasons.push(
        `quiz[${i}]: explanation too short (need at least ${minExpl} characters; keep a short encouraging comment)`,
      );
    }
    if (!skipLen && exp.length > maxExpl) {
      reasons.push(
        `quiz[${i}]: explanation too long (keep under ${maxExpl} characters; one or two brief sentences)`,
      );
    }
    const ansRaw = String(raw.answer ?? raw.correct ?? '')
      .trim()
      .toUpperCase()
      .replace(/[^ABC]/g, '');
    const letter = ansRaw.charAt(0);
    if (!['A', 'B', 'C'].includes(letter)) {
      reasons.push(`quiz[${i}]: answer must be A, B, or C`);
    } else if (explanationContradictsAnswerLetter(exp, letter)) {
      reasons.push(`quiz[${i}]: explanation appears to contradict answer ${letter}`);
    }
  }
  return { ok: reasons.length === 0, reasons };
}

router.post('/', quotaPreCheck('assessment'), async (req, res, next) => {
  const cfg = groqConfig();
  if (!cfg) {
    console.warn('[assessment] GROQ_API_KEY missing');
    return res.status(503).json({
      error: 'assessment_not_configured',
      message: 'Set GROQ_API_KEY in api/.env (see .env.example).',
    });
  }

  const { kind, transcript, summary, bookTitle, bookAuthor, challengeMode, isbn: rawIsbn } =
    req.body || {};
  const temperature =
    typeof req.body?.temperature === 'number' && req.body.temperature >= 0 && req.body.temperature <= 2
      ? req.body.temperature
      : 0.55;

  try {
    if (kind === 'book_comprehension') {
      const title = String(bookTitle ?? '').trim();
      if (!title) {
        return res.status(400).json({ error: 'invalid_book', message: 'bookTitle is required.' });
      }
      const author = String(bookAuthor ?? '').trim();
      const isbnForAi = normalizeIsbnForAi(rawIsbn);
      const sum = truncateText(summaryTextForQuiz(summary), 4000);
      const mode = String(challengeMode ?? 'both').toLowerCase();
      if (!['quiz', 'storyteller', 'both'].includes(mode)) {
        return res.status(400).json({
          error: 'invalid_challenge_mode',
          message: 'challengeMode must be quiz, storyteller, or both.',
        });
      }
      const system =
        mode === 'quiz'
          ? SYSTEM_BOOK_QUIZ
          : mode === 'storyteller'
            ? SYSTEM_BOOK_STORYTELLER
            : SYSTEM_BOOK_BOTH;
      const mcqUserLine =
        mode === 'storyteller'
          ? ''
          : `\n\nJSON must include "key_facts" (1 to 3 strings, English), then "book_context" (English), then "quiz" (3 objects: id 1 Literal, 2 Inferential, 3 Emotional) with English "question", "options" (3 strings), "answer" ("A"|"B"|"C"), and short encouraging English "explanation" (one or two brief sentences each, aligned with "answer"). Do not ask author/ISBN trivia.\n`;
      const isbnLine = isbnForAi
        ? `\nISBN (hyphens removed; catalog context only—do NOT mention in questions or options): ${isbnForAi}\n`
        : '';
      const userMsgBase = `The child is reading "${truncateText(title, 400)}" by ${author ? truncateText(author, 200) : 'an unknown author'}.${isbnLine}

Follow your system instructions strictly. All quiz-facing text must be ENGLISH. Prefer a fun quiz whenever the title or summary gives any hook; use quiz_unavailable only in the rare case described in your system prompt. Do not ask who wrote the book—the author line is context only.

Summary (story facts for the quiz; title may clarify; do not quiz author names): ${sum || '(none)'}${mcqUserLine}
Return only the JSON object.`;

      const DEFAULT_QUIZ_FALLBACK =
        "I'm still learning about this story, let's try a Retell challenge instead!";

      const usesMcq = mode === 'quiz' || mode === 'both';
      const maxTokens = mode === 'both' ? 1400 : mode === 'storyteller' ? 520 : 1280;

      let parsed = null;
      let regenHint = '';

      for (let attempt = 0; attempt < MAX_MCQ_COMPREHENSION_ATTEMPTS; attempt++) {
        const isLastAttempt = attempt === MAX_MCQ_COMPREHENSION_ATTEMPTS - 1;
        const userMsg =
          attempt === 0
            ? userMsgBase
            : isLastAttempt
              ? `${userMsgBase}\n\nREGENERATE: ${regenHint}\nReturn the complete JSON again. Each quiz[].answer (A/B/C) must match its explanation with no contradictions. Explanations may be brief.`
              : `${userMsgBase}\n\nREGENERATE: ${regenHint}\nReturn the complete JSON again. Every quiz[].explanation must match the letter in quiz[].answer—short encouraging English (at least ~${MIN_QUIZ_EXPLANATION_CHARS} characters, one or two brief sentences).`;

        const body = {
          model: cfg.model,
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: userMsg },
          ],
          temperature: Math.min(0.7, temperature + 0.06 * attempt),
          max_tokens: maxTokens,
        };

        // Groq: `json_schema` is only on select models; `llama-3.3-70b-versatile` rejects it (400).
        // `json_object` is supported on all models and still guarantees valid JSON; shape is enforced below.
        if (usesMcq) {
          body.response_format = { type: 'json_object' };
        }

        let resp = await fetch(GROQ_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${cfg.apiKey}`,
          },
          body: JSON.stringify(body),
        });
        let data = await resp.json();

        if (!resp.ok && usesMcq && body.response_format && resp.status === 400) {
          const msg400 = data?.error?.message || '';
          console.warn('[assessment] groq response_format rejected; retrying without format', msg400);
          delete body.response_format;
          resp = await fetch(GROQ_URL, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${cfg.apiKey}`,
            },
            body: JSON.stringify(body),
          });
          data = await resp.json();
        }

        if (resp.status !== 200) {
          const msg = data?.error?.message || data?.message || resp.statusText;
          console.warn('[assessment] groq book_comprehension failed', resp.status, msg);
          return res.status(resp.status).json({ error: 'assessment_failed', message: msg });
        }

        const content = data?.choices?.[0]?.message?.content?.trim() ?? '';
        try {
          parsed = JSON.parse(stripJsonFence(content));
        } catch (e) {
          regenHint = `Model returned invalid JSON (${e?.message}).`;
          if (isLastAttempt) {
            console.warn('[assessment] book_comprehension JSON parse', e?.message);
            return res.status(422).json({ error: 'invalid_model_json', message: 'Model did not return valid JSON.' });
          }
          continue;
        }

        if (!usesMcq || parsed.quiz_unavailable === true) {
          break;
        }

        if (Array.isArray(parsed.quiz) && parsed.quiz.length === 3) {
          const v = isLastAttempt
            ? validateQuizSelfCorrection(parsed.quiz, { skipExplanationLength: true })
            : validateQuizSelfCorrection(parsed.quiz);
          if (v.ok) {
            break;
          }
          regenHint = v.reasons.join('; ');
          if (isLastAttempt) {
            console.warn('[assessment] quiz self-correction failed after retries:', regenHint);
            if (mode === 'quiz') {
              parsed = {
                quiz_unavailable: true,
                fallback_message: DEFAULT_QUIZ_FALLBACK,
                book_context: '',
                key_facts: [],
                quiz: [],
              };
            }
            break;
          }
          continue;
        }

        regenHint =
          'Return exactly 3 MCQs in "quiz" with ids 1 (Literal), 2 (Inferential), 3 (Emotional), each with question, 3 options, answer A|B|C, and explanation.';
        if (isLastAttempt) {
          break;
        }
        continue;
      }

      if (!parsed) {
        return res.status(422).json({ error: 'invalid_model_json', message: 'Empty model response.' });
      }
      const bookContext = String(parsed?.book_context ?? '').trim();
      const coachIntroLegacy = String(parsed?.coach_intro ?? '').trim();
      const retellingPromptRaw = String(parsed?.retelling_prompt ?? '').trim();
      const rawKeywords = parsed?.retelling_keywords;
      const rawHints = parsed?.retelling_hints;
      let mcqQuestions = [];
      if (Array.isArray(parsed?.quiz) && parsed.quiz.length > 0) {
        mcqQuestions = normalizeReadingCoachQuizList(parsed.quiz);
      } else {
        mcqQuestions = normalizeMcqList(parsed?.mcq_questions);
      }
      const coachIntro = coachIntroLegacy || bookContext;
      const keyFacts = Array.isArray(parsed?.key_facts)
        ? parsed.key_facts.map((x) => String(x ?? '').trim()).filter(Boolean)
        : [];
      let retellingKeywords = Array.isArray(rawKeywords)
        ? rawKeywords.map((k) => String(k ?? '').trim()).filter((k) => k.length > 0)
        : [];
      if (retellingKeywords.length === 0) {
        retellingKeywords = ['First', 'Next', 'Then', 'Finally'];
      }
      let retellingHints = Array.isArray(rawHints)
        ? rawHints.map((h) => String(h ?? '').trim()).filter((h) => h.length > 0)
        : [];

      if (mode === 'quiz' && mcqQuestions.length < 3) {
        const custom =
          parsed.quiz_unavailable === true ? String(parsed.fallback_message ?? '').trim() : '';
        const msg = custom || DEFAULT_QUIZ_FALLBACK;
        return res.json({
          quiz_unavailable: true,
          fallback_message: msg,
          coach_intro: msg,
          mcq_questions: [],
          retelling_hints: [],
        });
      }

      if (mode === 'quiz') {
        retellingHints = [];
        retellingKeywords = [];
      } else if (mode === 'storyteller') {
        mcqQuestions = [];
        retellingHints = [];
        if (!retellingPromptRaw) {
          return res.status(422).json({
            error: 'incomplete_retelling_prompt',
            message: 'storyteller mode requires a non-empty retelling_prompt (one central question).',
          });
        }
      } else {
        retellingHints = [];
        if (mcqQuestions.length < 3 || !retellingPromptRaw) {
          return res.status(422).json({
            error: 'incomplete_both',
            message: 'both mode requires 3 quiz items and a non-empty retelling_prompt.',
          });
        }
      }

      if (mode !== 'quiz' && retellingKeywords.length !== 4) {
        retellingKeywords = ['First', 'Next', 'Then', 'Finally'];
      }

      const effectiveCoachIntro =
        coachIntro ||
        (mode !== 'quiz' && retellingPromptRaw ? retellingPromptRaw : '');
      if (!effectiveCoachIntro) {
        return res.status(422).json({
          error: 'incomplete_plan',
          message: 'Missing book_context (or coach_intro for legacy format).',
        });
      }

      return res.json({
        coach_intro: effectiveCoachIntro,
        mcq_questions: mcqQuestions,
        retelling_prompt: mode === 'quiz' ? '' : retellingPromptRaw,
        retelling_keywords: mode === 'quiz' ? [] : retellingKeywords,
        retelling_hints: retellingHints,
        ...(keyFacts.length > 0 ? { key_facts: keyFacts.slice(0, 3) } : {}),
      });
    }

    if (kind === 'retelling_feedback') {
      const t = String(transcript ?? '').trim();
      if (!t) {
        return res.status(400).json({ error: 'invalid_transcript', message: 'transcript is required.' });
      }
      const sum = truncateText(summary ?? '', 8000);
      const userMsg = `Book summary (context only):\n---\n${sum || '(none)'}\n---\n\nChild's retelling:\n---\n${truncateText(t, 12000)}\n---\nReturn the JSON object only.`;
      const resp = await fetch(GROQ_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${cfg.apiKey}`,
        },
        body: JSON.stringify({
          model: cfg.model,
          messages: [
            { role: 'system', content: SYSTEM_RETELLING_LISTENER },
            { role: 'user', content: userMsg },
          ],
          temperature: Math.min(0.75, temperature + 0.05),
          max_tokens: 600,
        }),
      });
      const data = await resp.json();
      if (resp.status !== 200) {
        const msg = data?.error?.message || data?.message || resp.statusText;
        console.warn('[assessment] groq retelling_feedback failed', resp.status, msg);
        return res.status(resp.status).json({ error: 'assessment_failed', message: msg });
      }
      const content = data?.choices?.[0]?.message?.content?.trim() ?? '';
      let parsed;
      try {
        parsed = JSON.parse(stripJsonFence(content));
      } catch (e) {
        console.warn('[assessment] retelling_feedback JSON parse', e?.message);
        return res.status(422).json({ error: 'invalid_model_json', message: 'Model did not return valid JSON.' });
      }
      const comment = String(parsed?.comment ?? '').trim();
      const logicScore = Number(parsed?.logic_score);
      if (!comment) {
        return res.status(422).json({ error: 'empty_comment', message: 'Empty listener response.' });
      }
      if (!Number.isFinite(logicScore) || logicScore < 1 || logicScore > 5) {
        return res.status(422).json({ error: 'invalid_score', message: 'logic_score must be 1–5.' });
      }
      return res.json({ comment, logic_score: Math.floor(logicScore) });
    }

    return res.status(400).json({
      error: 'invalid_kind',
      message: 'kind must be "book_comprehension" or "retelling_feedback".',
    });
  } catch (err) {
    next(err);
  }
});

export default router;
