// POST /api/webhooks/revenuecat
// RevenueCat posts subscription lifecycle events here.
// Set the webhook URL in the RevenueCat dashboard → Project → Integrations → Webhooks.

import { Hono } from "hono";
import {
  verifyRevenueCatWebhook,
  handleRevenueCatEvent,
} from "../../lib/payments/revenuecat.js";
import type { RevenueCatEvent } from "../../types/api.js";

const revenuecatWebhookRouter = new Hono();

revenuecatWebhookRouter.post("/", async (c) => {
  const authHeader = c.req.header("Authorization");

  if (!verifyRevenueCatWebhook(authHeader)) {
    return c.json({ error: "Forbidden", code: "BAD_SIGNATURE" }, 403);
  }

  let event: RevenueCatEvent;
  try {
    event = await c.req.json<RevenueCatEvent>();
  } catch {
    return c.json({ error: "Invalid JSON body", code: "BAD_REQUEST" }, 400);
  }

  try {
    await handleRevenueCatEvent(event);
  } catch (err) {
    console.error("[webhook/revenuecat] processing failed:", err);
    // Return 200 so RevenueCat does not retry indefinitely for our own errors
    return c.json({ ok: false, error: "Processing failed" }, 200);
  }

  return c.json({ ok: true });
});

export { revenuecatWebhookRouter };
