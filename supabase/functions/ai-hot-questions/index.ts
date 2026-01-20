/**
 * AI Hot Questions Edge Function
 *
 * 返回热门问题列表，可选基于用户历史推荐
 *
 * 功能：
 * - 返回预定义的热门问题列表
 * - 可选：基于用户历史对话推荐相关问题
 * - 支持匿名访问（返回通用热门问题）
 * - 支持认证访问（返回个性化推荐）
 *
 * Requirements: 7.1
 */

import { authenticateRequest } from "../_shared/auth.ts";
import {
  corsHeaders,
  handleCorsPreflightRequest,
  isCorsPreflightRequest,
} from "../_shared/cors.ts";
import { successResponse, badRequest } from "../_shared/response.ts";
import { getSupabaseAdmin, Tables } from "../_shared/supabase.ts";

// 预定义的热门问题分类
interface HotQuestionCategory {
  category: string;
  questions: string[];
}

// 默认热门问题列表
const DEFAULT_HOT_QUESTIONS: HotQuestionCategory[] = [
  {
    category: "推荐",
    questions: [
      "有什么好看的新番推荐吗？",
      "推荐一些治愈系动漫",
      "有什么热血战斗番推荐？",
      "推荐一些适合周末看的轻松动漫",
    ],
  },
  {
    category: "信息查询",
    questions: [
      "这季度有哪些新番？",
      "《葬送的芙莉莲》讲的是什么故事？",
      "有哪些动漫改编自轻小说？",
      "最近有什么高分动漫？",
    ],
  },
  {
    category: "讨论",
    questions: [
      "你觉得哪部动漫的世界观最有深度？",
      "有哪些动漫的结局让人印象深刻？",
      "你最喜欢哪个动漫角色？",
      "有哪些动漫值得二刷？",
    ],
  },
  {
    category: "原著相关",
    questions: [
      "这部动漫有原著小说吗？",
      "动漫和原著有什么区别？",
      "原著小说更新到哪里了？",
      "有哪些动漫改编得比原著好？",
    ],
  },
];

// 简化的热门问题列表（用于快速响应）
const SIMPLE_HOT_QUESTIONS: string[] = [
  "有什么好看的新番推荐吗？",
  "这季度有哪些新番？",
  "推荐一些治愈系动漫",
  "有什么热血战斗番推荐？",
  "《葬送的芙莉莲》讲的是什么故事？",
  "有哪些动漫改编自轻小说？",
  "最近有什么高分动漫？",
  "推荐一些适合周末看的轻松动漫",
];

/**
 * 从用户历史对话中提取关键词
 */
async function getUserInterests(userId: string): Promise<string[]> {
  const supabase = getSupabaseAdmin();

  // 获取用户最近的对话
  const { data, error } = await supabase
    .from(Tables.AI_CONVERSATIONS)
    .select("messages, title")
    .eq("user_id", userId)
    .order("updated_at", { ascending: false })
    .limit(5);

  if (error || !data || data.length === 0) {
    return [];
  }

  // 简单的关键词提取（从对话标题中提取）
  const interests: string[] = [];
  for (const conv of data) {
    if (conv.title) {
      // 提取可能的动漫名称或关键词
      const title = conv.title as string;
      if (title.includes("推荐")) interests.push("推荐");
      if (title.includes("新番")) interests.push("新番");
      if (title.includes("治愈")) interests.push("治愈");
      if (title.includes("热血")) interests.push("热血");
      if (title.includes("原著") || title.includes("小说")) interests.push("原著");
    }
  }

  return [...new Set(interests)]; // 去重
}

/**
 * 根据用户兴趣生成个性化问题
 */
function getPersonalizedQuestions(interests: string[]): string[] {
  const questions: string[] = [];

  // 根据兴趣添加相关问题
  for (const interest of interests) {
    switch (interest) {
      case "推荐":
        questions.push("还有其他类似的动漫推荐吗？");
        questions.push("有什么最近完结的好番？");
        break;
      case "新番":
        questions.push("下季度有什么值得期待的新番？");
        questions.push("这季度哪部新番评价最高？");
        break;
      case "治愈":
        questions.push("有什么日常系动漫推荐？");
        questions.push("推荐一些画风温馨的动漫");
        break;
      case "热血":
        questions.push("有什么打斗场面精彩的动漫？");
        questions.push("推荐一些运动番");
        break;
      case "原著":
        questions.push("有哪些动漫的原著值得一看？");
        questions.push("最近有什么轻小说改编的动漫？");
        break;
    }
  }

  // 如果没有足够的个性化问题，补充默认问题
  if (questions.length < 4) {
    const defaultQuestions = SIMPLE_HOT_QUESTIONS.filter(
      (q) => !questions.includes(q)
    );
    questions.push(...defaultQuestions.slice(0, 4 - questions.length));
  }

  return questions.slice(0, 8); // 最多返回 8 个问题
}

/**
 * 主处理函数
 */
Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");

  // 处理 CORS 预检请求
  if (isCorsPreflightRequest(req)) {
    return handleCorsPreflightRequest(origin);
  }

  // 支持 GET 和 POST 请求
  if (req.method !== "GET" && req.method !== "POST") {
    return badRequest("Method not allowed", origin);
  }

  // 解析查询参数
  const url = new URL(req.url);
  const format = url.searchParams.get("format") || "simple"; // simple | categorized
  const limit = parseInt(url.searchParams.get("limit") || "8", 10);

  // 尝试验证 JWT（可选）
  const authResult = await authenticateRequest(req);
  const userId = authResult.success ? authResult.userId : null;

  // 如果用户已认证，尝试获取个性化推荐
  let questions: string[] = [];
  let categories: HotQuestionCategory[] = [];

  if (userId) {
    try {
      const interests = await getUserInterests(userId);
      if (interests.length > 0) {
        questions = getPersonalizedQuestions(interests);
      }
    } catch (e) {
      console.error("Failed to get user interests:", e);
    }
  }

  // 如果没有个性化问题，使用默认问题
  if (questions.length === 0) {
    questions = SIMPLE_HOT_QUESTIONS.slice(0, limit);
  }

  // 根据格式返回不同的响应
  if (format === "categorized") {
    // 返回分类格式
    categories = DEFAULT_HOT_QUESTIONS.map((cat) => ({
      category: cat.category,
      questions: cat.questions.slice(0, Math.ceil(limit / 4)),
    }));

    return successResponse(
      {
        questions: questions.slice(0, limit),
        categories,
        personalized: userId !== null,
      },
      origin
    );
  }

  // 返回简单格式
  return successResponse(
    {
      questions: questions.slice(0, limit),
      personalized: userId !== null,
    },
    origin
  );
});
