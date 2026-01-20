/**
 * Supabase Admin Client 模块
 * 
 * 为 Edge Functions 提供 Supabase 数据库访问
 * 使用 service_role 密钥进行特权操作
 * 
 * 安全注意事项：
 * - service_role 密钥仅在服务端使用
 * - 绝不将此密钥暴露给客户端
 * - 所有用户操作需先验证 JWT
 */

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

// 环境变量
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";

/**
 * Supabase Admin Client 单例
 * 使用 service_role 密钥，具有完全数据库访问权限
 */
let adminClient: SupabaseClient | null = null;

/**
 * 获取 Supabase Admin Client（单例模式）
 * 
 * 使用 service_role 密钥，绕过 RLS 策略
 * 仅用于服务端特权操作
 * 
 * @returns Supabase Admin Client
 * @throws Error 如果环境变量未配置
 */
export function getSupabaseAdmin(): SupabaseClient {
  if (adminClient) {
    return adminClient;
  }

  if (!SUPABASE_URL) {
    throw new Error("SUPABASE_URL environment variable is not set");
  }

  if (!SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY environment variable is not set");
  }

  adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    db: {
      schema: "public",
    },
  });

  return adminClient;
}

/**
 * 创建新的 Supabase Admin Client 实例
 * 
 * 用于需要独立实例的场景（如并发操作）
 * 
 * @returns 新的 Supabase Admin Client 实例
 */
export function createSupabaseAdmin(): SupabaseClient {
  if (!SUPABASE_URL) {
    throw new Error("SUPABASE_URL environment variable is not set");
  }

  if (!SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY environment variable is not set");
  }

  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    db: {
      schema: "public",
    },
  });
}

/**
 * 获取 Supabase Anon Client
 * 
 * 使用 anon 密钥，受 RLS 策略限制
 * 用于公开只读操作
 * 
 * @returns Supabase Anon Client
 */
export function getSupabaseAnon(): SupabaseClient {
  if (!SUPABASE_URL) {
    throw new Error("SUPABASE_URL environment variable is not set");
  }

  if (!SUPABASE_ANON_KEY) {
    throw new Error("SUPABASE_ANON_KEY environment variable is not set");
  }

  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

/**
 * 获取 Supabase Storage Admin
 * 
 * 用于私有 bucket 的文件操作
 * 
 * @returns Supabase Storage 实例
 */
export function getStorageAdmin() {
  return getSupabaseAdmin().storage;
}

/**
 * 数据库表名常量
 */
export const Tables = {
  // 公开表
  ANIME: "anime",
  ANIME_SEASONS: "anime_seasons",
  EPISODES: "episodes",
  EPISODE_PLATFORM_LINKS: "episode_platform_links",
  ANIME_PLATFORM_LINKS: "anime_platform_links",
  SOURCE_MATERIALS: "source_materials",
  CHAPTERS: "chapters",
  SCHEDULE: "schedule",
  
  // 用户表（需要认证）
  USER_PROFILES: "user_profiles",
  USER_FAVORITES: "user_favorites",
  WATCH_HISTORY: "watch_history",
  AI_CONVERSATIONS: "ai_conversations",
} as const;

/**
 * Storage Bucket 名称常量
 */
export const Buckets = {
  ANIME_COVERS: "anime-covers",
  ANIME_BANNERS: "anime-banners",
  USER_AVATARS: "user-avatars",
} as const;

/**
 * 检查数据库连接是否正常
 * 
 * @returns 连接状态
 */
export async function checkDatabaseConnection(): Promise<boolean> {
  try {
    const admin = getSupabaseAdmin();
    const { error } = await admin.from(Tables.ANIME).select("id").limit(1);
    return !error;
  } catch {
    return false;
  }
}
