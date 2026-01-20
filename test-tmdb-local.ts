#!/usr/bin/env -S deno run --allow-env --allow-net

/**
 * 本地测试 TMDB API 连接
 */

// 从 .env 文件读取 token
const envContent = await Deno.readTextFile("supabase/functions/.env");
const tokenMatch = envContent.match(/TMDB_API_TOKEN=(.+)/);
const TMDB_API_TOKEN = tokenMatch ? tokenMatch[1].trim() : "";

console.log("=== TMDB API 本地测试 ===\n");
console.log("Token 信息:");
console.log("- 存在:", !!TMDB_API_TOKEN);
console.log("- 长度:", TMDB_API_TOKEN.length);
console.log("- 前缀:", TMDB_API_TOKEN.substring(0, 30) + "...\n");

// 测试 1: 获取动漫列表
console.log("测试 1: 获取日本动画列表");
const listUrl = "https://api.themoviedb.org/3/discover/tv?with_genres=16&with_origin_country=JP&language=zh-CN&sort_by=popularity.desc&page=1";

try {
  const response = await fetch(listUrl, {
    headers: {
      "Authorization": `Bearer ${TMDB_API_TOKEN}`,
      "accept": "application/json",
    },
  });

  console.log("- 状态码:", response.status);
  
  if (response.ok) {
    const data = await response.json();
    console.log("- 结果数量:", data.results?.length || 0);
    if (data.results?.[0]) {
      console.log("- 第一个结果:", data.results[0].name);
    }
  } else {
    const error = await response.text();
    console.log("- 错误:", error);
  }
} catch (error) {
  console.error("- 请求失败:", error.message);
}

console.log("\n测试 2: 搜索动漫");
const searchUrl = "https://api.themoviedb.org/3/search/tv?query=进击的巨人&language=zh-CN";

try {
  const response = await fetch(searchUrl, {
    headers: {
      "Authorization": `Bearer ${TMDB_API_TOKEN}`,
      "accept": "application/json",
    },
  });

  console.log("- 状态码:", response.status);
  
  if (response.ok) {
    const data = await response.json();
    console.log("- 总结果数:", data.total_results || 0);
    console.log("- 返回数量:", data.results?.length || 0);
    if (data.results?.[0]) {
      console.log("- 第一个结果:", data.results[0].name);
    }
  } else {
    const error = await response.text();
    console.log("- 错误:", error);
  }
} catch (error) {
  console.error("- 请求失败:", error.message);
}

console.log("\n=== 测试完成 ===");
