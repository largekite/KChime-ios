// Per-user / per-device daily token cost guardrails.
//
// Uses an in-process Map keyed by user/device ID + UTC date.
// State is warm-instance-local — in serverless environments the counter resets
// on cold starts. For production accuracy, back this with a Redis INCR or a
// `daily_tokens` DB row. The in-process version still catches rapid bursts
// within the same warm Lambda/Vercel function instance.

interface TokenEntry {
  date: string;   // "YYYY-MM-DD" UTC
  tokens: number;
}

const tokenMap = new Map<string, TokenEntry>();

// Approximate cost caps (tokens per user per UTC day).
// gpt-4o-mini: ~$0.15 / 1M input tokens. 200k ≈ $0.03/user/day free tier.
const FREE_DAILY_TOKEN_LIMIT = 200_000;
const PRO_DAILY_TOKEN_LIMIT = 5_000_000;

function todayUTC(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Returns true if the user/device is within their daily token budget.
 * @param key   "user:<uuid>" or "device:<id>"
 * @param isPro whether the account has a Pro entitlement
 */
export function isDailyBudgetAvailable(key: string, isPro: boolean): boolean {
  const limit = isPro ? PRO_DAILY_TOKEN_LIMIT : FREE_DAILY_TOKEN_LIMIT;
  const entry = tokenMap.get(key);
  if (!entry || entry.date !== todayUTC()) return true; // fresh day or unknown
  return entry.tokens < limit;
}

/**
 * Record tokens consumed in this request.
 * @param key       "user:<uuid>" or "device:<id>"
 * @param tokens    Total tokens used (prompt + completion)
 */
export function recordDailyTokens(key: string, tokens: number): void {
  const today = todayUTC();
  const entry = tokenMap.get(key);
  if (!entry || entry.date !== today) {
    tokenMap.set(key, { date: today, tokens });
  } else {
    entry.tokens += tokens;
  }
}

/** Current daily token total for a key (0 if no data or stale). */
export function getDailyTokenCount(key: string): number {
  const entry = tokenMap.get(key);
  if (!entry || entry.date !== todayUTC()) return 0;
  return entry.tokens;
}
