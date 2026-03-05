// In-memory request-body cache with SHA-256 keying and TTL eviction.
//
// In Vercel/Lambda, in-memory state lives for the lifetime of a warm instance.
// Cold starts produce an empty cache. This still reduces latency and cost for
// bursts of identical requests (e.g. user tapping Regenerate repeatedly).
//
// For multi-region persistence, replace with an Upstash Redis client.

import { createHash } from "node:crypto";

interface CacheEntry {
  data: unknown;
  expiresAt: number;
}

const store = new Map<string, CacheEntry>();

// ─── Key ─────────────────────────────────────────────────────────────────────

/** SHA-256 hex digest of the stable JSON representation of any value. */
export function hashRequestBody(body: unknown): string {
  return createHash("sha256").update(JSON.stringify(body)).digest("hex");
}

// ─── Read / write ─────────────────────────────────────────────────────────────

export function getCachedResult<T>(key: string): T | null {
  const entry = store.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    store.delete(key);
    return null;
  }
  return entry.data as T;
}

export function setCachedResult(key: string, data: unknown, ttlMs = 60_000): void {
  // Prune expired entries when the store grows large to avoid unbounded memory growth.
  if (store.size > 500) {
    const now = Date.now();
    for (const [k, v] of store) {
      if (now > v.expiresAt) store.delete(k);
    }
  }
  store.set(key, { data, expiresAt: Date.now() + ttlMs });
}
