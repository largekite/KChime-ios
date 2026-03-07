// POST /api/v2/generateReplies
//
// Richer endpoint compared to /api/mobile/reply:
//   • Extended request shape: userDraft, constraints, style
//   • Response: { suggestions[], alternatives: {longer, shorter}, safety }
//   • SSE streaming when client sends Accept: text/event-stream
//   • SHA-256 request-body caching (60 s TTL, in-process)
//   • Telemetry (latency_ms, tokens, profile — no message content)
//   • Per-user/device daily token cost guardrails

import { Hono } from "hono";
import { stream } from "hono/streaming";
import { z } from "zod";
import { optionalAuth } from "../lib/auth/middleware.js";
import { getUsage, recordUsage } from "../lib/db/client.js";
import { checkRateLimit, REPLY_RATE_LIMIT, REPLY_RATE_WINDOW_MS } from "../lib/rate-limit/index.js";
import { createAIProvider } from "../lib/ai/index.js";
import type { GenerateResult } from "../lib/ai/index.js";
import { hashRequestBody, getCachedResult, setCachedResult } from "../lib/cache/requestCache.js";
import { checkSafety } from "../lib/safety/classifier.js";
import { emitTelemetry } from "../lib/telemetry/index.js";
import { isDailyBudgetAvailable, recordDailyTokens } from "../lib/cost/guardrails.js";

const ai = createAIProvider();
const generateRepliesRouter = new Hono();

// ─── Schemas ──────────────────────────────────────────────────────────────────

const toneProfileSchema = z.object({
  label: z.string(),
  formality: z.number().min(0).max(1),
  emojiEnabled: z.boolean(),
  lengthPreference: z.enum(["short", "medium", "verbose"]),
  customInstructions: z.string().max(500).optional(),
});

const relationshipProfileSchema = z.object({
  name: z.string().min(1).max(50),
  formality: z.number().int().min(0).max(10),
  warmth: z.number().int().min(0).max(10),
  brevity: z.number().int().min(0).max(10),
  emojiAllowed: z.boolean(),
  directness: z.number().int().min(0).max(10),
});

const constraintsSchema = z.object({
  maxChars: z.number().int().min(1).max(1000).optional(),
  language: z.string().min(2).max(10).optional(),
});

const styleSchema = z.object({
  avoidApologies: z.boolean().optional(),
  includeCTA: z.boolean().optional(),
});

const generateRepliesSchema = z.object({
  incomingText: z.string().min(1).max(4000),
  userDraft: z.string().max(2000).optional(),
  toneProfile: toneProfileSchema,
  relationshipProfile: relationshipProfileSchema.optional(),
  contactNotes: z.string().max(500).optional(),
  constraints: constraintsSchema.optional(),
  style: styleSchema.optional(),
  featureKey: z.string().min(1).default("keyboard"),
  deviceID: z.string().min(1),
});

// ─── Response builders ────────────────────────────────────────────────────────

function buildSuccessResponse(result: GenerateResult, safety: { blocked: boolean; reason: string | null }) {
  return {
    suggestions: result.suggestions,
    alternatives: {
      longer: result.longerAlternative,
      shorter: result.shorterAlternative,
    },
    safety,
  };
}

// ─── SSE helpers ─────────────────────────────────────────────────────────────

function sseEvent(type: string, data: unknown): string {
  return `data: ${JSON.stringify({ type, ...( typeof data === "object" && data !== null ? data : { value: data }) })}\n\n`;
}

// ─── Handler ──────────────────────────────────────────────────────────────────

generateRepliesRouter.post("/", optionalAuth, async (c) => {
  const startMs = Date.now();
  const auth = c.get("auth");
  const wantsStream = c.req.header("Accept")?.includes("text/event-stream") ?? false;

  // ── 1. Parse + validate ──────────────────────────────────────────────────────
  let rawBody: unknown;
  try {
    rawBody = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON body", code: "BAD_REQUEST" }, 400);
  }

  const parsed = generateRepliesSchema.safeParse(rawBody);
  if (!parsed.success) {
    return c.json(
      { error: "Invalid request body", code: "BAD_REQUEST", details: parsed.error.flatten() },
      400
    );
  }
  const body = parsed.data;

  // ── 2. Safety check (on incomingText only — no AI cost incurred) ─────────────
  const safety = checkSafety(body.incomingText);
  if (safety.blocked) {
    emitTelemetry({
      event: "generate_replies",
      latency_ms: Date.now() - startMs,
      tokens_used: null,
      profile_label: body.toneProfile.label,
      relationship_used: !!body.relationshipProfile,
      constraints_used: !!body.constraints,
      style_used: !!body.style,
      cached: false,
      streaming: wantsStream,
      success: false,
      user_type: auth ? (auth.isPro ? "pro" : "free") : "anonymous",
      error_code: "safety_blocked",
    });
    // Return an empty result rather than an error status so the client can handle it gracefully.
    return c.json({
      suggestions: [],
      alternatives: { longer: "", shorter: "" },
      safety,
    });
  }

  // ── 3. IP burst rate limit ───────────────────────────────────────────────────
  const ip = c.req.header("X-Forwarded-For")?.split(",")[0]?.trim() ?? "unknown";
  const ipLimit = checkRateLimit(`ip:${ip}`, REPLY_RATE_LIMIT, REPLY_RATE_WINDOW_MS);
  if (!ipLimit.allowed) {
    return c.json({ error: "Too many requests", code: "RATE_LIMITED" }, 429);
  }

  // ── 4. Daily reply-count usage check ─────────────────────────────────────────
  const usageKey = auth?.userID ? { userID: auth.userID } : { deviceID: body.deviceID };
  const usage = await getUsage({ feature: body.featureKey, ...usageKey });
  if (usage.remaining <= 0) {
    return c.json(
      {
        error: "Daily limit reached. Upgrade to Pro for 50 replies/day.",
        code: "LIMIT_REACHED",
        remaining: 0,
        limit: usage.limit,
      },
      429
    );
  }

  // ── 5. Daily token cost guardrail ────────────────────────────────────────────
  const costKey = auth?.userID ? `user:${auth.userID}` : `device:${body.deviceID}`;
  const isPro = auth?.isPro ?? false;
  if (!isDailyBudgetAvailable(costKey, isPro)) {
    return c.json({ error: "Daily token budget exceeded", code: "COST_LIMIT_REACHED" }, 429);
  }

  // ── 6. Cache lookup ──────────────────────────────────────────────────────────
  // Hash only the parts that affect the AI output (not featureKey/deviceID).
  const cachePayload = {
    incomingText: body.incomingText,
    ...(body.userDraft !== undefined ? { userDraft: body.userDraft } : {}),
    toneProfile: body.toneProfile,
    ...(body.relationshipProfile ? { relationshipProfile: body.relationshipProfile } : {}),
    ...(body.contactNotes !== undefined ? { contactNotes: body.contactNotes } : {}),
    ...(body.constraints ? { constraints: body.constraints } : {}),
    ...(body.style ? { style: body.style } : {}),
  };
  const cacheKey = hashRequestBody(cachePayload);
  const cached = getCachedResult<GenerateResult>(cacheKey);

  if (cached) {
    emitTelemetry({
      event: "generate_replies",
      latency_ms: Date.now() - startMs,
      tokens_used: null,
      profile_label: body.toneProfile.label,
      relationship_used: !!body.relationshipProfile,
      constraints_used: !!body.constraints,
      style_used: !!body.style,
      cached: true,
      streaming: wantsStream,
      success: true,
      user_type: auth ? (isPro ? "pro" : "free") : "anonymous",
    });

    // Still record usage so the counter is accurate even for cache hits.
    await recordUsage({ feature: body.featureKey, ...usageKey });

    if (wantsStream) {
      return streamResult(c, cached, safety);
    }
    return c.json(buildSuccessResponse(cached, safety));
  }

  // ── 7. AI generation ─────────────────────────────────────────────────────────
  let result: GenerateResult;
  try {
    // Reconstruct optional nested objects using conditional spreads so
    // exactOptionalPropertyTypes is satisfied (no `key: undefined` values).
    const constraintsArg = body.constraints
      ? {
          ...(body.constraints.maxChars !== undefined ? { maxChars: body.constraints.maxChars } : {}),
          ...(body.constraints.language !== undefined ? { language: body.constraints.language } : {}),
        }
      : undefined;

    const styleArg = body.style
      ? {
          ...(body.style.avoidApologies !== undefined ? { avoidApologies: body.style.avoidApologies } : {}),
          ...(body.style.includeCTA !== undefined ? { includeCTA: body.style.includeCTA } : {}),
        }
      : undefined;

    result = await ai.generateReplies({
      receivedMessage: body.incomingText,
      ...(body.userDraft !== undefined ? { userDraft: body.userDraft } : {}),
      toneProfile: {
        label: body.toneProfile.label,
        formality: body.toneProfile.formality,
        emojiEnabled: body.toneProfile.emojiEnabled,
        lengthPreference: body.toneProfile.lengthPreference,
        ...(body.toneProfile.customInstructions !== undefined
          ? { customInstructions: body.toneProfile.customInstructions }
          : {}),
      },
      ...(body.relationshipProfile ? { relationshipProfile: body.relationshipProfile } : {}),
      ...(body.contactNotes !== undefined ? { contactNotes: body.contactNotes } : {}),
      ...(constraintsArg ? { constraints: constraintsArg } : {}),
      ...(styleArg ? { style: styleArg } : {}),
    });
  } catch (err) {
    console.error("[generateReplies] AI generation failed:", err);
    emitTelemetry({
      event: "generate_replies",
      latency_ms: Date.now() - startMs,
      tokens_used: null,
      profile_label: body.toneProfile.label,
      relationship_used: !!body.relationshipProfile,
      constraints_used: !!body.constraints,
      style_used: !!body.style,
      cached: false,
      streaming: wantsStream,
      success: false,
      user_type: auth ? (isPro ? "pro" : "free") : "anonymous",
      error_code: "ai_error",
    });
    return c.json({ error: "Reply generation failed", code: "AI_ERROR" }, 502);
  }

  // ── 8. Record usage + tokens ─────────────────────────────────────────────────
  const tokensUsed = result.tokensUsed;
  await recordUsage({
    feature: body.featureKey,
    ...usageKey,
    ...(tokensUsed !== undefined ? { tokensUsed } : {}),
  });

  if (tokensUsed !== undefined) {
    recordDailyTokens(costKey, tokensUsed);
  }

  // ── 9. Cache the result ──────────────────────────────────────────────────────
  setCachedResult(cacheKey, result, 60_000);

  // ── 10. Telemetry ────────────────────────────────────────────────────────────
  emitTelemetry({
    event: "generate_replies",
    latency_ms: Date.now() - startMs,
    tokens_used: tokensUsed ?? null,
    profile_label: body.toneProfile.label,
    relationship_used: !!body.relationshipProfile,
    constraints_used: !!body.constraints,
    style_used: !!body.style,
    cached: false,
    streaming: wantsStream,
    success: true,
    user_type: auth ? (isPro ? "pro" : "free") : "anonymous",
  });

  // ── 11. Respond ──────────────────────────────────────────────────────────────
  if (wantsStream) {
    return streamResult(c, result, safety);
  }
  return c.json(buildSuccessResponse(result, safety));
});

// ─── SSE streaming ────────────────────────────────────────────────────────────
//
// Streams each suggestion as a separate event so the client can render
// progressively. The iOS app can consume this via URLSessionDataTask + line
// buffering, or simply use the non-streaming path for simplicity.
//
// Event sequence:
//   suggestion {index: 0, text: "..."}
//   suggestion {index: 1, text: "..."}
//   suggestion {index: 2, text: "..."}
//   alternatives {longer: "...", shorter: "..."}
//   done {safety: {blocked, reason}}

function streamResult(
  c: Parameters<typeof stream>[0],
  result: GenerateResult,
  safety: { blocked: boolean; reason: string | null }
) {
  return stream(c, async (s) => {
    s.onAbort(() => { /* client disconnected */ });

    for (let i = 0; i < result.suggestions.length; i++) {
      await s.write(sseEvent("suggestion", { index: i, text: result.suggestions[i] }));
    }

    await s.write(
      sseEvent("alternatives", {
        longer: result.longerAlternative,
        shorter: result.shorterAlternative,
      })
    );

    await s.write(sseEvent("done", { safety }));
  });
}

export { generateRepliesRouter };
