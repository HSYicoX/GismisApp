/**
 * Upload Avatar Edge Function
 *
 * 上传用户头像到 user-avatars bucket
 * 并更新用户资料中的 avatar_url
 *
 * 访问模式：需要 JWT 认证
 * 使用 service_role 访问 Storage 和数据库
 *
 * Requirements: 6.3, 8.3
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
import { getSupabaseAdmin, Tables, Buckets } from "../_shared/supabase.ts";

/**
 * 允许的图片 MIME 类型
 */
const ALLOWED_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
]);

/**
 * 最大文件大小（5MB）
 */
const MAX_FILE_SIZE = 5 * 1024 * 1024;

/**
 * 上传响应类型
 */
interface UploadResponse {
  avatar_url: string;
  path: string;
}

/**
 * 从 Content-Type 获取文件扩展名
 */
function getExtensionFromMimeType(mimeType: string): string {
  const extensions: Record<string, string> = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
  };
  return extensions[mimeType] || "jpg";
}

/**
 * 生成唯一的文件路径
 */
function generateFilePath(userId: string, extension: string): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  return `${userId}/${timestamp}-${random}.${extension}`;
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
    const contentType = req.headers.get("Content-Type") || "";

    let fileData: Uint8Array;
    let mimeType: string;
    let fileName: string | undefined;

    // 处理 multipart/form-data 上传
    if (contentType.includes("multipart/form-data")) {
      const formData = await req.formData();
      const file = formData.get("file");

      if (!file || !(file instanceof File)) {
        return badRequest("Missing 'file' field in form data", origin);
      }

      // 验证文件类型
      mimeType = file.type;
      if (!ALLOWED_MIME_TYPES.has(mimeType)) {
        return validationError(
          "Invalid file type. Allowed types: JPEG, PNG, GIF, WebP",
          origin,
          { allowedTypes: Array.from(ALLOWED_MIME_TYPES) }
        );
      }

      // 验证文件大小
      if (file.size > MAX_FILE_SIZE) {
        return validationError(
          `File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`,
          origin,
          { maxSize: MAX_FILE_SIZE }
        );
      }

      fileData = new Uint8Array(await file.arrayBuffer());
      fileName = file.name;
    }
    // 处理直接二进制上传
    else if (ALLOWED_MIME_TYPES.has(contentType)) {
      mimeType = contentType;

      // 读取请求体
      const arrayBuffer = await req.arrayBuffer();
      fileData = new Uint8Array(arrayBuffer);

      // 验证文件大小
      if (fileData.length > MAX_FILE_SIZE) {
        return validationError(
          `File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`,
          origin,
          { maxSize: MAX_FILE_SIZE }
        );
      }
    } else {
      return badRequest(
        "Invalid Content-Type. Use multipart/form-data or a valid image MIME type",
        origin
      );
    }

    // 验证文件不为空
    if (fileData.length === 0) {
      return badRequest("Empty file", origin);
    }

    const supabase = getSupabaseAdmin();
    const storage = supabase.storage;

    // 生成文件路径
    const extension = getExtensionFromMimeType(mimeType);
    const filePath = generateFilePath(userId, extension);

    // 获取用户当前头像路径（用于删除旧头像）
    const { data: profile } = await supabase
      .from(Tables.USER_PROFILES)
      .select("avatar_url")
      .eq("user_id", userId)
      .maybeSingle();

    // 上传新头像
    const { data: uploadData, error: uploadError } = await storage
      .from(Buckets.USER_AVATARS)
      .upload(filePath, fileData, {
        contentType: mimeType,
        upsert: false,
      });

    if (uploadError) {
      console.error("Storage upload error:", uploadError);
      return internalError("Failed to upload avatar", origin);
    }

    // 生成头像 URL（私有 bucket 需要签名 URL，但这里我们存储路径，客户端通过 get-signed-url 获取）
    // 或者如果 bucket 配置为公开，可以直接使用公开 URL
    const avatarUrl = `${Buckets.USER_AVATARS}/${filePath}`;

    // 更新用户资料
    const { error: updateError } = await supabase
      .from(Tables.USER_PROFILES)
      .upsert(
        {
          user_id: userId,
          avatar_url: avatarUrl,
        },
        {
          onConflict: "user_id",
        }
      );

    if (updateError) {
      console.error("Failed to update profile:", updateError);
      // 尝试删除已上传的文件
      await storage.from(Buckets.USER_AVATARS).remove([filePath]);
      return fromSupabaseError(updateError, origin);
    }

    // 删除旧头像（如果存在）
    if (profile?.avatar_url && profile.avatar_url !== avatarUrl) {
      const oldPath = profile.avatar_url.replace(`${Buckets.USER_AVATARS}/`, "");
      if (oldPath && oldPath !== filePath) {
        await storage.from(Buckets.USER_AVATARS).remove([oldPath]).catch((err) => {
          console.warn("Failed to delete old avatar:", err);
        });
      }
    }

    const response: UploadResponse = {
      avatar_url: avatarUrl,
      path: filePath,
    };

    return successResponse(response, origin, 201);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to upload avatar", origin);
  }
});
