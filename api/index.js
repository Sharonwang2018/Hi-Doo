/**
 * Single Vercel Serverless entry for the whole Express app (Hobby 12-function limit).
 * Application code lives under ../server/ — see Vercel Express: https://vercel.com/docs/frameworks/backend/express
 */
import { app } from '../server/app.js';

export default app;
