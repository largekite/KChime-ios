// GET /api/mobile/usage?feature=keyboard&deviceID=<uuid>

import { Hono } from "hono";
import { optionalAuth } from "../lib/auth/middleware.js";
import { getUsage } from "../lib/db/client.js";

const usageRouter = new Hono();

usageRouter.get("/", optionalAuth, async (c) => {
  const feature = c.req.query("feature");
  const deviceID = c.req.query("deviceID");

  if (!feature) {
    return c.json({ error: "Missing ?feature= query param", code: "BAD_REQUEST" }, 400);
  }

  const auth = c.get("auth");

  const usage = await getUsage({
    feature,
    ...(auth?.userID
      ? { userID: auth.userID }
      : deviceID
      ? { deviceID }
      : {}),
  });

  return c.json({ remaining: usage.remaining, limit: usage.limit, feature });
});

export { usageRouter };
