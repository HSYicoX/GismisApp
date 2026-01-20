/**
 * JWT 验证模块
 * 
 * 为 Edge Functions 提供自建 JWT 验证功能
 * 注意：这是自建 JWT，不是 Supabase Auth JWT
 * 
 * 使用 Web Crypto API 实现，无需外部依赖
 */

// JWT 密钥（从环境变量加载）
const JWT_SECRET = Deno.env.get("JWT_SECRET") || "";

/**
 * JWT Payload 类型定义
 */
export interface JWTPayload {
  sub: string;           // 用户 ID
  exp: number;           // 过期时间（Unix 时间戳）
  iat: number;           // 签发时间
  iss?: string;          // 签发者
  aud?: string;          // 受众
  [key: string]: unknown; // 其他自定义字段
}

/**
 * 验证结果类型
 */
export interface AuthResult {
  success: boolean;
  userId?: string;
  payload?: JWTPayload;
  error?: string;
}

/**
 * 从请求头中提取 Bearer Token
 * 
 * @param request - HTTP 请求对象
 * @returns Token 字符串或 null
 */
export function extractBearerToken(request: Request): string | null {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return null;
  }

  const parts = authHeader.split(" ");
  if (parts.length !== 2 || parts[0].toLowerCase() !== "bearer") {
    return null;
  }

  return parts[1];
}

/**
 * Base64URL 解码
 */
function base64UrlDecode(str: string): Uint8Array {
  // 补齐 padding
  const padding = "=".repeat((4 - (str.length % 4)) % 4);
  const base64 = str.replace(/-/g, "+").replace(/_/g, "/") + padding;
  const binary = atob(base64);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

/**
 * 验证 JWT Token
 * 
 * @param token - JWT Token 字符串
 * @returns 验证结果
 */
export async function verifyJWT(token: string): Promise<AuthResult> {
  if (!JWT_SECRET) {
    console.error("JWT_SECRET environment variable is not set");
    return {
      success: false,
      error: "Server configuration error",
    };
  }

  try {
    const parts = token.split(".");
    if (parts.length !== 3) {
      return {
        success: false,
        error: "Invalid token format",
      };
    }

    const [headerB64, payloadB64, signatureB64] = parts;

    // 创建 CryptoKey 用于验证
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(JWT_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );

    // 验证签名
    const signatureInput = `${headerB64}.${payloadB64}`;
    const signature = base64UrlDecode(signatureB64);
    
    const isValid = await crypto.subtle.verify(
      "HMAC",
      key,
      signature,
      new TextEncoder().encode(signatureInput)
    );

    if (!isValid) {
      return {
        success: false,
        error: "Invalid signature",
      };
    }

    // 解码 payload
    const payloadJson = new TextDecoder().decode(base64UrlDecode(payloadB64));
    const payload = JSON.parse(payloadJson) as JWTPayload;

    // 检查过期时间
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      return {
        success: false,
        error: "Token expired",
      };
    }

    // 提取用户 ID
    const userId = payload.sub;
    if (!userId) {
      return {
        success: false,
        error: "Invalid token: missing user ID",
      };
    }

    return {
      success: true,
      userId,
      payload,
    };
  } catch (error) {
    console.error("JWT verification failed:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Invalid token",
    };
  }
}

/**
 * 验证请求中的 JWT
 * 
 * @param request - HTTP 请求对象
 * @returns 验证结果
 */
export async function authenticateRequest(request: Request): Promise<AuthResult> {
  const token = extractBearerToken(request);
  
  if (!token) {
    return {
      success: false,
      error: "Missing authorization token",
    };
  }

  return verifyJWT(token);
}

/**
 * 从请求中提取用户 ID（便捷方法）
 * 
 * @param request - HTTP 请求对象
 * @returns 用户 ID 或 null
 */
export async function getUserId(request: Request): Promise<string | null> {
  const result = await authenticateRequest(request);
  return result.success ? result.userId ?? null : null;
}

/**
 * 解码 JWT（不验证签名，仅用于调试）
 * 
 * @param token - JWT Token 字符串
 * @returns 解码后的 payload 或 null
 */
export function decodeJWT(token: string): JWTPayload | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) {
      return null;
    }
    const payloadJson = new TextDecoder().decode(base64UrlDecode(parts[1]));
    return JSON.parse(payloadJson) as JWTPayload;
  } catch {
    return null;
  }
}

/**
 * 检查 Token 是否即将过期（用于提前刷新）
 * 
 * @param payload - JWT Payload
 * @param thresholdSeconds - 过期阈值（秒），默认 5 分钟
 * @returns 是否即将过期
 */
export function isTokenExpiringSoon(
  payload: JWTPayload,
  thresholdSeconds: number = 300
): boolean {
  if (!payload.exp) {
    return false;
  }
  
  const now = Math.floor(Date.now() / 1000);
  return payload.exp - now < thresholdSeconds;
}
