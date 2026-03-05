// AI provider abstraction — swap OpenAI for Anthropic without touching route handlers.

import type { ToneProfilePayload, RelationshipProfilePayload } from "../../types/api.js";
export type { GenerateResult } from "./prompt-builder.js";
import type { GenerateResult } from "./prompt-builder.js";
import type { PromptConstraints, PromptStyle } from "./prompt-builder.js";

// ─── Shared params type ───────────────────────────────────────────────────────

export interface GenerateParams {
  receivedMessage: string;
  userDraft?: string;
  toneProfile: ToneProfilePayload;
  relationshipProfile?: RelationshipProfilePayload;
  contactNotes?: string;
  constraints?: PromptConstraints;
  style?: PromptStyle;
}

// ─── Provider interface ───────────────────────────────────────────────────────

export interface AIProvider {
  name: string;
  generateReplies(params: GenerateParams): Promise<GenerateResult>;
}

// ─── Providers ────────────────────────────────────────────────────────────────

import { OpenAIProvider } from "./openai.js";
import { AnthropicProvider } from "./anthropic.js";

export function createAIProvider(): AIProvider {
  if (process.env["OPENAI_API_KEY"]) return new OpenAIProvider();
  if (process.env["ANTHROPIC_API_KEY"]) return new AnthropicProvider();
  throw new Error("No AI provider configured. Set OPENAI_API_KEY or ANTHROPIC_API_KEY.");
}

// ─── Fallback wrapper ─────────────────────────────────────────────────────────

/**
 * Tries OpenAI first; on any error falls back to Anthropic.
 * Both must be configured; if only one is set, use createAIProvider() instead.
 */
export class FallbackAIProvider implements AIProvider {
  readonly name = "fallback";
  private primary: AIProvider;
  private secondary: AIProvider;

  constructor() {
    this.primary = new OpenAIProvider();
    this.secondary = new AnthropicProvider();
  }

  async generateReplies(params: GenerateParams): Promise<GenerateResult> {
    try {
      return await this.primary.generateReplies(params);
    } catch (err) {
      console.warn(`[AI] Primary "${this.primary.name}" failed, falling back:`, err);
      return await this.secondary.generateReplies(params);
    }
  }
}
