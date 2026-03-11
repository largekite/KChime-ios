import Anthropic from "@anthropic-ai/sdk";
import type { AIProvider, GenerateParams, RawPromptParams } from "./index.js";
import type { GenerateResult } from "./prompt-builder.js";
import { buildPrompt, parseGenerateResult } from "./prompt-builder.js";

export class AnthropicProvider implements AIProvider {
  readonly name = "anthropic";
  private client: Anthropic;

  constructor() {
    this.client = new Anthropic({
      apiKey: process.env["ANTHROPIC_API_KEY"],
    });
  }

  async generateReplies(params: GenerateParams): Promise<GenerateResult> {
    const { system, user } = buildPrompt(params);

    const message = await this.client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 768,
      system,
      messages: [{ role: "user", content: user }],
    });

    const block = message.content[0];
    const raw = block?.type === "text" ? block.text : "{}";
    const result = parseGenerateResult(raw);
    result.tokensUsed = message.usage.input_tokens + message.usage.output_tokens;
    return result;
  }

  async generateRaw(params: RawPromptParams): Promise<string> {
    const message = await this.client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system: params.system,
      messages: [{ role: "user", content: params.user }],
    });
    const block = message.content[0];
    return block?.type === "text" ? block.text : "{}";
  }
}
