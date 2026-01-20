/**
 * Get Schedule Edge Function
 *
 * 获取动漫更新时间表
 *
 * 访问模式：公开访问（无需认证）
 *
 * Query Parameters:
 * - day: 星期几（1-7，1=周一，7=周日），不传则返回全部
 *
 * Requirements: 8.4
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
import { BilibiliAdapter } from "../_shared/adapters/bilibili_adapter.ts";
// import { TMDBAdapter } from "../_shared/adapters/tmdb_adapter.ts"; // 暂时禁用

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

    // 解析星期参数
    const dayParam = url.searchParams.get("day");
    let day: number | undefined;

    if (dayParam !== null) {
      day = parseInt(dayParam, 10);
      if (isNaN(day) || day < 1 || day > 7) {
        return badRequest(
          "Invalid day parameter. Must be an integer between 1 (Monday) and 7 (Sunday).",
          origin
        );
      }
    }

    // 创建聚合器（暂时只用 Bilibili）
    const cache = new CacheLayer();
    const aggregator = new DataAggregator(
      [new BilibiliAdapter()],
      cache
    );

    // 获取时间表
    const schedule = await aggregator.getSchedule(day);

    // 构建响应
    const response: {
      day?: number;
      dayName?: string;
      schedule: typeof schedule;
      count: number;
    } = {
      schedule,
      count: schedule.length,
    };

    // 如果指定了星期，添加星期信息
    if (day !== undefined) {
      response.day = day;
      response.dayName = getDayName(day);
    }

    return successResponse(response, origin);
  } catch (error) {
    console.error("Unexpected error:", error);
    return internalError("Failed to fetch schedule", origin);
  }
});

/**
 * 获取星期名称
 */
function getDayName(day: number): string {
  const dayNames = [
    "", // 0 不使用
    "周一",
    "周二",
    "周三",
    "周四",
    "周五",
    "周六",
    "周日",
  ];
  return dayNames[day] || "";
}
