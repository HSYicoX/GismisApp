/**
 * Update Profile Edge Function
 *
 * 更新用户资料（含输入验证和 sanitization）
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问数据库
 *
 * Requirements: 6.2
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
  validationError,
  internalError,
  fromSupabaseError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

/**
 * 更新请求体类型
 */
interface UpdateProfileRequest {
  nickname?: string;
  bio?: string;
  preferences?: Record<string, unknown>;
}

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

/**
 * 验证错误详情
 */
interface ValidationErrors {
  [field: string]: string;
}

/**
 * 验证和清理昵称
 */
function validateNickname(nickname: unknown): { valid: boolean; value?: string; error?: string } {
  if (nickname === undefined || nickname === null) {
    return { valid: true, value: undefined };
  }

  if (typeof nickname !== "string") {
    return { valid: false, error: "Nickname must be a string" };
  }

  // 清理：去除首尾空白
  const cleaned = nickname.trim();

  // 允许空字符串（清除昵称）
  if (cleaned === "") {
    return { valid: true, value: null as unknown as string };
  }

  // 长度限制
  if (cleaned.length > 50) {
    return { valid: false, error: "Nickname must be 50 characters or less" };
  }

  // 禁止特殊字符（只允许字母、数字、中文、下划线、连字符）
  const validPattern = /^[\p{L}\p{N}_\-\s]+$/u;
  if (!validPattern.test(cleaned)) {
    return { valid: false, error: "Nickname contains invalid characters" };
  }

  return { valid: true, value: cleaned };
}

/**
 * 验证和清理个人简介
 */
function validateBio(bio: unknown): { valid: boolean; value?: string; error?: string } {
  if (bio === undefined || bio === null) {
    return { valid: true, value: undefined };
  }

  if (typeof bio !== "string") {
    return { valid: false, error: "Bio must be a string" };
  }

  // 清理：去除首尾空白
  const cleaned = bio.trim();

  // 允许空字符串（清除简介）
  if (cleaned === "") {
    return { valid: true, value: null as unknown as string };
  }

  // 长度限制
  if (cleaned.length > 500) {
    return { valid: false, error: "Bio must be 500 characters or less" };
  }

  // 基本 XSS 防护：移除 HTML 标签
  const sanitized = cleaned.replace(/<[^>]*>/g, "");

  return { valid: true, value: sanitized };
}

/**
 * 验证偏好设置
 */
function validatePreferences(
  preferences: unknown
): { valid: boolean; value?: Record<string, unknown>; error?: string } {
  if (preferences === undefined || preferences === null) {
    return { valid: true, value: undefined };
  }

  if (typeof preferences !== "object" || Array.isArray(preferences)) {
    return { valid: false, error: "Preferences must be an object" };
  }

  // 限制偏好设置大小（防止存储过大数据）
  const jsonStr = JSON.stringify(preferences);
  if (jsonStr.length > 10000) {
    return { valid: false, error: "Preferences object is too large" };
  }

  // 验证允许的偏好设置键
  const allowedKeys = new Set([
    "theme",
    "language",
    "notifications",
    "autoplay",
    "quality",
    "subtitle",
    "displayMode",
  ]);

  const cleaned: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(preferences as Record<string, unknown>)) {
    if (allowedKeys.has(key)) {
      cleaned[key] = value;
    }
  }

  return { valid: true, value: cleaned };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");

  // 处理 CORS 预检请求
  if (isCorsPreflightRequest(req)) {
    return handleCorsPreflightRequest(origin);
  }

  // 仅支持 PUT/PATCH 方法
  if (req.method !== "PUT" && req.method !== "PATCH") {
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
    let body: UpdateProfileRequest;
    try {
      body = await req.json();
    } catch {
      return badRequest("Invalid JSON body", origin);
    }

    // 验证请求体不为空
    if (!body || typeof body !== "object") {
      return badRequest("Request body must be an object", origin);
    }

    // 验证各字段
    const errors: ValidationErrors = {};
    const updates: Record<string, unknown> = {};

    // 验证昵称
    const nicknameResult = validateNickname(body.nickname);
    if (!nicknameResult.valid) {
      errors.nickname = nicknameResult.error!;
    } else if (nicknameResult.value !== undefined) {
      updates.nickname = nicknameResult.value;
    }

    // 验证简介
    const bioResult = validateBio(body.bio);
    if (!bioResult.valid) {
      errors.bio = bioResult.error!;
    } else if (bioResult.value !== undefined) {
      updates.bio = bioResult.value;
    }

    // 验证偏好设置
    const preferencesResult = validatePreferences(body.preferences);
    if (!preferencesResult.valid) {
      errors.preferences = preferencesResult.error!;
    } else if (preferencesResult.value !== undefined) {
      updates.preferences = preferencesResult.value;
    }

    // 如果有验证错误，返回错误响应
    if (Object.keys(errors).length > 0) {
      return validationError("Validation failed", origin, errors);
    }

    // 如果没有要更新的字段
    if (Object.keys(updates).length === 0) {
      return badRequest("No valid fields to update", origin);
    }

    const supabase = getSupabaseAdmin();

    // 检查用户资料是否存在
    const { data: existing, error: checkError } = await supabase
      .from(Tables.USER_PROFILES)
      .select("id, preferences")
      .eq("user_id", userId)
      .maybeSingle();

    if (checkError) {
      console.error("Database error:", checkError);
      return fromSupabaseError(checkError, origin);
    }

    let profile: UserProfile;

    if (!existing) {
      // 资料不存在，创建新资料
      const { data: newProfile, error: createError } = await supabase
        .from(Tables.USER_PROFILES)
        .insert({
          user_id: userId,
          nickname: updates.nickname ?? null,
          bio: updates.bio ?? null,
          preferences: updates.preferences ?? {},
        })
        .select()
        .single();

      if (createError) {
        console.error("Failed to create profile:", createError);
        return fromSupabaseError(createError, origin);
      }

      profile = {
        id: newProfile.id,
        user_id: newProfile.user_id,
        nickname: newProfile.nickname,
        avatar_url: newProfile.avatar_url,
        bio: newProfile.bio,
        preferences: newProfile.preferences || {},
        created_at: newProfile.created_at,
        updated_at: newProfile.updated_at,
      };
    } else {
      // 资料存在，更新
      // 如果更新偏好设置，合并现有偏好
      if (updates.preferences) {
        updates.preferences = {
          ...(existing.preferences || {}),
          ...(updates.preferences as Record<string, unknown>),
        };
      }

      const { data: updatedProfile, error: updateError } = await supabase
        .from(Tables.USER_PROFILES)
        .update(updates)
        .eq("user_id", userId)
        .select()
        .single();

      if (updateError) {
        console.error("Failed to update profile:", updateError);
        return fromSupabaseError(updateError, origin);
      }

      profile = {
        id: updatedProfile.id,
        user_id: updatedProfile.user_id,
        nickname: updatedProfile.nickname,
        avatar_url: updatedProfile.avatar_url,
        bio: updatedProfile.bio,
        preferences: updatedProfile.preferences || {},
        created_at: updatedProfile.created_at,
        updated_at: updatedProfile.updated_at,
      };
    }

    return successResponse(profile, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to update profile", origin);
  }
});
