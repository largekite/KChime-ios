// Sign in with Apple — server-side identity token (JWT) verification
// Spec: https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api

import { createRemoteJWKSet, jwtVerify } from "jose";

const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_ISSUER = "https://appleid.apple.com";

// Cache the JWKS so we don't fetch on every request
const appleJWKS = createRemoteJWKSet(new URL(APPLE_JWKS_URL));

export interface AppleIdentityClaims {
  sub: string;        // Apple User ID (stable per app)
  email?: string;
  email_verified?: boolean;
  is_private_email?: boolean;
  iss: string;
  aud: string | string[];
  exp: number;
  iat: number;
}

/**
 * Verify an Apple identity token and return the claims.
 * Throws if the token is invalid, expired, or has wrong audience.
 */
export async function verifyAppleIdentityToken(
  identityToken: string
): Promise<AppleIdentityClaims> {
  const bundleId = process.env["APPLE_CLIENT_ID"];
  if (!bundleId) throw new Error("APPLE_CLIENT_ID env var not set");

  const { payload } = await jwtVerify(identityToken, appleJWKS, {
    issuer: APPLE_ISSUER,
    audience: bundleId,
  });

  return payload as unknown as AppleIdentityClaims;
}
