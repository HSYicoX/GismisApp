/**
 * Get Profile Edge Function
 *
 * 获取用户资料
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问数据库
 *
 * Requirements: 6.1
 */

import { authenticateRequest } from "../_shared/auth.ts";
import {
  isCorsPreflightRequest,
  handleCorsPreflightRequest,
} from "../_shared/cors.ts";
import {
  successResponse,
  unauthorized,
  notFound,
  internalError,
  fromSupabaseError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

/**
 * 用户资料响应类型
 */
interface UserProfile {
  id: string;
  user_id: string;
  nickname: string | null;
  avatar_url: string | null;
  bio: string | null;
  preferences: Record<string, unknown>;
  created_at: string;
  updated_at: string;
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

    // 查询用户资料
    const { data, error } = await supabase
      .from(Tables.USER_PROFILES)
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    if (error) {
      console.error("Database error:", error);
      return fromSupabaseError(error, origin);
    }

    // 如果用户资料不存在，创建默认资料
    if (!data) {
      const { data: newProfile, error: createError } = await supabase
        .from(Tables.USER_PROFILES)
        .insert({
          user_id: userId,
          nickname: null,
          avatar_url: null,
          bio: null,
          preferences: {},
        })
        .select()
        .single();

      if (createError) {
        console.error("Failed to create profile:", createError);
        return fromSupabaseError(createError, origin);
      }

      const profile: UserProfile = {
        id: newProfile.id,
        user_id: newProfile.user_id,
        nickname: newProfile.nickname,
        avatar_url: newProfile.avatar_url,
        bio: newProfile.bio,
        preferences: newProfile.preferences || {},
        created_at: newProfile.created_at,
        updated_at: newProfile.updated_at,
      };

      return successResponse(profile, origin, 201);
    }

    // 返回现有资料
    const profile: UserProfile = {
      id: data.id,
      user_id: data.user_id,
      nickname: data.nickname,
      avatar_url: data.avatar_url,
      bio: data.bio,
      preferences: data.preferences || {},
      created_at: data.created_at,
      updated_at: data.updated_at,
    };

    return successResponse(profile, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to fetch profile", origin);
  }
});
