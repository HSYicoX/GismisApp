/**
 * Search Anime Edge Function
 *
 * 跨平台搜索动漫
 *
 * 访问模式：公开访问（无需认证）
 *
 * Query Parameters:
 * - q: 搜索关键词（必需）
 * - limit: 返回数量限制（默认 20，最大 50）
 *
 * Requirements: 8.3
 */

import {
  isCorsPreflightRequest,
  handleCorsPreflightRequest,
} from "../_shared/cors.ts";
import {
  successResponse,
  badRequest,
  internalError,
} from "../_shared/response.ts";
import { DataAggregator } from "../_shared/aggregator/data_aggregator.ts";
import { CacheLayer } from "../_shared/aggregator/cache_layer.ts";
import { TMDBAdapter } from "../_shared/adapters/tmdb_adapter.ts";

/** 最大返回数量 */
const MAX_LIMIT = 50;
/** 默认返回数量 */
const DEFAULT_LIMIT = 20;

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

    // 解析搜索关键词
    const keyword = url.searchParams.get("q");
    if (!keyword || keyword.trim() === "") {
      return badRequest("Missing required parameter: q (search keyword)", origin);
    }

    // 解析返回数量限制
    const limitParam = url.searchParams.get("limit");
    let limit = limitParam ? parseInt(limitParam, 10) : DEFAULT_LIMIT;
    if (isNaN(limit) || limit < 1) {
      return badRequest("Invalid limit parameter. Must be a positive integer.", origin);
    }
    // 限制最大返回数量
    limit = Math.min(limit, MAX_LIMIT);

    // 创建聚合器（使用 TMDB 作为主要数据源）
    const cache = new CacheLayer();
    const aggregator = new DataAggregator(
      [new TMDBAdapter()],
      cache
    );

    // 执行搜索
    const searchResults = await aggregator.searchAnime(keyword.trim(), limit);

    return successResponse(
      {
        keyword: keyword.trim(),
        results: searchResults,
        count: searchResults.length,
      },
      origin
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to search anime", origin);
  }
});
