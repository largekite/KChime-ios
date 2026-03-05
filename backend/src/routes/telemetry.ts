// POST /api/telemetry/event
//
// Receives client-side analytics events from the iOS app and keyboard extension.
// Events are validated against a strict allowlist before being emitted as
// structured logs — no raw user strings are ever stored.
//
// Downstream: Vercel Log Drains → Datadog / Axiom / Grafana Loki for dashboards.

import { Hono } from "hono";
import { z } from "zod";
import { createHash } from "node:crypto";

const telemetryRouter = new Hono();

// ─── Allowlists ───────────────────────────────────────────────────────────────

const VALID_EVENTS = new Set([
  "app_opened",
  "onboarding_step_viewed",
  "onboarding_completed",
  "onboarding_abandoned",
  "keyboard_opened",
  "generation_requested",
  "generation_completed",
  "suggestion_inserted",
  "tone_chip_tapped",
  "rewrite_chip_blocked",
  "paywall_viewed",
  "subscription_started",
  "subscription_restored",
  "subscription_cancelled",
  "promise_detected",
  "promise_confirmed",
  "promise_dismissed",
  "share_extension_opened",
  "share_extension_completed",
]);

// Only these property keys are permitted — blocks any attempt to leak freeform text.
const VALID_PROPERTY_KEYS = new Set([
  "is_first_launch",
  "step",
  "step_index",
  "at_step",
  "feature",
  "tone_profile",
  "relationship_used",
  "latency_ms",
  "success",
  "char_count_bucket",
  "suggestion_index",
  "chip",
  "is_pro_chip",
  "source",
  "product_id",
  "billing_period",
]);

// Permitted string values for string-typed properties — prevents PII slipping in.
const VALID_STRING_VALUES: Record<string, Set<string>> = {
  feature:           new Set(["keyboard", "share_extension"]),
  step:              new Set(["value_prop", "privacy", "tone_picker", "contacts", "keyboard_setup", "first_success"]),
  at_step:           new Set(["value_prop", "privacy", "tone_picker", "contacts", "keyboard_setup", "first_success"]),
  char_count_bucket: new Set(["xs", "s", "m", "l", "xl"]),
  source:            new Set(["limit_reached", "pro_chip_tapped", "settings", "onboarding"]),
  billing_period:    new Set(["monthly", "annual"]),
  tone_profile:      new Set(["Professional", "Friendly", "Direct", "Custom"]),
};

// ─── Schema ───────────────────────────────────────────────────────────────────

const EventBodySchema = z.object({
  event:       z.string().min(1).max(80),
  device_id:   z.string().min(1).max(120),
  ts:          z.string().datetime().optional(),
  properties:  z.record(z.union([z.string(), z.number(), z.boolean()])).optional(),
});

// ─── Route ────────────────────────────────────────────────────────────────────

telemetryRouter.post("/", async (c) => {
  const parsed = EventBodySchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid body", code: "BAD_REQUEST" }, 400);
  }

  const { event, device_id, ts, properties = {} } = parsed.data;

  // 1. Validate event name
  if (!VALID_EVENTS.has(event)) {
    return c.json({ error: "Unknown event", code: "UNKNOWN_EVENT" }, 422);
  }

  // 2. Strip unknown property keys (silent — clients may send extra on upgrade)
  const safeProps: Record<string, string | number | boolean> = {};
  for (const [key, val] of Object.entries(properties)) {
    if (!VALID_PROPERTY_KEYS.has(key)) continue;

    // 3. Validate string values against allowlists
    if (typeof val === "string") {
      const allowed = VALID_STRING_VALUES[key];
      if (allowed && !allowed.has(val)) continue;  // silently drop invalid value
    }

    safeProps[key] = val;
  }

  // 4. Emit as a structured log line — no DB write, no PII
  console.log(JSON.stringify({
    log_type:  "client_event",
    event,
    device_id: hashDeviceID(device_id),   // one-way hash before logging
    properties: safeProps,
    ts:        ts ?? new Date().toISOString(),
  }));

  return c.json({ ok: true });
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Hash the device ID before logging so raw IDs never appear in logs.
 * Consistent hashing still enables per-device cohort analysis.
 */
function hashDeviceID(id: string): string {
  return createHash("sha256").update(id).digest("hex").slice(0, 16);
}

export { telemetryRouter };
