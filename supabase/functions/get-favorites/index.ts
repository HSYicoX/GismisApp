/**
 * Get Favorites Edge Function
 *
 * 获取用户收藏列表（含 anime 详情）
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问数据库
 *
 * Requirements: 5.2, 5.3
 */

import { authenticateRequest } from "../_shared/auth.ts";
import {
  isCorsPreflightRequest,
  handleCorsPreflightRequest,
} from "../_shared/cors.ts";
import {
  successResponse,
  unauthorized,
  internalError,
  fromSupabaseError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

/**
 * 收藏项响应类型
 */
interface FavoriteItem {
  id: string;
  anime_id: string;
  added_at: string;
  sort_order: number | null;
  anime: {
    id: string;
    title: string;
    title_ja: string | null;
    synopsis: string | null;
    cover_url: string | null;
    banner_url: string | null;
    genres: string[];
    rating: number | null;
    status: string;
    start_date: string | null;
    end_date: string | null;
    season_count: number;
    current_season: number;
  };
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
    const supabase = getSupabaseAdmin();

    // 查询用户收藏列表，包含 anime 详情
    const { data, error } = await supabase
      .from(Tables.USER_FAVORITES)
      .select(
        `
        id,
        anime_id,
        added_at,
        sort_order,
        anime:anime_id (
          id,
          title,
          title_ja,
          synopsis,
          cover_url,
          banner_url,
          genres,
          rating,
          status,
          start_date,
          end_date,
          season_count,
          current_season
        )
      `
      )
      .eq("user_id", userId)
      .order("sort_order", { ascending: true, nullsFirst: false })
      .order("added_at", { ascending: false });

    if (error) {
      console.error("Database error:", error);
      return fromSupabaseError(error, origin);
    }

    // 格式化响应数据
    const favorites: FavoriteItem[] = (data || []).map((item) => ({
      id: item.id,
      anime_id: item.anime_id,
      added_at: item.added_at,
      sort_order: item.sort_order,
      anime: item.anime,
    }));

    return successResponse(favorites, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to fetch favorites", origin);
  }
});
