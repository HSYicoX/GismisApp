/**
 * Update Watch Progress Edge Function
 *
 * 更新用户观看进度（支持 upsert）
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问数据库
 *
 * Requirements: 5.1
 */

import { authenticateRequest } from "../_shared/auth.ts";
import {
  isCorsPreflightRequest,
  handleCorsPreflightRequest,
} from "../_shared/cors.ts";
import {
  successResponse,
  unauthorized,
  badRequest,
  notFound,
  internalError,
  fromSupabaseError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

/**
 * 请求体类型
 */
interface UpdateProgressRequest {
  episode_id: string;
  progress: number;
  duration?: number;
  completed?: boolean;
}

/**
 * 观看历史记录响应类型
 */
interface WatchHistoryRecord {
  id: string;
  user_id: string;
  episode_id: string;
  progress: number;
  duration: number | null;
  watched_at: string;
  completed: boolean;
}

/**
 * 验证请求体
 */
function validateRequest(body: unknown): {
  valid: boolean;
  data?: UpdateProgressRequest;
  error?: string;
} {
  if (!body || typeof body !== "object") {
    return { valid: false, error: "Request body is required" };
  }

  const data = body as Record<string, unknown>;

  // 验证 episode_id
  if (!data.episode_id || typeof data.episode_id !== "string") {
    return { valid: false, error: "episode_id is required and must be a string" };
  }

  // 验证 UUID 格式
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(data.episode_id)) {
    return { valid: false, error: "episode_id must be a valid UUID" };
  }

  // 验证 progress
  if (data.progress === undefined || typeof data.progress !== "number") {
    return { valid: false, error: "progress is required and must be a number" };
  }

  if (data.progress < 0) {
    return { valid: false, error: "progress must be non-negative" };
  }

  // 验证 duration（可选）
  if (data.duration !== undefined) {
    if (typeof data.duration !== "number" || data.duration < 0) {
      return { valid: false, error: "duration must be a non-negative number" };
    }
  }

  // 验证 completed（可选）
  if (data.completed !== undefined && typeof data.completed !== "boolean") {
    return { valid: false, error: "completed must be a boolean" };
  }

  return {
    valid: true,
    data: {
      episode_id: data.episode_id as string,
      progress: data.progress as number,
      duration: data.duration as number | undefined,
      completed: data.completed as boolean | undefined,
    },
  };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");

  // 处理 CORS 预检请求
  if (isCorsPreflightRequest(req)) {
    return handleCorsPreflightRequest(origin);
  }

  // 仅支持 POST 方法
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // 验证 JWT
    const authResult = await authenticateRequest(req);
    if (!authResult.success || !authResult.userId) {
      return unauthorized(authResult.error || "Authentication required", origin);
    }

    const userId = authResult.userId;

    // 解析请求体
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest("Invalid JSON body", origin);
    }

    // 验证请求体
    const validation = validateRequest(body);
    if (!validation.valid || !validation.data) {
      return badRequest(validation.error || "Invalid request", origin);
    }

    const { episode_id, progress, duration, completed } = validation.data;
    const supabase = getSupabaseAdmin();

    // 验证 episode 是否存在
    const { data: episode, error: episodeError } = await supabase
      .from(Tables.EPISODES)
      .select("id, duration_seconds")
      .eq("id", episode_id)
      .single();

    if (episodeError || !episode) {
      return notFound("Episode not found", origin);
    }

    // 确定是否完成观看
    // 如果明确指定了 completed，使用指定值
    // 否则，如果 progress >= duration 的 90%，自动标记为完成
    let isCompleted = completed;
    if (isCompleted === undefined) {
      const episodeDuration = duration || episode.duration_seconds;
      if (episodeDuration && progress >= episodeDuration * 0.9) {
        isCompleted = true;
      } else {
        isCompleted = false;
      }
    }

    // Upsert 观看历史记录
    const { data: watchRecord, error: upsertError } = await supabase
      .from(Tables.WATCH_HISTORY)
      .upsert(
        {
          user_id: userId,
          episode_id: episode_id,
          progress: Math.floor(progress), // 确保是整数
          duration: duration ? Math.floor(duration) : episode.duration_seconds,
          watched_at: new Date().toISOString(),
          completed: isCompleted,
        },
        {
          onConflict: "user_id,episode_id",
          ignoreDuplicates: false,
        }
      )
      .select()
      .single();

    if (upsertError) {
      console.error("Database error:", upsertError);
      return fromSupabaseError(upsertError, origin);
    }

    const response: WatchHistoryRecord = {
      id: watchRecord.id,
      user_id: watchRecord.user_id,
      episode_id: watchRecord.episode_id,
      progress: watchRecord.progress,
      duration: watchRecord.duration,
      watched_at: watchRecord.watched_at,
      completed: watchRecord.completed,
    };

    return successResponse(response, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to update watch progress", origin);
  }
});
