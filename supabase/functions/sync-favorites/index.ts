/**
 * Sync Favorites Edge Function
 *
 * 处理收藏的批量同步操作（add/remove）
 * 实现 server-wins 冲突策略
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问数据库
 *
 * Requirements: 5.2, 5.3, 5.4
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
  internalError,
  fromSupabaseError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

/**
 * 同步操作类型
 */
type SyncOperationType = "add" | "remove";

/**
 * 同步操作请求
 */
interface SyncOperation {
  type: SyncOperationType;
  animeId: string;
  timestamp: string; // ISO 8601 格式
  sortOrder?: number;
}

/**
 * 同步请求体
 */
interface SyncRequest {
  operations: SyncOperation[];
}

/**
 * 同步结果项
 */
interface SyncResultItem {
  animeId: string;
  type: SyncOperationType;
  success: boolean;
  error?: string;
  serverWins?: boolean; // 是否服务端数据优先
}

/**
 * 同步响应
 */
interface SyncResponse {
  processed: number;
  succeeded: number;
  failed: number;
  results: SyncResultItem[];
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
    let body: SyncRequest;
    try {
      body = await req.json();
    } catch {
      return badRequest("Invalid JSON body", origin);
    }

    // 验证请求体
    if (!body.operations || !Array.isArray(body.operations)) {
      return badRequest("Missing or invalid 'operations' array", origin);
    }

    if (body.operations.length === 0) {
      return successResponse<SyncResponse>(
        {
          processed: 0,
          succeeded: 0,
          failed: 0,
          results: [],
        },
        origin
      );
    }

    // 限制单次同步操作数量
    const MAX_OPERATIONS = 100;
    if (body.operations.length > MAX_OPERATIONS) {
      return badRequest(
        `Too many operations. Maximum ${MAX_OPERATIONS} allowed per request`,
        origin
      );
    }

    const supabase = getSupabaseAdmin();
    const results: SyncResultItem[] = [];

    // 处理每个同步操作
    for (const operation of body.operations) {
      const result = await processOperation(supabase, userId, operation);
      results.push(result);
    }

    // 统计结果
    const succeeded = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    const response: SyncResponse = {
      processed: results.length,
      succeeded,
      failed,
      results,
    };

    return successResponse(response, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to sync favorites", origin);
  }
});

/**
 * 处理单个同步操作
 *
 * 实现 server-wins 冲突策略：
 * - 如果服务端有更新的数据，忽略客户端操作
 * - 如果客户端数据更新，执行操作
 */
async function processOperation(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  operation: SyncOperation
): Promise<SyncResultItem> {
  const { type, animeId, timestamp, sortOrder } = operation;

  // 验证操作类型
  if (type !== "add" && type !== "remove") {
    return {
      animeId,
      type,
      success: false,
      error: "Invalid operation type. Must be 'add' or 'remove'",
    };
  }

  // 验证 animeId
  if (!animeId || typeof animeId !== "string") {
    return {
      animeId: animeId || "unknown",
      type,
      success: false,
      error: "Invalid animeId",
    };
  }

  // 解析客户端时间戳
  let clientTimestamp: Date;
  try {
    clientTimestamp = new Date(timestamp);
    if (isNaN(clientTimestamp.getTime())) {
      throw new Error("Invalid date");
    }
  } catch {
    return {
      animeId,
      type,
      success: false,
      error: "Invalid timestamp format",
    };
  }

  try {
    if (type === "add") {
      return await handleAddFavorite(
        supabase,
        userId,
        animeId,
        clientTimestamp,
        sortOrder
      );
    } else {
      return await handleRemoveFavorite(
        supabase,
        userId,
        animeId,
        clientTimestamp
      );
    }
  } catch (error) {
    console.error(`Error processing ${type} operation for ${animeId}:`, error);
    return {
      animeId,
      type,
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

/**
 * 处理添加收藏操作
 *
 * Server-wins 策略：
 * - 如果已存在且服务端 added_at 更新，保留服务端数据
 * - 如果不存在或客户端时间戳更新，执行添加/更新
 */
async function handleAddFavorite(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  animeId: string,
  clientTimestamp: Date,
  sortOrder?: number
): Promise<SyncResultItem> {
  // 检查 anime 是否存在
  const { data: anime, error: animeError } = await supabase
    .from(Tables.ANIME)
    .select("id")
    .eq("id", animeId)
    .single();

  if (animeError || !anime) {
    return {
      animeId,
      type: "add",
      success: false,
      error: "Anime not found",
    };
  }

  // 检查是否已存在收藏
  const { data: existing, error: checkError } = await supabase
    .from(Tables.USER_FAVORITES)
    .select("id, added_at")
    .eq("user_id", userId)
    .eq("anime_id", animeId)
    .maybeSingle();

  if (checkError) {
    throw checkError;
  }

  if (existing) {
    // 已存在，检查时间戳（server-wins）
    const serverTimestamp = new Date(existing.added_at);
    if (serverTimestamp >= clientTimestamp) {
      // 服务端数据更新或相同，保留服务端数据
      return {
        animeId,
        type: "add",
        success: true,
        serverWins: true,
      };
    }

    // 客户端数据更新，更新 sort_order（如果提供）
    if (sortOrder !== undefined) {
      const { error: updateError } = await supabase
        .from(Tables.USER_FAVORITES)
        .update({ sort_order: sortOrder })
        .eq("id", existing.id);

      if (updateError) {
        throw updateError;
      }
    }

    return {
      animeId,
      type: "add",
      success: true,
    };
  }

  // 不存在，插入新记录
  const { error: insertError } = await supabase
    .from(Tables.USER_FAVORITES)
    .insert({
      user_id: userId,
      anime_id: animeId,
      added_at: clientTimestamp.toISOString(),
      sort_order: sortOrder,
    });

  if (insertError) {
    throw insertError;
  }

  return {
    animeId,
    type: "add",
    success: true,
  };
}

/**
 * 处理移除收藏操作
 *
 * Server-wins 策略：
 * - 如果服务端 added_at 比客户端删除时间戳更新，保留收藏
 * - 否则执行删除
 */
async function handleRemoveFavorite(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  animeId: string,
  clientTimestamp: Date
): Promise<SyncResultItem> {
  // 检查是否存在收藏
  const { data: existing, error: checkError } = await supabase
    .from(Tables.USER_FAVORITES)
    .select("id, added_at")
    .eq("user_id", userId)
    .eq("anime_id", animeId)
    .maybeSingle();

  if (checkError) {
    throw checkError;
  }

  if (!existing) {
    // 不存在，视为成功（幂等性）
    return {
      animeId,
      type: "remove",
      success: true,
    };
  }

  // 检查时间戳（server-wins）
  const serverTimestamp = new Date(existing.added_at);
  if (serverTimestamp > clientTimestamp) {
    // 服务端数据在客户端删除操作之后添加，保留收藏
    return {
      animeId,
      type: "remove",
      success: true,
      serverWins: true,
    };
  }

  // 执行删除
  const { error: deleteError } = await supabase
    .from(Tables.USER_FAVORITES)
    .delete()
    .eq("id", existing.id);

  if (deleteError) {
    throw deleteError;
  }

  return {
    animeId,
    type: "remove",
    success: true,
  };
}
