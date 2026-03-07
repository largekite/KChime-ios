// POST /api/auth/apple
// Verifies an Apple identity token and returns a KChime session JWT.

import { Hono } from "hono";
import { z } from "zod";
import { verifyAppleIdentityToken } from "../lib/auth/apple.js";
import { signSessionToken } from "../lib/auth/middleware.js";
import { upsertUser } from "../lib/db/client.js";

const authRouter = new Hono();

const appleAuthSchema = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  fullName: z
    .object({
      givenName: z.string().optional(),
      familyName: z.string().optional(),
    })
    .optional(),
  deviceID: z.string().optional(),
});

authRouter.post("/apple", async (c) => {
  let rawBody: unknown;
  try {
    rawBody = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON body", code: "BAD_REQUEST" }, 400);
  }

  const parsed = appleAuthSchema.safeParse(rawBody);
  if (!parsed.success) {
    return c.json({ error: "Invalid request body", code: "BAD_REQUEST" }, 400);
  }
  const body = parsed.data;

  let claims;
  try {
    claims = await verifyAppleIdentityToken(body.identityToken);
  } catch (err) {
    console.error("[auth/apple] token verification failed:", err);
    return c.json({ error: "Invalid identity token", code: "INVALID_APPLE_TOKEN" }, 401);
  }

  const user = await upsertUser(claims.sub, body.deviceID);

  const token = await signSessionToken({
    userID: user.id,
    appleUserID: user.appleUserID,
    isPro: user.isPro,
  });

  return c.json({
    token,
    isPro: user.isPro,
    isMax: user.isMax,
    isNewUser: Date.now() - user.createdAt.getTime() < 5_000,
  });
});

export { authRouter };
