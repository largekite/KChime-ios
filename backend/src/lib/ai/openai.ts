import OpenAI from "openai";
import type { AIProvider, GenerateParams } from "./index.js";
import type { GenerateResult } from "./prompt-builder.js";
import { buildPrompt, parseGenerateResult } from "./prompt-builder.js";

export class OpenAIProvider implements AIProvider {
  readonly name = "openai";
  private client: OpenAI;

  constructor() {
    this.client = new OpenAI({
      apiKey: process.env["OPENAI_API_KEY"],
    });
  }

  async generateReplies(params: GenerateParams): Promise<GenerateResult> {
    const { system, user } = buildPrompt(params);

    const response = await this.client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      max_tokens: 768,
      temperature: 0.8,
      response_format: { type: "json_object" },
    });

    const raw = response.choices[0]?.message.content ?? "{}";
    const result = parseGenerateResult(raw);
    if (response.usage) {
      result.tokensUsed = response.usage.total_tokens;
    }
    return result;
  }
}
