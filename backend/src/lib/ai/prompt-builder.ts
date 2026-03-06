// Prompt builder for KChime reply generation.
//
// Takes the user's personal ToneProfile + an optional RelationshipProfile
// (who they're writing to) and produces a system + user prompt pair.
//
// Output contract: the AI must return a JSON object:
//   { "suggestions": ["...", "...", "..."], "longerAlternative": "..." }
//
// The 3 suggestions follow the brevity setting of the relationship profile.
// The longerAlternative is always 2-3 full sentences regardless of brevity.

import type { ToneProfilePayload, RelationshipProfilePayload } from "../../types/api.js";

// ─── Input ────────────────────────────────────────────────────────────────────

export interface PromptConstraints {
  maxChars?: number;   // hard character limit per suggestion (default: none)
  language?: string;   // ISO 639-1 reply language, e.g. "en", "es" (default: "en")
}

export interface PromptStyle {
  avoidApologies?: boolean;  // suppress openers like "Sorry" / "I apologize"
  includeCTA?: boolean;      // end each reply with a call-to-action where natural
}

export interface PromptParams {
  receivedMessage: string;
  userDraft?: string;
  toneProfile: ToneProfilePayload;
  relationshipProfile?: RelationshipProfilePayload;
  contactNotes?: string;
  constraints?: PromptConstraints;
  style?: PromptStyle;
}

// ─── Output ───────────────────────────────────────────────────────────────────

export interface GenerateResult {
  suggestions: string[];      // exactly 3 short/medium replies
  longerAlternative: string;  // 1 fuller, 2-3 sentence reply
  shorterAlternative: string; // 1 ultra-concise reply (≤ 10 words)
  tokensUsed?: number;        // populated by the AI provider when available
}

// ─── Prompt builder ──────────────────────────────────────────────────────────

export function buildPrompt(params: PromptParams): { system: string; user: string } {
  const { receivedMessage, userDraft, toneProfile, relationshipProfile, contactNotes, constraints, style } = params;

  const lines: string[] = [];

  // 1. Core role
  lines.push("You are KChime, a message reply assistant.");

  // 2. Relationship context (who the user is writing to)
  if (relationshipProfile) {
    lines.push(buildRelationshipBlock(relationshipProfile));
  }

  // 3. User's personal style
  lines.push(buildPersonalStyleBlock(toneProfile, !!relationshipProfile));

  // 4. Contact context
  if (contactNotes) {
    lines.push(`Context about this person: ${contactNotes}`);
  }

  // 5. Constraints
  const constraintLines = buildConstraintBlock(constraints, style);
  if (constraintLines) lines.push(constraintLines);

  // 6. Output contract
  lines.push(buildOutputFormatBlock(relationshipProfile, constraints));

  const system = lines.join("\n\n");

  const userParts = [`Message to reply to:\n\n"${receivedMessage}"`];
  if (userDraft) {
    userParts.push(`\nUser's draft (improve or use as inspiration):\n\n"${userDraft}"`);
  }

  return { system, user: userParts.join("") };
}

// ─── Block builders ──────────────────────────────────────────────────────────

function buildRelationshipBlock(rel: RelationshipProfilePayload): string {
  const parts: string[] = [
    `You are writing a reply on behalf of someone responding to their ${rel.name}.`,
    `Adapt the tone to this relationship:`,
    `- Formality: ${scoreDesc(rel.formality, ["very casual", "casual", "moderate", "formal", "very formal"])} (${rel.formality}/10)`,
    `- Warmth: ${scoreDesc(rel.warmth, ["cold and distant", "reserved", "cordial", "warm", "very warm"])} (${rel.warmth}/10)`,
    `- Brevity: ${scoreDesc(rel.brevity, ["can be elaborate", "balanced length", "fairly brief", "brief", "very brief — one sentence if possible"])} (${rel.brevity}/10)`,
    `- Directness: ${scoreDesc(rel.directness, ["gentle and indirect", "slightly indirect", "balanced", "direct", "very direct and to-the-point"])} (${rel.directness}/10)`,
    `- Emoji: ${rel.emojiAllowed ? "may use 1 emoji if it fits naturally" : "do not use emoji"}`,
    `The relationship context takes precedence over personal style when they conflict.`,
  ];
  return parts.join("\n");
}

function buildPersonalStyleBlock(
  tone: ToneProfilePayload,
  hasRelationship: boolean
): string {
  const formalityLabel =
    tone.formality < 0.3
      ? "casual"
      : tone.formality < 0.6
      ? "balanced"
      : "formal";

  const lengthLabel =
    tone.lengthPreference === "short"
      ? "concise (under 20 words)"
      : tone.lengthPreference === "verbose"
      ? "thorough (2-3 sentences)"
      : "moderate (1-2 sentences)";

  const emojiNote =
    tone.emojiEnabled
      ? "may use emoji in personal style"
      : "prefers no emoji";

  const qualifier = hasRelationship
    ? "The user's personal message style (apply where it doesn't conflict with the relationship context above):"
    : "User's message style:";

  const parts = [
    `${qualifier} ${formalityLabel} formality, ${lengthLabel} replies, ${emojiNote}.`,
  ];

  if (tone.customInstructions) {
    parts.push(`Additional style note: ${tone.customInstructions}`);
  }

  return parts.join(" ");
}

function buildConstraintBlock(constraints?: PromptConstraints, style?: PromptStyle): string {
  const parts: string[] = [];
  if (constraints?.language && constraints.language !== "en") {
    parts.push(`Reply in ${constraints.language} language.`);
  }
  if (constraints?.maxChars) {
    parts.push(`Each suggestion must be at most ${constraints.maxChars} characters.`);
  }
  if (style?.avoidApologies) {
    parts.push(`Do not start any reply with an apology (e.g. "Sorry", "I apologize", "Apologies").`);
  }
  if (style?.includeCTA) {
    parts.push(`End each reply with a clear call-to-action where it fits naturally.`);
  }
  return parts.join(" ");
}

function buildOutputFormatBlock(rel?: RelationshipProfilePayload, constraints?: PromptConstraints): string {
  // Length guidance for the 3 short suggestions
  const brevityScore = rel?.brevity ?? 5;
  const shortGuidance =
    brevityScore >= 7
      ? "Keep each of the 3 suggestions to 1 sentence or under 20 words."
      : brevityScore >= 4
      ? "Keep each of the 3 suggestions to 1-2 sentences."
      : "Each of the 3 suggestions can be 1-3 sentences.";

  const charNote = constraints?.maxChars
    ? ` Each suggestion must stay under ${constraints.maxChars} characters.`
    : "";

  return [
    `Generate exactly 3 reply suggestions, 1 longer alternative, and 1 shorter alternative.`,
    shortGuidance + charNote,
    `The longerAlternative must be 2-3 full sentences (useful when a more thorough response is warranted).`,
    `The shorterAlternative must be extremely concise — a single phrase or at most 10 words.`,
    `Both alternatives follow the same tone and relationship rules.`,
    `Return ONLY a JSON object — no markdown, no explanation, no code fences:`,
    `{"suggestions":["reply 1","reply 2","reply 3"],"longerAlternative":"A more thorough reply...","shorterAlternative":"Brief reply."}`,
  ].join(" ");
}

// ─── Result parser ────────────────────────────────────────────────────────────

const FALLBACK_LONGER = "I appreciate you reaching out. Let me give this some thought and get back to you properly.";
const FALLBACK_SHORTER = "Got it, thanks.";

/**
 * Parse the raw AI output into a GenerateResult.
 * Tolerates minor JSON formatting issues and falls back to line-based parsing.
 */
export function parseGenerateResult(raw: string): GenerateResult {
  // Strip markdown code fences (```json ... ``` or ``` ... ```)
  let trimmed = raw.trim();
  trimmed = trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```\s*$/, "").trim();

  // Try direct JSON parse
  try {
    const parsed: unknown = JSON.parse(trimmed);
    if (isGenerateResultShape(parsed)) {
      return {
        suggestions: parsed.suggestions.slice(0, 3),
        longerAlternative: parsed.longerAlternative,
        shorterAlternative: parsed.shorterAlternative,
      };
    }

    // Model wrapped in a key — extract arrays and alternatives
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      const obj = parsed as Record<string, unknown>;
      const suggestions = extractStringArray(obj);
      const longerAlternative = extractLongerAlternative(obj);
      const shorterAlternative = extractShorterAlternative(obj);
      if (suggestions.length > 0) {
        return { suggestions: suggestions.slice(0, 3), longerAlternative, shorterAlternative };
      }
    }
  } catch {
    // fall through to line-based
  }

  // Line-based fallback
  const lines = trimmed
    .split("\n")
    .map((l) => l.replace(/^[\d.\-*)\s"]+|["]+$/g, "").trim())
    .filter((l) => l.length > 5);

  const suggestions = lines.slice(0, 3);
  const longerAlternative = lines[3] ?? suggestions[0] ?? FALLBACK_LONGER;
  const shorterAlternative = suggestions[0]?.split(/[.,!?]/)[0]?.trim() ?? FALLBACK_SHORTER;

  return {
    suggestions: suggestions.length >= 3 ? suggestions : padSuggestions(suggestions),
    longerAlternative,
    shorterAlternative,
  };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Map a 0-10 integer score to one of 5 prose descriptors.
 * Index 0 = low (0-1), index 4 = high (9-10).
 */
function scoreDesc(score: number, labels: [string, string, string, string, string]): string {
  const idx = Math.min(4, Math.floor(score / 2));
  return labels[idx] ?? labels[2]!;
}

function isGenerateResultShape(
  v: unknown
): v is { suggestions: string[]; longerAlternative: string; shorterAlternative: string } {
  if (!v || typeof v !== "object" || Array.isArray(v)) return false;
  const o = v as Record<string, unknown>;
  return (
    Array.isArray(o["suggestions"]) &&
    (o["suggestions"] as unknown[]).every((s) => typeof s === "string") &&
    typeof o["longerAlternative"] === "string" &&
    typeof o["shorterAlternative"] === "string"
  );
}

function extractStringArray(obj: Record<string, unknown>): string[] {
  for (const val of Object.values(obj)) {
    if (Array.isArray(val) && val.every((s) => typeof s === "string")) {
      return val as string[];
    }
  }
  return [];
}

function extractLongerAlternative(obj: Record<string, unknown>): string {
  for (const key of ["longerAlternative", "longer_alternative", "longer", "detailed", "full"]) {
    if (typeof obj[key] === "string") return obj[key] as string;
  }
  return FALLBACK_LONGER;
}

function extractShorterAlternative(obj: Record<string, unknown>): string {
  for (const key of ["shorterAlternative", "shorter_alternative", "shorter", "brief", "concise"]) {
    if (typeof obj[key] === "string") return obj[key] as string;
  }
  return FALLBACK_SHORTER;
}

function padSuggestions(partial: string[]): string[] {
  const placeholders = [
    "I'll get back to you on that.",
    "Thanks for letting me know.",
    "Sounds good to me.",
  ];
  return [
    ...partial,
    ...placeholders.slice(partial.length),
  ].slice(0, 3);
}
