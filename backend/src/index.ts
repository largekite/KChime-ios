// Local development entry point.
// Vercel uses the `serve` export from app.ts directly (see vercel.json).

import "dotenv/config";
import { serve } from "@hono/node-server";
import { createApp } from "./app.js";

const app = createApp();
const port = parseInt(process.env["PORT"] ?? "3000", 10);

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`KChime API running on http://localhost:${info.port}`);
});
