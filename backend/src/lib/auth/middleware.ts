// Hono middleware — validates the KChime session JWT on protected routes.
// The JWT is issued by POST /api/auth/apple after verifying the Apple identity token.

import type { Context, Next } from "hono";
import { jwtVerify, SignJWT } from "jose";

const JWT_ALG = "HS256";

function getJwtSecret(): Uint8Array {
  const secret = process.env["JWT_SECRET"];
  if (!secret) throw new Error("JWT_SECRET env var not set");
  return new TextEncoder().encode(secret);
}

// Attach to Hono context for downstream route handlers
export interface AuthContext {
  userID: string;
  appleUserID: string;
  isPro: boolean;
}

declare module "hono" {
  interface ContextVariableMap {
    auth: AuthContext;
    deviceID?: string;
  }
}

export async function requireAuth(c: Context, next: Next): Promise<void | Response> {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return c.json({ error: "Unauthorized", code: "NO_TOKEN" }, 401);
  }

  const token = authHeader.slice(7);
  try {
    const { payload } = await jwtVerify(token, getJwtSecret(), {
      algorithms: [JWT_ALG],
    });

    c.set("auth", {
      userID: payload["sub"] as string,
      appleUserID: payload["appleUserID"] as string,
      isPro: Boolean(payload["isPro"]),
    });
    await next();
  } catch {
    return c.json({ error: "Invalid or expired token", code: "BAD_TOKEN" }, 401);
  }
}

// Optional auth — populates auth if present, continues either way
export async function optionalAuth(c: Context, next: Next): Promise<void> {
  const authHeader = c.req.header("Authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice(7);
    try {
      const { payload } = await jwtVerify(token, getJwtSecret(), {
        algorithms: [JWT_ALG],
      });
      c.set("auth", {
        userID: payload["sub"] as string,
        appleUserID: payload["appleUserID"] as string,
        isPro: Boolean(payload["isPro"]),
      });
    } catch {
      // Ignore invalid token for optional auth
    }
  }

  const deviceID = c.req.header("X-Device-ID");
  if (deviceID) c.set("deviceID", deviceID);

  await next();
}

export async function signSessionToken(params: {
  userID: string;
  appleUserID: string;
  isPro: boolean;
}): Promise<string> {
  return new SignJWT({
    appleUserID: params.appleUserID,
    isPro: params.isPro,
  })
    .setProtectedHeader({ alg: JWT_ALG })
    .setSubject(params.userID)
    .setIssuedAt()
    .setExpirationTime("90d")
    .sign(getJwtSecret());
}
