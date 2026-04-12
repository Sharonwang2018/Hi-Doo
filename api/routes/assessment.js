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

const SYSTEM_BOOK_QUIZ = `You are a professional children's literacy expert and a warm Reading Coach. You generate comprehension quizzes using ONLY the book metadata and summary provided in the user message. You do NOT have the full book text.

PRIORITY: Prefer producing a quiz whenever there is ANY usable story hint. Only return quiz_unavailable when the summary is literally empty or contains zero story details (after ignoring catalog placeholders), AND the title does not reasonably suggest a subject or theme. If the story is simple or the text is short, make the questions simple and easy—do not refuse a quiz just because the material is brief.

STRICT CONTEXT (no hallucinations):
- Use ONLY: the given title, author, and summary text. Do not invent characters, scenes, endings, or facts that are not clearly supported by that material.
- Do not rely on your memory of the book from outside this conversation. If something is not in the summary (or explicitly implied there), do not use it.
- You MAY use the title to infer a likely main character, subject, or theme when the summary is thin, and build fair, easy questions from title + summary together—still do not invent specific plot events that neither title nor summary plausibly suggest.
- If the summary is short but mentions at least a main character, setting, theme, or one concrete story beat, always try: derive key_facts from what is written (and title hints if needed) and build three fair MCQs.

MANDATORY WORKFLOW (follow this order in your JSON output):
1) First, write "key_facts": an array of 1 to 3 short strings (use as many as you can honestly ground—1 is OK if the text is tiny). Each string is ONE concrete fact in plain English supported by the summary and/or title (story content only—do not use the author line as a fact). No speculation; no "probably" or invented details.
2) Then write "book_context": one brief sentence that stays within those facts (safe paraphrase of the strongest shared context).
3) Then write "quiz": exactly 3 MCQs. Every question, every answer option, and every explanation MUST be fully answerable using ONLY those key_facts plus the book title when needed for disambiguation—never using who wrote it. If you have at least one grounded key_fact or a clear title hint, prefer writing simple questions over returning quiz_unavailable.

QUIZ RULES:
1. Generate exactly 3 Multiple Choice Questions (MCQ).
2. Level 1 (Literal): confidence builder. Set "level": "Literal" and "id": 1.
3. Level 2 (Inferential): "Why" or "How" that still follows from the key_facts only. Set "level": "Inferential" and "id": 2.
4. Level 3 (Emotional/Critical): feelings or connection, grounded in what the summary/key_facts support. Set "level": "Emotional" and "id": 3.
5. Each question has exactly 3 options in order A, B, C (may use "A) " prefix or plain text).
6. "answer" must be exactly "A", "B", or "C".
7. Simple English for ages roughly 6–8; encouraging tone; wrong options plausible but incorrect per the key_facts.
8. SELF-CORRECTION / "explanation" (required for every quiz item): Write in a warm, child-friendly tone (often 2–4 short sentences; briefer is OK when the book hints are thin). You MUST (a) align with the letter in "answer" and the key_facts/summary, and (b) avoid praising a wrong option as correct. Do not contradict the letter in "answer" (never say a different letter is correct). Only mention details supported by key_facts.
9. NEVER ask meta-questions about the catalog or missing text: do not ask whether a "summary" exists, is missing, or is "available"; do not put phrases like "summary available", "no summary", or "description" in any question or option. Quiz only about characters, events, feelings, or facts from the actual story hints in the summary/title—not about library metadata.
10. NEVER ask about the author, illustrator, or "who wrote/drew this book"—children are practicing comprehension of the story, not catalog trivia. Do not put author names in questions, options, or explanations unless the summary itself is about the author (rare).

RESPONSE FORMAT (JSON ONLY, no markdown):
{
  "key_facts": ["<1–3 facts from summary/title only; omit extras if you cannot ground them>"],
  "book_context": "One sentence grounded in key_facts only.",
  "quiz": [
    {
      "id": 1,
      "level": "Literal",
      "question": "...",
      "options": ["A) ...", "B) ...", "C) ..."],
      "answer": "A",
      "explanation": "Why A fits the story … Why B and C don't match what we know …"
    },
    {
      "id": 2,
      "level": "Inferential",
      "question": "...",
      "options": ["A) ...", "B) ...", "C) ..."],
      "answer": "B",
      "explanation": "Why B fits … Why A and C don't match the summary …"
    },
    {
      "id": 3,
      "level": "Emotional",
      "question": "...",
      "options": ["A) ...", "B) ...", "C) ..."],
      "answer": "C",
      "explanation": "Why C fits … Why A and B don't fit …"
    }
  ]
}

If and ONLY if there is literally no story content (empty/placeholder summary and no reasonable hint from the title), respond ONLY with:
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

const SYSTEM_BOOK_BOTH = `You are a professional children's literacy expert and a warm Reading Coach plus retelling listener. You only know title, author, and optional catalog summary—not full page text.

1) Quiz: Same grounding as quiz-only: key_facts (1 to 3 strings) from the summary/title—no invented plot; author is never a quiz topic. Prioritize generating a quiz; quiz_unavailable only when there is zero story detail (see quiz-only rules). Never ask about whether a summary exists or is "available"—only story content.

2) Storyteller: Act as a warm listener. Give ONE short inviting retelling_prompt (one question only) and retelling_keywords: ["First","Next","Then","Finally"]. retelling_hints must be [].

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
const MIN_QUIZ_EXPLANATION_CHARS = 20;

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
        `quiz[${i}]: explanation too short (need at least ${minExpl} characters to justify correct + distractors)`,
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

  const { kind, transcript, summary, bookTitle, bookAuthor, challengeMode } = req.body || {};
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
          : `\n\nJSON must include "key_facts" (1 to 3 strings) first, then "book_context", then "quiz" (3 objects: id 1 Literal, 2 Inferential, 3 Emotional) with "question", "options" (3 strings), "answer" ("A"|"B"|"C"), and "explanation". Each "explanation" must justify the correct letter using the book/key_facts and briefly rule out the two wrong options. Questions must be grounded ONLY in those key_facts plus title for disambiguation—never author trivia, no outside plot.\n`;
      const userMsgBase = `The child is reading "${truncateText(title, 400)}" by ${author ? truncateText(author, 200) : 'an unknown author'}.

Follow your system instructions strictly. Do not invent plot beyond title/summary. Prioritize a quiz when there is any story hint (even a very short summary or a suggestive title). Use quiz_unavailable only when there is truly no story content. Do not ask who wrote the book—the author line is context only.

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
              : `${userMsgBase}\n\nREGENERATE: ${regenHint}\nReturn the complete JSON again. Every quiz[].explanation must match the letter in quiz[].answer and briefly justify the correct option and why the other two do not fit (each explanation at least ~${MIN_QUIZ_EXPLANATION_CHARS} characters).`;

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
