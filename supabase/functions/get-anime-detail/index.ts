/**
 * Get Anime Detail Edge Function
 *
 * 获取单个动漫的详细信息
 *
 * 访问模式：公开访问（无需认证）
 *
 * Path Parameters:
 * - id: 动漫 ID
 */

import {
  isCorsPreflightRequest,
  handleCorsPreflightRequest,
} from "../_shared/cors.ts";
import {
  successResponse,
  badRequest,
  notFound,
  internalError,
} from "../_shared/response.ts";
import { TMDBAdapter } from "../_shared/adapters/tmdb_adapter.ts";

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
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/');
    const id = pathParts[pathParts.length - 1];

    if (!id || id.trim() === "") {
      return badRequest("Missing anime ID", origin);
    }

    // 使用 TMDB adapter 获取详情
    const adapter = new TMDBAdapter();
    const animeInfo = await adapter.getAnimeDetail(id);

    if (!animeInfo) {
      return notFound("Anime not found", origin);
    }

    return successResponse(animeInfo, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to fetch anime detail", origin);
  }
});
