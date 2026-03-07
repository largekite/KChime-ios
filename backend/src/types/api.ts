// Shared API contract — mirrors the Swift models in Shared/Networking/KChimeAPIClient.swift
// Keep both files in sync when adding fields.

// ─── Tone Profile ─────────────────────────────────────────────────────────────

export interface ToneProfilePayload {
  label: string;
  formality: number;                              // 0.0 – 1.0 (user's personal style)
  emojiEnabled: boolean;
  lengthPreference: "short" | "medium" | "verbose"; // matches Swift LengthPreference.rawValue
  customInstructions?: string;
}

// ─── Relationship Profile ─────────────────────────────────────────────────────

/**
 * Describes the relationship between the user and the person they're replying to.
 * All numeric dimensions are 0–10 integers.
 * Sent alongside ToneProfilePayload; the backend prompt builder combines both.
 */
export interface RelationshipProfilePayload {
  name: string;          // "Boss" | "Coworker" | "Client" | "Teacher" | "Friend" | "Family" | custom
  formality: number;     // 0–10: how formal the relationship requires (10 = very formal)
  warmth: number;        // 0–10: how warm/friendly to be (10 = very warm)
  brevity: number;       // 0–10: how brief to keep the reply (10 = one sentence max)
  emojiAllowed: boolean; // whether emoji are appropriate in this relationship
  directness: number;    // 0–10: how direct/blunt to be (10 = very direct)
}

// ─── Request / Response ───────────────────────────────────────────────────────

export interface ReplyRequest {
  featureKey: string;                              // "keyboard" | "share-extension"
  receivedMessage: string;
  toneProfile: ToneProfilePayload;
  relationshipProfile?: RelationshipProfilePayload; // optional; if absent, no relationship context
  contactNotes?: string;
  deviceID: string;
}

export interface ReplyResponse {
  suggestions: string[];       // exactly 3 short/medium replies
  longerAlternative: string;   // 1 fuller 2-3 sentence reply
  remaining: number;
  limit: number;
}

export interface UsageResponse {
  remaining: number;
  limit: number;
  feature: string;
}

// ─── /api/v2/generateReplies ──────────────────────────────────────────────────

export interface GenerateRepliesRequest {
  incomingText: string;
  userDraft?: string;
  toneProfile: ToneProfilePayload;
  relationshipProfile?: RelationshipProfilePayload;
  contactNotes?: string;
  constraints?: {
    maxChars?: number;   // hard character limit per suggestion
    language?: string;   // ISO 639-1, e.g. "en" (default) or "es"
  };
  style?: {
    avoidApologies?: boolean;
    includeCTA?: boolean;
  };
  featureKey?: string;  // default "keyboard"
  deviceID: string;
}

export interface GenerateRepliesResponse {
  suggestions: string[];
  alternatives: {
    longer: string;
    shorter: string;
  };
  safety: {
    blocked: boolean;
    reason: string | null;
  };
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

export interface AuthAppleRequest {
  identityToken: string;   // JWT from Sign in with Apple
  authorizationCode: string;
  fullName?: { givenName?: string; familyName?: string };
}

export interface AuthResponse {
  token: string;           // KChime session JWT
  isPro: boolean;
  isMax: boolean;
  isNewUser: boolean;
}

export interface ErrorResponse {
  error: string;
  code?: string;
}

// ─── RevenueCat webhook ───────────────────────────────────────────────────────

export interface RevenueCatEvent {
  event: {
    type: RevenueCatEventType;
    app_user_id: string;
    product_id: string;
    period_type?: "NORMAL" | "TRIAL" | "INTRO";
    expiration_at_ms?: number;
    environment: "SANDBOX" | "PRODUCTION";
  };
  api_version: string;
}

export type RevenueCatEventType =
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "CANCELLATION"
  | "UNCANCELLATION"
  | "BILLING_ISSUE"
  | "SUBSCRIBER_ALIAS"
  | "EXPIRATION"
  | "NON_RENEWING_PURCHASE";

// ─── Internal ─────────────────────────────────────────────────────────────────

export interface KChimeUser {
  id: string;
  appleUserID: string;
  deviceID?: string;
  isPro: boolean;
  isMax: boolean;
  proExpiresAt?: Date;
  createdAt: Date;
}
