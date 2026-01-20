/**
 * Get Signed URL Edge Function
 *
 * 生成私有文件的签名 URL
 * 用于访问 user-avatars 等私有 bucket 中的文件
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问 Storage
 *
 * Requirements: 6.4, 8.2
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
  notFound,
  forbidden,
  internalError,
} from "../_shared/response.ts";
import { getSupabaseAdmin, Buckets } from "../_shared/supabase.ts";

/**
 * 请求体类型
 */
interface SignedUrlRequest {
  bucket: string;
  path: string;
  expiresIn?: number; // 过期时间（秒），默认 3600
}

/**
 * 响应类型
 */
interface SignedUrlResponse {
  signedUrl: string;
  expiresAt: string;
}

/**
 * 允许的私有 bucket 列表
 */
const PRIVATE_BUCKETS = new Set([Buckets.USER_AVATARS]);

/**
 * 默认过期时间（1小时）
 */
const DEFAULT_EXPIRES_IN = 3600;

/**
 * 最大过期时间（24小时）
 */
const MAX_EXPIRES_IN = 86400;

/**
 * 最小过期时间（1分钟）
 */
const MIN_EXPIRES_IN = 60;

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
    let body: SignedUrlRequest;
    try {
      body = await req.json();
    } catch {
      return badRequest("Invalid JSON body", origin);
    }

    // 验证必需字段
    if (!body.bucket || typeof body.bucket !== "string") {
      return validationError("Missing or invalid 'bucket' field", origin);
    }

    if (!body.path || typeof body.path !== "string") {
      return validationError("Missing or invalid 'path' field", origin);
    }

    // 验证 bucket 是否为私有 bucket
    if (!PRIVATE_BUCKETS.has(body.bucket)) {
      return badRequest(
        `Bucket '${body.bucket}' is not a private bucket or does not exist`,
        origin
      );
    }

    // 验证过期时间
    let expiresIn = body.expiresIn ?? DEFAULT_EXPIRES_IN;
    if (typeof expiresIn !== "number" || !Number.isInteger(expiresIn)) {
      return validationError("'expiresIn' must be an integer", origin);
    }

    if (expiresIn < MIN_EXPIRES_IN) {
      expiresIn = MIN_EXPIRES_IN;
    } else if (expiresIn > MAX_EXPIRES_IN) {
      expiresIn = MAX_EXPIRES_IN;
    }

    // 清理路径（防止路径遍历攻击）
    const cleanPath = body.path
      .replace(/\.\./g, "") // 移除 ..
      .replace(/^\/+/, "") // 移除开头的斜杠
      .replace(/\/+/g, "/"); // 合并多个斜杠

    if (!cleanPath) {
      return validationError("Invalid path", origin);
    }

    // 对于 user-avatars bucket，验证用户只能访问自己的文件
    if (body.bucket === Buckets.USER_AVATARS) {
      // 路径格式应为: {userId}/{filename}
      const pathParts = cleanPath.split("/");
      const pathUserId = pathParts[0];

      if (pathUserId !== userId) {
        return forbidden("You can only access your own avatar", origin);
      }
    }

    const supabase = getSupabaseAdmin();
    const storage = supabase.storage;

    // 检查文件是否存在
    const { data: fileList, error: listError } = await storage
      .from(body.bucket)
      .list(cleanPath.split("/").slice(0, -1).join("/"), {
        search: cleanPath.split("/").pop(),
      });

    if (listError) {
      console.error("Storage list error:", listError);
      return internalError("Failed to check file existence", origin);
    }

    const fileName = cleanPath.split("/").pop();
    const fileExists = fileList?.some((f) => f.name === fileName);

    if (!fileExists) {
      return notFound("File not found", origin);
    }

    // 生成签名 URL
    const { data: signedUrlData, error: signedUrlError } = await storage
      .from(body.bucket)
      .createSignedUrl(cleanPath, expiresIn);

    if (signedUrlError) {
      console.error("Signed URL error:", signedUrlError);
      return internalError("Failed to generate signed URL", origin);
    }

    if (!signedUrlData?.signedUrl) {
      return internalError("Failed to generate signed URL", origin);
    }

    // 计算过期时间
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    const response: SignedUrlResponse = {
      signedUrl: signedUrlData.signedUrl,
      expiresAt,
    };

    return successResponse(response, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to generate signed URL", origin);
  }
});
