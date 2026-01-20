/**
 * 统一响应格式模块
 * 
 * 为 Edge Functions 提供一致的 API 响应格式
 * 包含成功响应、错误响应和分页响应
 */

import { getCorsHeaders } from "./cors.ts";

/**
 * 标准 API 响应结构
 */
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: ApiError;
  meta?: ResponseMeta;
}

/**
 * API 错误结构
 */
export interface ApiError {
  code: string;
  message: string;
  details?: unknown;
}

/**
 * 响应元数据
 */
export interface ResponseMeta {
  timestamp: string;
  requestId?: string;
  pagination?: PaginationMeta;
}

/**
 * 分页元数据
 */
export interface PaginationMeta {
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
  hasMore: boolean;
}

/**
 * 错误码常量
 */
export const ErrorCodes = {
  // 客户端错误 (4xx)
  BAD_REQUEST: "BAD_REQUEST",
  UNAUTHORIZED: "UNAUTHORIZED",
  FORBIDDEN: "FORBIDDEN",
  NOT_FOUND: "NOT_FOUND",
  CONFLICT: "CONFLICT",
  VALIDATION_ERROR: "VALIDATION_ERROR",
  RATE_LIMITED: "RATE_LIMITED",
  
  // 服务端错误 (5xx)
  INTERNAL_ERROR: "INTERNAL_ERROR",
  SERVICE_UNAVAILABLE: "SERVICE_UNAVAILABLE",
  DATABASE_ERROR: "DATABASE_ERROR",
  EXTERNAL_SERVICE_ERROR: "EXTERNAL_SERVICE_ERROR",
} as const;

/**
 * 创建成功响应
 * 
 * @param data - 响应数据
 * @param origin - 请求来源（用于 CORS）
 * @param status - HTTP 状态码，默认 200
 * @returns Response 对象
 */
export function successResponse<T>(
  data: T,
  origin?: string | null,
  status: number = 200
): Response {
  const response: ApiResponse<T> = {
    success: true,
    data,
    meta: {
      timestamp: new Date().toISOString(),
    },
  };

  return new Response(JSON.stringify(response), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...getCorsHeaders(origin),
    },
  });
}

/**
 * 创建分页响应
 * 
 * @param data - 响应数据数组
 * @param pagination - 分页信息
 * @param origin - 请求来源（用于 CORS）
 * @returns Response 对象
 */
export function paginatedResponse<T>(
  data: T[],
  pagination: PaginationMeta,
  origin?: string | null
): Response {
  const response: ApiResponse<T[]> = {
    success: true,
    data,
    meta: {
      timestamp: new Date().toISOString(),
      pagination,
    },
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      ...getCorsHeaders(origin),
    },
  });
}

/**
 * 创建错误响应
 * 
 * @param code - 错误码
 * @param message - 错误消息
 * @param status - HTTP 状态码
 * @param origin - 请求来源（用于 CORS）
 * @param details - 错误详情（可选）
 * @returns Response 对象
 */
export function errorResponse(
  code: string,
  message: string,
  status: number,
  origin?: string | null,
  details?: unknown
): Response {
  const response: ApiResponse = {
    success: false,
    error: {
      code,
      message,
      ...(details && { details }),
    },
    meta: {
      timestamp: new Date().toISOString(),
    },
  };

  return new Response(JSON.stringify(response), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...getCorsHeaders(origin),
    },
  });
}

/**
 * 400 Bad Request 响应
 */
export function badRequest(
  message: string = "Bad request",
  origin?: string | null,
  details?: unknown
): Response {
  return errorResponse(ErrorCodes.BAD_REQUEST, message, 400, origin, details);
}

/**
 * 401 Unauthorized 响应
 */
export function unauthorized(
  message: string = "Unauthorized",
  origin?: string | null
): Response {
  return errorResponse(ErrorCodes.UNAUTHORIZED, message, 401, origin);
}

/**
 * 403 Forbidden 响应
 */
export function forbidden(
  message: string = "Forbidden",
  origin?: string | null
): Response {
  return errorResponse(ErrorCodes.FORBIDDEN, message, 403, origin);
}

/**
 * 404 Not Found 响应
 */
export function notFound(
  message: string = "Resource not found",
  origin?: string | null
): Response {
  return errorResponse(ErrorCodes.NOT_FOUND, message, 404, origin);
}

/**
 * 409 Conflict 响应
 */
export function conflict(
  message: string = "Resource conflict",
  origin?: string | null,
  details?: unknown
): Response {
  return errorResponse(ErrorCodes.CONFLICT, message, 409, origin, details);
}

/**
 * 422 Validation Error 响应
 */
export function validationError(
  message: string = "Validation failed",
  origin?: string | null,
  details?: unknown
): Response {
  return errorResponse(ErrorCodes.VALIDATION_ERROR, message, 422, origin, details);
}

/**
 * 429 Rate Limited 响应
 */
export function rateLimited(
  message: string = "Too many requests",
  origin?: string | null,
  retryAfter?: number
): Response {
  const response = errorResponse(ErrorCodes.RATE_LIMITED, message, 429, origin);
  
  if (retryAfter) {
    const headers = new Headers(response.headers);
    headers.set("Retry-After", retryAfter.toString());
    return new Response(response.body, {
      status: response.status,
      headers,
    });
  }
  
  return response;
}

/**
 * 500 Internal Server Error 响应
 */
export function internalError(
  message: string = "Internal server error",
  origin?: string | null
): Response {
  // 不暴露内部错误详情给客户端
  return errorResponse(ErrorCodes.INTERNAL_ERROR, message, 500, origin);
}

/**
 * 503 Service Unavailable 响应
 */
export function serviceUnavailable(
  message: string = "Service temporarily unavailable",
  origin?: string | null
): Response {
  return errorResponse(ErrorCodes.SERVICE_UNAVAILABLE, message, 503, origin);
}

/**
 * 数据库错误响应
 */
export function databaseError(
  message: string = "Database operation failed",
  origin?: string | null
): Response {
  return errorResponse(ErrorCodes.DATABASE_ERROR, message, 500, origin);
}

/**
 * 创建分页元数据
 * 
 * @param total - 总记录数
 * @param page - 当前页码
 * @param pageSize - 每页大小
 * @returns 分页元数据
 */
export function createPaginationMeta(
  total: number,
  page: number,
  pageSize: number
): PaginationMeta {
  const totalPages = Math.ceil(total / pageSize);
  return {
    total,
    page,
    pageSize,
    totalPages,
    hasMore: page < totalPages,
  };
}

/**
 * 从 Supabase 错误创建响应
 * 
 * @param error - Supabase 错误对象
 * @param origin - 请求来源
 * @returns Response 对象
 */
export function fromSupabaseError(
  error: { code?: string; message?: string; hint?: string },
  origin?: string | null
): Response {
  const code = error.code || "";
  const message = error.message || "Database error";

  // 映射 Supabase/PostgREST 错误码
  switch (code) {
    case "PGRST116":
      return notFound("Resource not found", origin);
    case "PGRST301":
      return badRequest("Invalid range", origin);
    case "23505":
      return conflict("Duplicate entry", origin);
    case "42501":
      return forbidden("Permission denied", origin);
    case "42P01":
      return notFound("Table not found", origin);
    case "23503":
      return badRequest("Foreign key violation", origin);
    case "23502":
      return validationError("Required field missing", origin);
    default:
      console.error("Supabase error:", error);
      return databaseError(message, origin);
  }
}
