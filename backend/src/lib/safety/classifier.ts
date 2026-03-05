// Lightweight keyword-based safety classifier.
//
// Designed to catch obvious harmful content before it reaches the AI.
// For production, supplement with OpenAI Moderation API or a dedicated
// content-safety model, which can catch context-dependent violations.

export interface SafetyResult {
  blocked: boolean;
  reason: string | null;
}

const BLOCKED_PATTERNS: ReadonlyArray<RegExp> = [
  // Threats / violence
  /\b(kill\s+you|murder|bomb|explosive\s+device|shoot\s+up)\b/i,
  // Self-harm
  /\b(self.?harm|suicide\s+method|how\s+to\s+die)\b/i,
  // Scams / fraud
  /\b(phishing|account\s+credentials|send\s+me\s+your\s+password)\b/i,
  // Illegal activity
  /\b(buy\s+(drugs?|cocaine|heroin|meth)|darkweb\s+market)\b/i,
];

/**
 * Returns { blocked: true, reason } if the text violates content policy,
 * otherwise { blocked: false, reason: null }.
 *
 * Only `text` is inspected — no PII logging.
 */
export function checkSafety(text: string): SafetyResult {
  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(text)) {
      return { blocked: true, reason: "content_policy_violation" };
    }
  }
  return { blocked: false, reason: null };
}
