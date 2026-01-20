/**
 * Test TMDB API Edge Function
 * 用于测试 TMDB API 连接和认证
 */

import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  // 处理 CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const TMDB_API_TOKEN = Deno.env.get("TMDB_API_TOKEN");
    
    const diagnostics = {
      tokenExists: !!TMDB_API_TOKEN,
      tokenLength: TMDB_API_TOKEN?.length || 0,
      tokenPrefix: TMDB_API_TOKEN?.substring(0, 20) || "N/A",
    };

    console.log("TMDB Diagnostics:", diagnostics);

    // 测试 TMDB API
    const testUrl = "https://api.themoviedb.org/3/discover/tv?with_genres=16&with_origin_country=JP&language=zh-CN&sort_by=popularity.desc&page=1";
    
    console.log("Testing URL:", testUrl);
    
    const response = await fetch(testUrl, {
      headers: {
        "Authorization": `Bearer ${TMDB_API_TOKEN}`,
        "accept": "application/json",
      },
    });

    console.log("Response status:", response.status);

    const responseText = await response.text();
    console.log("Response body length:", responseText.length);

    let data;
    try {
      data = JSON.parse(responseText);
    } catch (e) {
      data = { error: "Failed to parse JSON", body: responseText.substring(0, 500) };
    }

    return new Response(
      JSON.stringify({
        diagnostics,
        apiResponse: {
          status: response.status,
          ok: response.ok,
          data: data,
        },
      }, null, 2),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Test error:", error);
    return new Response(
      JSON.stringify({
        error: error.message,
        stack: error.stack,
      }, null, 2),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
