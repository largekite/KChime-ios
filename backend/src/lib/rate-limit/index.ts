// In-memory rate limiter for dev/single-instance deployments.
// For multi-region Vercel/Lambda, swap the store for an Upstash Redis client.

interface RateLimitEntry {
  count: number;
  resetAt: number; // epoch ms
}

const store = new Map<string, RateLimitEntry>();

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
}

/**
 * Sliding-window rate limiter.
 * @param key     Unique identifier (e.g. `ip:${ip}` or `device:${id}`)
 * @param limit   Max requests per window
 * @param windowMs Window duration in milliseconds (default: 1 minute)
 */
export function checkRateLimit(
  key: string,
  limit: number,
  windowMs = 60_000
): RateLimitResult {
  const now = Date.now();
  let entry = store.get(key);

  if (!entry || entry.resetAt < now) {
    entry = { count: 0, resetAt: now + windowMs };
    store.set(key, entry);
  }

  entry.count += 1;
  const allowed = entry.count <= limit;
  const remaining = Math.max(0, limit - entry.count);

  return { allowed, remaining, resetAt: new Date(entry.resetAt) };
}

// Clean up expired entries periodically (every 5 minutes)
if (typeof setInterval !== "undefined") {
  setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of store.entries()) {
      if (entry.resetAt < now) store.delete(key);
    }
  }, 5 * 60_000);
}

// Per-IP limits for the reply endpoint (stricter)
export const REPLY_RATE_LIMIT = 20;        // 20 requests per minute per IP
export const REPLY_RATE_WINDOW_MS = 60_000;

// Per-device/user daily limits are enforced via the DB (see lib/db/client.ts)
