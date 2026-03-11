// POST /api/mobile/reply
// Generates 3 short reply suggestions + 1 longer alternative.
// Accepts an optional relationshipProfile (who the user is writing to).

import { Hono } from "hono";
import { z } from "zod";
import { optionalAuth } from "../lib/auth/middleware.js";
import { getUsage, recordUsage } from "../lib/db/client.js";
import { checkRateLimit, REPLY_RATE_LIMIT, REPLY_RATE_WINDOW_MS } from "../lib/rate-limit/index.js";
import { createAIProvider } from "../lib/ai/index.js";

const ai = createAIProvider();
const replyRouter = new Hono();

// ─── Schemas ──────────────────────────────────────────────────────────────────

const toneProfileSchema = z.object({
  label: z.string(),
  formality: z.number().min(0).max(1),
  emojiEnabled: z.boolean(),
  // "verbose" matches Swift's LengthPreference.verbose.rawValue
  lengthPreference: z.enum(["short", "medium", "verbose"]),
  customInstructions: z.string().optional(),
});

const relationshipProfileSchema = z.object({
  name: z.string().min(1).max(50),
  formality: z.number().int().min(0).max(10),
  warmth: z.number().int().min(0).max(10),
  brevity: z.number().int().min(0).max(10),
  emojiAllowed: z.boolean(),
  directness: z.number().int().min(0).max(10),
});

const replySchema = z.object({
  featureKey: z.string().min(1),
  receivedMessage: z.string().min(1).max(4000),
  toneProfile: toneProfileSchema,
  relationshipProfile: relationshipProfileSchema.optional(),
  contactNotes: z.string().max(500).optional(),
  deviceID: z.string().min(1),
  contextMode: z.enum(["office", "text", "party", "family"]).optional(),
});

// ─── Handler ──────────────────────────────────────────────────────────────────

replyRouter.post("/", optionalAuth, async (c) => {
  const auth = c.get("auth");

  // Parse + validate body
  let rawBody: unknown;
  try {
    rawBody = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON body", code: "BAD_REQUEST" }, 400);
  }

  const parsed = replySchema.safeParse(rawBody);
  if (!parsed.success) {
    return c.json(
      { error: "Invalid request body", code: "BAD_REQUEST", details: parsed.error.flatten() },
      400
    );
  }
  const body = parsed.data;

  // IP-level burst limit (anti-abuse)
  const ip = c.req.header("X-Forwarded-For")?.split(",")[0]?.trim() ?? "unknown";
  const ipLimit = checkRateLimit(`ip:${ip}`, REPLY_RATE_LIMIT, REPLY_RATE_WINDOW_MS);
  if (!ipLimit.allowed) {
    return c.json({ error: "Too many requests", code: "RATE_LIMITED" }, 429);
  }

  // Daily usage check
  const usage = await getUsage({
    feature: body.featureKey,
    ...(auth?.userID ? { userID: auth.userID } : { deviceID: body.deviceID }),
  });

  if (usage.remaining <= 0) {
    return c.json(
      {
        error: "Daily limit reached. Upgrade to Pro for unlimited replies.",
        code: "LIMIT_REACHED",
        remaining: 0,
        limit: usage.limit,
      },
      429
    );
  }

  // Map contextMode to context-specific instructions with tone labels
  const contextInstruction: Record<string, string> = {
    office: "The context is a professional workplace setting — keep it workplace-appropriate. Generate 4 replies with these tones: Professional, Diplomatic, Confident, Friendly.",
    text: "The context is a casual text message conversation — keep it conversational and brief. Generate 4 replies with these tones: Chill, Witty, Hype, Sweet.",
    party: "The context is a social/party setting — keep it fun and upbeat. Generate 4 replies with these tones: Playful, Bold, Energetic, Smooth.",
    family: "The context is a family conversation — keep it warm and personal. Generate 4 replies with these tones: Warm, Gentle, Lighthearted, Respectful.",
  };
  const contextNote = body.contextMode ? contextInstruction[body.contextMode] : undefined;
  const mergedCustomInstructions = [body.toneProfile.customInstructions, contextNote]
    .filter(Boolean)
    .join(" ") || undefined;

  // Generate
  let result: { suggestions: string[]; longerAlternative: string };
  try {
    result = await ai.generateReplies({
      receivedMessage: body.receivedMessage,
      // Strip Zod-inferred `undefined` values so exactOptionalPropertyTypes is satisfied
      toneProfile: {
        label: body.toneProfile.label,
        formality: body.toneProfile.formality,
        emojiEnabled: body.toneProfile.emojiEnabled,
        lengthPreference: body.toneProfile.lengthPreference,
        ...(mergedCustomInstructions !== undefined ? { customInstructions: mergedCustomInstructions } : {}),
      },
      ...(body.relationshipProfile ? { relationshipProfile: body.relationshipProfile } : {}),
      ...(body.contactNotes !== undefined ? { contactNotes: body.contactNotes } : {}),
    });
  } catch (err) {
    console.error("[reply] AI generation failed:", err);
    return c.json({ error: "Reply generation failed", code: "AI_ERROR" }, 502);
  }

  // Record usage only after a successful generation
  await recordUsage({
    feature: body.featureKey,
    ...(auth?.userID ? { userID: auth.userID } : { deviceID: body.deviceID }),
  });

  return c.json({
    suggestions: result.suggestions,
    longerAlternative: result.longerAlternative,
    remaining: usage.remaining - 1,
    limit: usage.limit,
  });
});

export { replyRouter };
