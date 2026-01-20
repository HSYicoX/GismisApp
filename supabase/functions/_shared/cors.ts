/**
 * CORS 头处理模块
 * 
 * 为 Edge Functions 提供统一的 CORS 配置
 * 支持预检请求（OPTIONS）和实际请求的 CORS 头
 */

// 允许的来源列表（生产环境应限制为具体域名）
const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:8080',
  'https://haokir.com',
  'https://www.haokir.com',
  'https://app.haokir.com',
];

// 默认 CORS 头
export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400', // 24 小时缓存预检结果
};

/**
 * 获取动态 CORS 头（基于请求来源）
 * 
 * @param origin - 请求的 Origin 头
 * @returns CORS 响应头
 */
export function getCorsHeaders(origin?: string | null): Record<string, string> {
  // 如果 origin 在允许列表中，返回具体的 origin
  // 否则返回通配符（开发环境）或拒绝
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin) 
    ? origin 
    : '*';

  return {
    ...corsHeaders,
    'Access-Control-Allow-Origin': allowedOrigin,
  };
}

/**
 * 处理 OPTIONS 预检请求
 * 
 * @param origin - 请求的 Origin 头
 * @returns 预检响应
 */
export function handleCorsPreflightRequest(origin?: string | null): Response {
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(origin),
  });
}

/**
 * 检查是否为预检请求
 * 
 * @param request - HTTP 请求对象
 * @returns 是否为 OPTIONS 预检请求
 */
export function isCorsPreflightRequest(request: Request): boolean {
  return request.method === 'OPTIONS';
}

/**
 * 为响应添加 CORS 头
 * 
 * @param response - 原始响应
 * @param origin - 请求的 Origin 头
 * @returns 带 CORS 头的新响应
 */
export function addCorsHeaders(response: Response, origin?: string | null): Response {
  const headers = new Headers(response.headers);
  const cors = getCorsHeaders(origin);
  
  for (const [key, value] of Object.entries(cors)) {
    headers.set(key, value);
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
