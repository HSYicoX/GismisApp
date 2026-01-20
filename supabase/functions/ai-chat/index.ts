/**
 * AI Chat Edge Function
 *
 * 提供 AI 助手聊天功能，支持 SSE 流式响应
 *
 * 功能：
 * - 验证 JWT
 * - 接收消息和上下文
 * - 调用 DeepSeek API（支持 deepseek-chat 和 deepseek-reasoner）
 * - 实现 SSE 流式响应
 * - 发送 meta, field_start, delta, field_end, done 事件
 * - 处理错误并发送 error 事件
 * - 保存对话到 ai_conversations 表
 *
 * Requirements: 7.1, 7.2, 7.3, 7.4
 */

import { authenticateRequest } from "../_shared/auth.ts";
import {
  corsHeaders,
  handleCorsPreflightRequest,
  isCorsPreflightRequest,
} from "../_shared/cors.ts";
import { unauthorized, badRequest, internalError } from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

// DeepSeek API 配置
const DEEPSEEK_API_URL =
  Deno.env.get("DEEPSEEK_API_URL") || "https://api.deepseek.com";
const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY") || "";

// 支持的模型
const SUPPORTED_MODELS = ["deepseek-chat", "deepseek-reasoner"] as const;
type SupportedModel = (typeof SUPPORTED_MODELS)[number];

// 请求体类型
interface ChatRequest {
  message: string;
  model?: SupportedModel;
  conversationId?: string;
  context?: ChatMessage[];
}

// 聊天消息类型
interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

// DeepSeek API 响应类型
interface DeepSeekStreamChunk {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: {
    index: number;
    delta: {
      role?: string;
      content?: string;
      reasoning_content?: string;
    };
    finish_reason: string | null;
  }[];
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

/**
 * 生成唯一的消息 ID
 */
function generateMessageId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * 生成唯一的对话 ID
 */
function generateConversationId(): string {
  return `conv_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * 创建 SSE 事件字符串
 */
function createSSEEvent(
  eventType: string,
  data: Record<string, unknown>
): string {
  return `event: ${eventType}\ndata: ${JSON.stringify(data)}\n\n`;
}

/**
 * 保存对话到数据库
 */
async function saveConversation(
  userId: string,
  conversationId: string,
  messages: ChatMessage[],
  model: string,
  tokensUsed: number
): Promise<void> {
  const supabase = getSupabaseAdmin();

  // 生成对话标题（使用第一条用户消息的前 50 个字符）
  const firstUserMessage = messages.find((m) => m.role === "user");
  const title = firstUserMessage
    ? firstUserMessage.content.substring(0, 50) +
      (firstUserMessage.content.length > 50 ? "..." : "")
    : "New Conversation";

  // 尝试更新现有对话，如果不存在则插入新对话
  const { error } = await supabase.from(Tables.AI_CONVERSATIONS).upsert(
    {
      user_id: userId,
      conversation_id: conversationId,
      title,
      messages: JSON.stringify(messages),
      model,
      tokens_used: tokensUsed,
      updated_at: new Date().toISOString(),
    },
    {
      onConflict: "conversation_id",
    }
  );

  if (error) {
    console.error("Failed to save conversation:", error);
  }
}

/**
 * 加载现有对话
 */
async function loadConversation(
  userId: string,
  conversationId: string
): Promise<ChatMessage[] | null> {
  const supabase = getSupabaseAdmin();

  const { data, error } = await supabase
    .from(Tables.AI_CONVERSATIONS)
    .select("messages")
    .eq("user_id", userId)
    .eq("conversation_id", conversationId)
    .single();

  if (error || !data) {
    return null;
  }

  try {
    return JSON.parse(data.messages as string) as ChatMessage[];
  } catch {
    return null;
  }
}

/**
 * 调用 DeepSeek API 并返回流式响应
 */
async function* streamDeepSeekResponse(
  messages: ChatMessage[],
  model: SupportedModel
): AsyncGenerator<DeepSeekStreamChunk | { error: string }> {
  if (!DEEPSEEK_API_KEY) {
    yield { error: "DeepSeek API key not configured" };
    return;
  }

  try {
    const response = await fetch(`${DEEPSEEK_API_URL}/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model,
        messages,
        stream: true,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("DeepSeek API error:", response.status, errorText);
      yield { error: `DeepSeek API error: ${response.status}` };
      return;
    }

    const reader = response.body?.getReader();
    if (!reader) {
      yield { error: "No response body" };
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });

      // 处理 SSE 数据行
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        const trimmedLine = line.trim();
        if (!trimmedLine || trimmedLine === "data: [DONE]") continue;

        if (trimmedLine.startsWith("data: ")) {
          try {
            const jsonStr = trimmedLine.substring(6);
            const chunk = JSON.parse(jsonStr) as DeepSeekStreamChunk;
            yield chunk;
          } catch (e) {
            console.error("Failed to parse chunk:", e, trimmedLine);
          }
        }
      }
    }

    // 处理剩余的 buffer
    if (buffer.trim() && buffer.trim() !== "data: [DONE]") {
      if (buffer.trim().startsWith("data: ")) {
        try {
          const jsonStr = buffer.trim().substring(6);
          const chunk = JSON.parse(jsonStr) as DeepSeekStreamChunk;
          yield chunk;
        } catch (e) {
          console.error("Failed to parse final chunk:", e);
        }
      }
    }
  } catch (e) {
    console.error("DeepSeek stream error:", e);
    yield { error: e instanceof Error ? e.message : "Unknown error" };
  }
}

/**
 * 主处理函数
 */
Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");

  // 处理 CORS 预检请求
  if (isCorsPreflightRequest(req)) {
    return handleCorsPreflightRequest(origin);
  }

  // 只允许 POST 请求
  if (req.method !== "POST") {
    return badRequest("Method not allowed", origin);
  }

  // 验证 JWT
  const authResult = await authenticateRequest(req);
  if (!authResult.success || !authResult.userId) {
    return unauthorized(authResult.error || "Unauthorized", origin);
  }

  const userId = authResult.userId;

  // 解析请求体
  let requestBody: ChatRequest;
  try {
    requestBody = (await req.json()) as ChatRequest;
  } catch {
    return badRequest("Invalid JSON body", origin);
  }

  // 验证必需字段
  if (!requestBody.message || typeof requestBody.message !== "string") {
    return badRequest("Message is required", origin);
  }

  // 验证模型
  const model: SupportedModel = requestBody.model || "deepseek-chat";
  if (!SUPPORTED_MODELS.includes(model)) {
    return badRequest(
      `Invalid model. Supported models: ${SUPPORTED_MODELS.join(", ")}`,
      origin
    );
  }

  // 确定对话 ID
  const conversationId = requestBody.conversationId || generateConversationId();
  const messageId = generateMessageId();

  // 构建消息历史
  let messages: ChatMessage[] = [];

  // 如果有现有对话，加载历史消息
  if (requestBody.conversationId) {
    const existingMessages = await loadConversation(userId, conversationId);
    if (existingMessages) {
      messages = existingMessages;
    }
  }

  // 如果提供了上下文，使用上下文
  if (requestBody.context && requestBody.context.length > 0) {
    messages = requestBody.context;
  }

  // 添加系统提示（如果没有）
  if (!messages.some((m) => m.role === "system")) {
    messages.unshift({
      role: "system",
      content:
        "你是一个专业的动漫助手，可以帮助用户了解动漫信息、推荐动漫、讨论剧情等。请用友好、专业的方式回答用户的问题。",
    });
  }

  // 添加用户消息
  messages.push({
    role: "user",
    content: requestBody.message,
  });

  // 确定要流式传输的字段
  // deepseek-reasoner 模型会返回 reasoning_content 和 content
  // deepseek-chat 模型只返回 content
  const fields =
    model === "deepseek-reasoner" ? ["reasoning", "content"] : ["content"];

  // 创建 SSE 响应流
  const encoder = new TextEncoder();
  let totalTokens = 0;
  let assistantContent = "";
  let reasoningContent = "";

  const stream = new ReadableStream({
    async start(controller) {
      try {
        // 发送 meta 事件
        controller.enqueue(
          encoder.encode(
            createSSEEvent("meta", {
              message_id: messageId,
              conversation_id: conversationId,
              model,
              fields,
            })
          )
        );

        // 跟踪当前正在流式传输的字段
        let currentField: string | null = null;
        let hasStartedContent = false;
        let hasStartedReasoning = false;

        // 流式处理 DeepSeek 响应
        for await (const chunk of streamDeepSeekResponse(messages, model)) {
          // 检查是否是错误
          if ("error" in chunk) {
            controller.enqueue(
              encoder.encode(
                createSSEEvent("error", { message: chunk.error })
              )
            );
            controller.close();
            return;
          }

          // 处理 usage 信息
          if (chunk.usage) {
            totalTokens = chunk.usage.total_tokens;
          }

          // 处理 choices
          for (const choice of chunk.choices) {
            const delta = choice.delta;

            // 处理 reasoning_content（仅 deepseek-reasoner）
            if (delta.reasoning_content) {
              if (!hasStartedReasoning) {
                // 如果之前在流式传输其他字段，先结束它
                if (currentField && currentField !== "reasoning") {
                  controller.enqueue(
                    encoder.encode(
                      createSSEEvent("field_end", { field: currentField })
                    )
                  );
                }
                // 开始 reasoning 字段
                controller.enqueue(
                  encoder.encode(
                    createSSEEvent("field_start", { field: "reasoning" })
                  )
                );
                currentField = "reasoning";
                hasStartedReasoning = true;
              }

              reasoningContent += delta.reasoning_content;
              controller.enqueue(
                encoder.encode(
                  createSSEEvent("delta", {
                    field: "reasoning",
                    text: delta.reasoning_content,
                  })
                )
              );
            }

            // 处理 content
            if (delta.content) {
              if (!hasStartedContent) {
                // 如果之前在流式传输 reasoning，先结束它
                if (currentField === "reasoning") {
                  controller.enqueue(
                    encoder.encode(
                      createSSEEvent("field_end", { field: "reasoning" })
                    )
                  );
                }
                // 开始 content 字段
                controller.enqueue(
                  encoder.encode(
                    createSSEEvent("field_start", { field: "content" })
                  )
                );
                currentField = "content";
                hasStartedContent = true;
              }

              assistantContent += delta.content;
              controller.enqueue(
                encoder.encode(
                  createSSEEvent("delta", {
                    field: "content",
                    text: delta.content,
                  })
                )
              );
            }
          }
        }

        // 结束当前字段
        if (currentField) {
          controller.enqueue(
            encoder.encode(createSSEEvent("field_end", { field: currentField }))
          );
        }

        // 发送 done 事件
        controller.enqueue(
          encoder.encode(
            createSSEEvent("done", {
              tokens_used: totalTokens,
            })
          )
        );

        // 保存对话到数据库
        if (assistantContent) {
          messages.push({
            role: "assistant",
            content: assistantContent,
          });

          await saveConversation(
            userId,
            conversationId,
            messages,
            model,
            totalTokens
          );
        }

        controller.close();
      } catch (e) {
        console.error("Stream error:", e);
        controller.enqueue(
          encoder.encode(
            createSSEEvent("error", {
              message: e instanceof Error ? e.message : "Unknown error",
            })
          )
        );
        controller.close();
      }
    },
  });

  // 返回 SSE 响应
  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no", // 禁用 Nginx 缓冲
      ...corsHeaders,
    },
  });
});
