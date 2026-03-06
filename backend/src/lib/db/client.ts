// Database client — Supabase (postgres.js).
// Set DATABASE_URL in .env to your Supabase connection string.
// Use the "Transaction" pooler (port 6543) for serverless — requires prepare:false.
// Run migrations once by calling runMigrations() or via the Supabase SQL editor.

import postgres from "postgres";
import type { KChimeUser } from "../../types/api.js";

// prepare:false is required when connecting through Supabase's pgBouncer pooler.
const sql = postgres(process.env["DATABASE_URL"]!, {
  ssl: "require",
  prepare: false,
});

// ─── Bootstrap ────────────────────────────────────────────────────────────────

export async function runMigrations(): Promise<void> {
  await sql`
    CREATE TABLE IF NOT EXISTS users (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      apple_user_id   TEXT UNIQUE NOT NULL,
      device_id       TEXT,
      is_pro          BOOLEAN NOT NULL DEFAULT false,
      pro_expires_at  TIMESTAMPTZ,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS usage_logs (
      id          BIGSERIAL PRIMARY KEY,
      user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
      device_id   TEXT,
      feature     TEXT NOT NULL,
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `;

  await sql`
    CREATE INDEX IF NOT EXISTS usage_logs_user_day
      ON usage_logs (user_id, feature, created_at);
  `;

  await sql`
    CREATE INDEX IF NOT EXISTS usage_logs_device_day
      ON usage_logs (device_id, feature, created_at);
  `;

  await sql`
    ALTER TABLE usage_logs ADD COLUMN IF NOT EXISTS tokens_used INTEGER;
  `;
}

// ─── User Queries ─────────────────────────────────────────────────────────────

type UserRow = {
  id: string;
  apple_user_id: string;
  device_id: string | null;
  is_pro: boolean;
  pro_expires_at: string | null;
  created_at: string;
};

export async function findUserByAppleID(
  appleUserID: string
): Promise<KChimeUser | null> {
  const rows = await sql<UserRow[]>`
    SELECT * FROM users WHERE apple_user_id = ${appleUserID} LIMIT 1
  `;
  const row = rows[0];
  if (!row) return null;
  return rowToUser(row);
}

export async function upsertUser(appleUserID: string, deviceID?: string): Promise<KChimeUser> {
  const rows = await sql<UserRow[]>`
    INSERT INTO users (apple_user_id, device_id)
    VALUES (${appleUserID}, ${deviceID ?? null})
    ON CONFLICT (apple_user_id) DO UPDATE
      SET device_id = COALESCE(EXCLUDED.device_id, users.device_id)
    RETURNING *
  `;
  const row = rows[0];
  if (!row) throw new Error("upsertUser: no row returned");
  return rowToUser(row);
}

export async function setUserPro(
  appleUserID: string,
  isPro: boolean,
  expiresAt?: Date
): Promise<void> {
  await sql`
    UPDATE users
    SET is_pro = ${isPro}, pro_expires_at = ${expiresAt?.toISOString() ?? null}
    WHERE apple_user_id = ${appleUserID}
  `;
}

export async function deleteUser(userID: string): Promise<void> {
  await sql`DELETE FROM users WHERE id = ${userID}::uuid`;
}

// ─── Usage Queries ────────────────────────────────────────────────────────────

const FREE_LIMIT = 5;
const PRO_LIMIT = 10_000;

export async function getUsage(params: {
  userID?: string;
  deviceID?: string;
  feature: string;
}): Promise<{ used: number; limit: number; remaining: number }> {
  const limit = params.userID
    ? (await isProUser(params.userID)) ? PRO_LIMIT : FREE_LIMIT
    : FREE_LIMIT;

  let rows: { count: string }[];
  if (params.userID) {
    rows = await sql<{ count: string }[]>`
      SELECT COUNT(*) as count FROM usage_logs
      WHERE feature = ${params.feature}
        AND user_id = ${params.userID}::uuid
        AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC')
    `;
  } else {
    rows = await sql<{ count: string }[]>`
      SELECT COUNT(*) as count FROM usage_logs
      WHERE feature = ${params.feature}
        AND device_id = ${params.deviceID ?? ""}
        AND user_id IS NULL
        AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC')
    `;
  }

  const used = parseInt(rows[0]?.count ?? "0", 10);
  return { used, limit, remaining: Math.max(0, limit - used) };
}

export async function recordUsage(params: {
  userID?: string;
  deviceID?: string;
  feature: string;
  tokensUsed?: number;
}): Promise<void> {
  if (params.userID) {
    await sql`
      INSERT INTO usage_logs (user_id, device_id, feature, tokens_used)
      VALUES (${params.userID}::uuid, ${params.deviceID ?? null}, ${params.feature}, ${params.tokensUsed ?? null})
    `;
  } else {
    await sql`
      INSERT INTO usage_logs (user_id, device_id, feature, tokens_used)
      VALUES (NULL, ${params.deviceID ?? null}, ${params.feature}, ${params.tokensUsed ?? null})
    `;
  }
}

export async function getDailyTokensFromDB(params: {
  userID?: string;
  deviceID?: string;
  feature: string;
}): Promise<number> {
  let rows: { total: string }[];
  if (params.userID) {
    rows = await sql<{ total: string }[]>`
      SELECT COALESCE(SUM(tokens_used), 0) AS total FROM usage_logs
      WHERE feature = ${params.feature} AND tokens_used IS NOT NULL
        AND user_id = ${params.userID}::uuid
        AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC')
    `;
  } else {
    rows = await sql<{ total: string }[]>`
      SELECT COALESCE(SUM(tokens_used), 0) AS total FROM usage_logs
      WHERE feature = ${params.feature} AND tokens_used IS NOT NULL
        AND device_id = ${params.deviceID ?? ""}
        AND user_id IS NULL
        AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC')
    `;
  }
  return parseInt(rows[0]?.total ?? "0", 10);
}

async function isProUser(userID: string): Promise<boolean> {
  const rows = await sql<{ is_pro: boolean }[]>`
    SELECT is_pro FROM users WHERE id = ${userID}::uuid LIMIT 1
  `;
  return rows[0]?.is_pro ?? false;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function rowToUser(row: UserRow): KChimeUser {
  return {
    id: row.id,
    appleUserID: row.apple_user_id,
    isPro: row.is_pro,
    createdAt: new Date(row.created_at),
    ...(row.device_id !== null ? { deviceID: row.device_id } : {}),
    ...(row.pro_expires_at !== null ? { proExpiresAt: new Date(row.pro_expires_at) } : {}),
  };
}
