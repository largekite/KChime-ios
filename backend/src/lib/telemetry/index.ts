// Structured telemetry logger for the /generateReplies endpoint.
//
// Emits one JSON line per generation event to stdout.
// Vercel Logs and AWS CloudWatch both consume stdout as structured logs.
//
// PRIVACY: message content is NEVER included. Only metadata is logged.

export interface GenerateRepliesTelemetry {
  event: "generate_replies";
  latency_ms: number;
  tokens_used: number | null;
  profile_label: string;
  relationship_used: boolean;
  constraints_used: boolean;
  style_used: boolean;
  cached: boolean;
  streaming: boolean;
  success: boolean;
  user_type: "pro" | "free" | "anonymous";
  error_code?: string;
}

export function emitTelemetry(evt: GenerateRepliesTelemetry): void {
  console.log(JSON.stringify({ ...evt, ts: new Date().toISOString() }));
}
