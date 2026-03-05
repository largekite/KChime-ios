// RevenueCat server-side integration
// - Webhook handler (route: POST /api/webhooks/revenuecat)
// - Entitlement verification via RevenueCat REST API

import { timingSafeEqual } from "node:crypto";
import type { RevenueCatEvent } from "../../types/api.js";
import { setUserPro, findUserByAppleID } from "../db/client.js";

const REVENUECAT_API_BASE = "https://api.revenuecat.com/v1";

// Grace period before revoking Pro after a BILLING_ISSUE (24 hours).
const BILLING_ISSUE_GRACE_MS = 24 * 60 * 60 * 1000;

// ─── Webhook processing ───────────────────────────────────────────────────────

/**
 * Verify the RevenueCat webhook Authorization header using a
 * timing-safe comparison to prevent secret oracle attacks.
 * RC sends: `Authorization: <webhook_secret>` (plain string, not Bearer).
 */
export function verifyRevenueCatWebhook(authHeader: string | undefined): boolean {
  const secret = process.env["REVENUECAT_WEBHOOK_SECRET"];
  if (!secret) throw new Error("REVENUECAT_WEBHOOK_SECRET not set");
  if (!authHeader) return false;
  try {
    const a = Buffer.from(secret, "utf8");
    const b = Buffer.from(authHeader, "utf8");
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

/**
 * Process a RevenueCat webhook event and update the user's pro status in the DB.
 */
export async function handleRevenueCatEvent(event: RevenueCatEvent): Promise<void> {
  const { type, app_user_id: appleUserID, expiration_at_ms } = event.event;

  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION": {
      const expiresAt = expiration_at_ms ? new Date(expiration_at_ms) : undefined;
      await setUserPro(appleUserID, true, expiresAt);
      console.log(JSON.stringify({
        event: "revenuecat_webhook", type, user: appleUserID,
        expiresAt: expiresAt?.toISOString() ?? null,
      }));
      break;
    }
    case "CANCELLATION":
    case "EXPIRATION": {
      // Revoke immediately — subscription has definitively ended.
      await setUserPro(appleUserID, false);
      console.log(JSON.stringify({ event: "revenuecat_webhook", type, user: appleUserID }));
      break;
    }
    case "BILLING_ISSUE": {
      // Give a 24-hour grace period; RC will retry and send RENEWAL or EXPIRATION.
      const gracePeriodEnd = new Date(Date.now() + BILLING_ISSUE_GRACE_MS);
      await setUserPro(appleUserID, true, gracePeriodEnd);
      console.log(JSON.stringify({
        event: "revenuecat_webhook", type, user: appleUserID,
        gracePeriodEnd: gracePeriodEnd.toISOString(),
      }));
      break;
    }
    default:
      // SUBSCRIBER_ALIAS, NON_RENEWING_PURCHASE, TEST, etc. — no-op
      break;
  }
}

// ─── Entitlement check ────────────────────────────────────────────────────────

interface RevenueCatSubscriber {
  entitlements: Record<string, { expires_date: string | null; is_active: boolean }>;
}

/**
 * Fetch the subscriber's entitlements directly from RevenueCat.
 * Use this for real-time checks (e.g. after purchase restore).
 * For normal usage, rely on the DB flag updated by webhooks.
 */
export async function fetchEntitlements(
  appleUserID: string
): Promise<{ isPro: boolean; expiresAt?: Date }> {
  const apiKey = process.env["REVENUECAT_API_KEY"];
  if (!apiKey) throw new Error("REVENUECAT_API_KEY not set");

  const res = await fetch(`${REVENUECAT_API_BASE}/subscribers/${encodeURIComponent(appleUserID)}`, {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!res.ok) {
    throw new Error(`RevenueCat API error: ${res.status}`);
  }

  const data = (await res.json()) as { subscriber: RevenueCatSubscriber };
  const pro = data.subscriber.entitlements["pro"];

  if (!pro?.is_active) return { isPro: false };

  return {
    isPro: true,
    ...(pro.expires_date ? { expiresAt: new Date(pro.expires_date) } : {}),
  };
}

/**
 * Get the current entitlement status for a user from the DB.
 * Checks expiry in-process so expired rows count as free without an extra RC call.
 */
export async function getEntitlement(
  appleUserID: string
): Promise<{ isPro: boolean; expiresAt: string | null }> {
  const user = await findUserByAppleID(appleUserID);
  if (!user) return { isPro: false, expiresAt: null };

  const expired = user.proExpiresAt != null && user.proExpiresAt < new Date();
  const isPro = user.isPro && !expired;

  return {
    isPro,
    expiresAt: user.proExpiresAt?.toISOString() ?? null,
  };
}
