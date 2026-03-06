// /api/mobile/account — account management endpoints.
// GET  /entitlement — return current pro status (requires auth)
// DELETE /         — GDPR/App Store compliant account deletion

import { Hono } from "hono";
import { requireAuth, optionalAuth } from "../lib/auth/middleware.js";
import { deleteUser } from "../lib/db/client.js";
import { getEntitlement } from "../lib/payments/revenuecat.js";
import postgres from "postgres";
const sql = postgres(process.env["DATABASE_URL"]!, { ssl: "require", prepare: false });

const accountRouter = new Hono();

// GET /api/mobile/account/entitlement
// Returns the current pro entitlement status from the DB (fast path, no RC API call).
// Useful for app-launch sync and after restore-purchases flows.
accountRouter.get("/entitlement", requireAuth, async (c) => {
  const { appleUserID } = c.get("auth");
  const entitlement = await getEntitlement(appleUserID);
  return c.json(entitlement);
});

accountRouter.delete("/", optionalAuth, async (c) => {
  const auth = c.get("auth");
  const deviceID = c.req.header("X-Device-ID") ?? c.get("deviceID");

  if (auth?.userID) {
    await deleteUser(auth.userID);
    return c.json({ deleted: true, scope: "user" });
  }

  if (deviceID) {
    await sql`DELETE FROM usage_logs WHERE device_id = ${deviceID}`;
    return c.json({ deleted: true, scope: "device" });
  }

  return c.json({ error: "No identity provided", code: "NO_IDENTITY" }, 400);
});

export { accountRouter };
