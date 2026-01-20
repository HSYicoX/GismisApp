/**
 * Get Anime List Edge Function
 *
 * 获取聚合的动漫列表（从多个平台获取并合并）
 *
 * 访问模式：公开访问（无需认证）
 *
 * Query Parameters:
 * - page: 页码（默认 1）
 * - pageSize: 每页数量（默认 20，最大 50）
 * - refresh: 是否强制刷新缓存（默认 false）
 *
 * Requirements: 8.1
 */

import {
  isCorsPreflightRequest,
  handleCorsPreflightRequest,
} from "../_shared/cors.ts";
import {
  successResponse,
  badRequest,
  internalError,
  createPaginationMeta,
  paginatedResponse,
} from "../_shared/response.ts";
import { DataAggregator } from "../_shared/aggregator/data_aggregator.ts";
import { CacheLayer } from "../_shared/aggregator/cache_layer.ts";
import { TMDBAdapter } from "../_shared/adapters/tmdb_adapter.ts";

/** 最大每页数量 */
const MAX_PAGE_SIZE = 50;
/** 默认每页数量 */
const DEFAULT_PAGE_SIZE = 20;

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

    // 解析分页参数
    const pageParam = url.searchParams.get("page");
    const pageSizeParam = url.searchParams.get("pageSize");
    const refreshParam = url.searchParams.get("refresh");

    // 验证并解析 page
    const page = pageParam ? parseInt(pageParam, 10) : 1;
    if (isNaN(page) || page < 1) {
      return badRequest("Invalid page parameter. Must be a positive integer.", origin);
    }

    // 验证并解析 pageSize
    let pageSize = pageSizeParam ? parseInt(pageSizeParam, 10) : DEFAULT_PAGE_SIZE;
    if (isNaN(pageSize) || pageSize < 1) {
      return badRequest("Invalid pageSize parameter. Must be a positive integer.", origin);
    }
    // 限制最大 pageSize
    pageSize = Math.min(pageSize, MAX_PAGE_SIZE);

    // 解析强制刷新参数
    const forceRefresh = refreshParam === "true";

    // 创建聚合器（使用 TMDB 作为主要数据源）
    const cache = new CacheLayer();
    const aggregator = new DataAggregator(
      [new TMDBAdapter()],
      cache
    );

    // 获取动漫列表
    const animeList = await aggregator.getAnimeList(page, pageSize, forceRefresh);

    // 构建分页响应
    // 注意：由于是聚合数据，我们无法准确知道总数，使用 hasMore 判断
    const hasMore = animeList.length === pageSize;
    const pagination = createPaginationMeta(
      hasMore ? page * pageSize + 1 : page * pageSize, // 估算总数
      page,
      pageSize
    );

    return paginatedResponse(animeList, pagination, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to fetch anime list", origin);
  }
});
