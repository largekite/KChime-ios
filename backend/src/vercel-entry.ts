// Vercel Node.js serverless function entry point.
// Wraps the Hono app's fetch handler in a standard Node.js request listener.
// This file is bundled → dist/vercel.js and used as the Vercel function.

import "dotenv/config";
import type { IncomingMessage, ServerResponse } from "http";
import { createApp } from "./app.js";

const app = createApp();

export default async function handler(
  req: IncomingMessage,
  res: ServerResponse
): Promise<void> {
  const proto =
    (req.headers["x-forwarded-proto"] as string | undefined) ?? "https";
  const host = req.headers["host"] ?? "localhost";
  const url = new URL(req.url ?? "/", `${proto}://${host}`);

  // Buffer the request body
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.from(chunk as ArrayBufferLike));
  }
  const body = chunks.length > 0 ? Buffer.concat(chunks) : undefined;

  const fetchReq = new Request(url.toString(), {
    method: req.method ?? "GET",
    headers: req.headers as HeadersInit,
    body: body && body.length > 0 ? body : undefined,
  });

  const response = await app.fetch(fetchReq);

  res.statusCode = response.status;
  response.headers.forEach((value, key) => res.setHeader(key, value));

  const buf = await response.arrayBuffer();
  res.end(Buffer.from(buf));
}
