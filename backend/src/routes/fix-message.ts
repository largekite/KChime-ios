// POST /api/mobile/fix-message
// Takes a user draft and returns 3 polished rewrites with tone labels and improvement notes.

import { Hono } from "hono";
import { z } from "zod";
import { optionalAuth } from "../lib/auth/middleware.js";
import { getUsage, recordUsage } from "../lib/db/client.js";
import { checkRateLimit, REPLY_RATE_LIMIT, REPLY_RATE_WINDOW_MS } from "../lib/rate-limit/index.js";
import { createAIProvider } from "../lib/ai/index.js";

const ai = createAIProvider();
const fixMessageRouter = new Hono();

const toneProfileSchema = z.object({
  label: z.string(),
  formality: z.number().min(0).max(1),
  emojiEnabled: z.boolean(),
  lengthPreference: z.enum(["short", "medium", "verbose"]),
  customInstructions: z.string().optional(),
});

const fixMessageSchema = z.object({
  draft: z.string().min(1).max(4000),
  messageType: z.string().min(1),
  relationship: z.string().min(1),
  toneProfile: toneProfileSchema,
  deviceID: z.string().min(1),
});

// Tone assignments per message type
const TONES_BY_TYPE: Record<string, string[]> = {
  "Casual text":    ["Clean", "Friendly", "Punchy"],
  "Work email":     ["Polished", "Approachable", "Confident"],
  "Slack / Teams":  ["Direct", "Friendly", "Confident"],
  "Formal letter":  ["Polished", "Diplomatic", "Authoritative"],
  "Social media":   ["Smooth", "Bold", "Witty"],
};

fixMessageRouter.post("/", optionalAuth, async (c) => {
  const auth = c.get("auth");

  let rawBody: unknown;
  try {
    rawBody = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON body", code: "BAD_REQUEST" }, 400);
  }

  const parsed = fixMessageSchema.safeParse(rawBody);
  if (!parsed.success) {
    return c.json(
      { error: "Invalid request body", code: "BAD_REQUEST", details: parsed.error.flatten() },
      400
    );
  }
  const body = parsed.data;

  // IP-level burst limit
  const ip = c.req.header("X-Forwarded-For")?.split(",")[0]?.trim() ?? "unknown";
  const ipLimit = checkRateLimit(`ip:${ip}`, REPLY_RATE_LIMIT, REPLY_RATE_WINDOW_MS);
  if (!ipLimit.allowed) {
    return c.json({ error: "Too many requests", code: "RATE_LIMITED" }, 429);
  }

  // Daily usage check
  const usage = await getUsage({
    feature: "fix-message",
    ...(auth?.userID ? { userID: auth.userID } : { deviceID: body.deviceID }),
  });

  if (usage.remaining <= 0) {
    return c.json(
      {
        error: "Daily limit reached. Upgrade to Pro for unlimited fixes.",
        code: "LIMIT_REACHED",
        remaining: 0,
        limit: usage.limit,
      },
      429
    );
  }

  const tones = TONES_BY_TYPE[body.messageType] ?? ["Polished", "Friendly", "Confident"];

  const systemPrompt = [
    "You are KChime, a message polishing assistant.",
    `The user is writing a ${body.messageType} ${body.relationship}.`,
    `User style: ${body.toneProfile.formality < 0.3 ? "casual" : body.toneProfile.formality < 0.6 ? "balanced" : "formal"} formality, ${body.toneProfile.emojiEnabled ? "emoji OK" : "no emoji"}.`,
    body.toneProfile.customInstructions ? `Additional style: ${body.toneProfile.customInstructions}` : "",
    "",
    `Rewrite the draft into 3 polished versions with these exact tones: ${tones.join(", ")}.`,
    "For each rewrite, list 2-3 specific improvements you made.",
    "",
    'Return ONLY a JSON object — no markdown, no code fences:',
    '{"fixes":[{"tone":"ToneName","text":"rewritten message","improvements":["improvement 1","improvement 2"]},...]}'
  ].filter(Boolean).join("\n");

  try {
    const result = await ai.generateRaw({
      system: systemPrompt,
      user: `Draft to fix:\n\n"${body.draft}"`,
    });

    // Parse the JSON response
    let trimmed = result.trim();
    trimmed = trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```\s*$/, "").trim();
    const data = JSON.parse(trimmed) as { fixes: { tone: string; text: string; improvements: string[] }[] };

    await recordUsage({
      feature: "fix-message",
      ...(auth?.userID ? { userID: auth.userID } : { deviceID: body.deviceID }),
    });

    return c.json({
      fixes: data.fixes.slice(0, 3),
      remaining: usage.remaining - 1,
      limit: usage.limit,
    });
  } catch (err) {
    console.error("[fix-message] AI generation failed:", err);
    return c.json({ error: "Fix generation failed", code: "AI_ERROR" }, 502);
  }
});

export { fixMessageRouter };
