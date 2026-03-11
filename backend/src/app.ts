// Hono app factory — used by both local dev server and Vercel edge handler.

import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { secureHeaders } from "hono/secure-headers";
import { authRouter } from "./routes/auth.js";
import { replyRouter } from "./routes/reply.js";
import { generateRepliesRouter } from "./routes/generateReplies.js";
import { usageRouter } from "./routes/usage.js";
import { accountRouter } from "./routes/account.js";
import { revenuecatWebhookRouter } from "./routes/webhooks/revenuecat.js";
import { telemetryRouter } from "./routes/telemetry.js";
import { fixMessageRouter } from "./routes/fix-message.js";

export function createApp(): Hono {
  const app = new Hono();

  // ─── Global middleware ───────────────────────────────────────────────────────
  app.use("*", logger());
  app.use("*", secureHeaders());
  app.use(
    "/api/*",
    cors({
      origin: process.env["ALLOWED_ORIGINS"]?.split(",") ?? ["*"],
      allowMethods: ["GET", "POST", "DELETE", "OPTIONS"],
      allowHeaders: ["Content-Type", "Authorization", "X-Device-ID"],
    })
  );

  // ─── Health check ────────────────────────────────────────────────────────────
  app.get("/api/health", (c) =>
    c.json({ status: "ok", version: process.env["npm_package_version"] ?? "0.0.0" })
  );

  // ─── Routes ──────────────────────────────────────────────────────────────────
  app.route("/api/auth", authRouter);
  app.route("/api/mobile/reply", replyRouter);
  app.route("/api/v2/generateReplies", generateRepliesRouter);
  app.route("/api/mobile/usage", usageRouter);
  app.route("/api/mobile/account", accountRouter);
  app.route("/api/webhooks/revenuecat", revenuecatWebhookRouter);
  app.route("/api/telemetry/event", telemetryRouter);
  app.route("/api/mobile/fix-message", fixMessageRouter);

  // ─── 404 fallback ────────────────────────────────────────────────────────────
  app.notFound((c) => c.json({ error: "Not found", code: "NOT_FOUND" }, 404));

  app.onError((err, c) => {
    console.error("[app] unhandled error:", err);
    return c.json({ error: "Internal server error", code: "SERVER_ERROR" }, 500);
  });

  return app;
}
