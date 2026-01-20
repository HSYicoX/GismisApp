/**
 * Get Watch History Edge Function
 *
 * 获取用户观看历史（含 episode 和 anime 详情）
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
  paginatedResponse,
  createPaginationMeta,
  unauthorized,
  badRequest,
  internalError,
  fromSupabaseError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

/**
 * 观看历史项响应类型
 */
interface WatchHistoryItem {
  id: string;
  episode_id: string;
  progress: number;
  duration: number | null;
  watched_at: string;
  completed: boolean;
  episode: {
    id: string;
    season_id: string;
    episode_number: number;
    title: string | null;
    synopsis: string | null;
    duration_seconds: number | null;
    air_date: string | null;
    thumbnail_url: string | null;
    season: {
      id: string;
      anime_id: string;
      season_number: number;
      title: string | null;
      anime: {
        id: string;
        title: string;
        title_ja: string | null;
        cover_url: string | null;
        status: string;
      };
    };
  };
}

/**
 * 解析分页参数
 */
function parsePaginationParams(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") || "1", 10));
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") || "20", 10))
  );
  return { page, pageSize };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");

  // 处理 CORS 预检请求
  if (isCorsPreflightRequest(req)) {
    return handleCorsPreflightRequest(origin);
  }

  // 仅支持 GET 方法
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // 验证 JWT
    const authResult = await authenticateRequest(req);
    if (!authResult.success || !authResult.userId) {
      return unauthorized(authResult.error || "Authentication required", origin);
    }

    const userId = authResult.userId;
    const url = new URL(req.url);
    const { page, pageSize } = parsePaginationParams(url);

    // 可选过滤参数
    const completedOnly = url.searchParams.get("completed") === "true";
    const animeId = url.searchParams.get("anime_id");

    const supabase = getSupabaseAdmin();

    // 构建查询
    let query = supabase
      .from(Tables.WATCH_HISTORY)
      .select(
        `
        id,
        episode_id,
        progress,
        duration,
        watched_at,
        completed,
        episode:episode_id (
          id,
          season_id,
          episode_number,
          title,
          synopsis,
          duration_seconds,
          air_date,
          thumbnail_url,
          season:season_id (
            id,
            anime_id,
            season_number,
            title,
            anime:anime_id (
              id,
              title,
              title_ja,
              cover_url,
              status
            )
          )
        )
      `,
        { count: "exact" }
      )
      .eq("user_id", userId);

    // 应用过滤条件
    if (completedOnly) {
      query = query.eq("completed", true);
    }

    // 如果指定了 anime_id，需要通过子查询过滤
    // 由于 Supabase 不支持直接在嵌套关系上过滤，我们需要先获取相关的 episode_ids
    if (animeId) {
      // 获取该动漫的所有 episode_ids
      const { data: episodeIds, error: episodeError } = await supabase
        .from(Tables.EPISODES)
        .select("id, season:season_id!inner(anime_id)")
        .eq("season.anime_id", animeId);

      if (episodeError) {
        console.error("Episode query error:", episodeError);
        return fromSupabaseError(episodeError, origin);
      }

      if (episodeIds && episodeIds.length > 0) {
        const ids = episodeIds.map((e) => e.id);
        query = query.in("episode_id", ids);
      } else {
        // 没有找到相关集数，返回空结果
        return paginatedResponse(
          [],
          createPaginationMeta(0, page, pageSize),
          origin
        );
      }
    }

    // 应用排序和分页
    const offset = (page - 1) * pageSize;
    query = query
      .order("watched_at", { ascending: false })
      .range(offset, offset + pageSize - 1);

    const { data, error, count } = await query;

    if (error) {
      console.error("Database error:", error);
      return fromSupabaseError(error, origin);
    }

    // 格式化响应数据
    const watchHistory: WatchHistoryItem[] = (data || []).map((item) => ({
      id: item.id,
      episode_id: item.episode_id,
      progress: item.progress,
      duration: item.duration,
      watched_at: item.watched_at,
      completed: item.completed,
      episode: item.episode,
    }));

    const total = count || 0;
    const pagination = createPaginationMeta(total, page, pageSize);

    return paginatedResponse(watchHistory, pagination, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to fetch watch history", origin);
  }
});
