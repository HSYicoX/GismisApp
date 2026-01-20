# Edge Functions 验证指南

本文档提供 Supabase Edge Functions 的验证步骤和测试命令。

## 前置条件

### 1. 环境变量配置

确保以下环境变量已在 Supabase Edge Functions 中配置：

```bash
# 必需的环境变量
JWT_SECRET=your_jwt_secret_key
SUPABASE_URL=https://api.haokir.com
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_ANON_KEY=your_anon_key

# AI 功能所需（可选）
DEEPSEEK_API_KEY=your_deepseek_api_key
DEEPSEEK_API_URL=https://api.deepseek.com
```

### 2. 部署 Edge Functions

```bash
# 进入 supabase 目录
cd supabase

# 部署所有 Edge Functions
supabase functions deploy get-favorites
supabase functions deploy sync-favorites
supabase functions deploy get-profile
supabase functions deploy update-profile
supabase functions deploy upload-avatar
supabase functions deploy get-signed-url
supabase functions deploy ai-chat
supabase functions deploy ai-hot-questions
supabase functions deploy get-watch-history
supabase functions deploy update-watch-progress
```

## 端点验证

### 基础 URL
```
https://api.haokir.com/functions/v1
```

### 测试变量设置
```bash
# 设置基础 URL
BASE_URL="https://api.haokir.com/functions/v1"

# 设置 API Key（anon key）
API_KEY="your_supabase_anon_key"

# 设置测试 JWT Token（需要有效的自建 JWT）
JWT_TOKEN="your_test_jwt_token"
```

---

## 1. CORS 预检测试

所有端点都应该正确响应 OPTIONS 请求：

```bash
# 测试 CORS 预检
curl -X OPTIONS "$BASE_URL/get-favorites" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization, content-type" \
  -v

# 期望响应：
# - HTTP 204
# - Access-Control-Allow-Origin: * 或 http://localhost:3000
# - Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
# - Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type
```

---

## 2. 认证测试（无 Token）

测试未认证请求是否正确返回 401：

```bash
# 测试无 Token 请求
curl -X GET "$BASE_URL/get-favorites" \
  -H "apikey: $API_KEY" \
  -H "Content-Type: application/json"

# 期望响应：
# HTTP 401
# {"success":false,"error":{"code":"UNAUTHORIZED","message":"Missing authorization token"}}
```

---

## 3. 收藏功能测试

### 3.1 获取收藏列表
```bash
curl -X GET "$BASE_URL/get-favorites" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json"

# 期望响应：
# HTTP 200
# {"success":true,"data":[...],"meta":{"timestamp":"..."}}
```

### 3.2 同步收藏
```bash
curl -X POST "$BASE_URL/sync-favorites" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "operations": [
      {
        "type": "add",
        "animeId": "test-anime-id",
        "timestamp": "2025-01-09T00:00:00Z"
      }
    ]
  }'

# 期望响应：
# HTTP 200
# {"success":true,"data":{"processed":1,"succeeded":...,"failed":...,"results":[...]}}
```

---

## 4. 用户资料测试

### 4.1 获取用户资料
```bash
curl -X GET "$BASE_URL/get-profile" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json"

# 期望响应：
# HTTP 200 或 201（首次创建）
# {"success":true,"data":{"id":"...","user_id":"...","nickname":...}}
```

### 4.2 更新用户资料
```bash
curl -X PUT "$BASE_URL/update-profile" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nickname": "测试用户",
    "bio": "这是一个测试简介"
  }'

# 期望响应：
# HTTP 200
# {"success":true,"data":{"id":"...","nickname":"测试用户","bio":"这是一个测试简介"}}
```

### 4.3 验证输入校验
```bash
# 测试昵称长度限制
curl -X PUT "$BASE_URL/update-profile" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nickname": "这是一个超过五十个字符的昵称测试这是一个超过五十个字符的昵称测试这是一个超过五十个字符的昵称测试"
  }'

# 期望响应：
# HTTP 422
# {"success":false,"error":{"code":"VALIDATION_ERROR","message":"Validation failed","details":{"nickname":"Nickname must be 50 characters or less"}}}
```

---

## 5. 头像上传测试

### 5.1 上传头像
```bash
# 使用 multipart/form-data 上传
curl -X POST "$BASE_URL/upload-avatar" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -F "file=@/path/to/test-image.jpg"

# 期望响应：
# HTTP 201
# {"success":true,"data":{"avatar_url":"user-avatars/...","path":"..."}}
```

### 5.2 获取签名 URL
```bash
curl -X POST "$BASE_URL/get-signed-url" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "bucket": "user-avatars",
    "path": "user-id/avatar.jpg",
    "expiresIn": 3600
  }'

# 期望响应：
# HTTP 200
# {"success":true,"data":{"signedUrl":"...","expiresAt":"..."}}
```

---

## 6. AI 助手测试

### 6.1 获取热门问题
```bash
# 匿名访问
curl -X GET "$BASE_URL/ai-hot-questions" \
  -H "apikey: $API_KEY"

# 期望响应：
# HTTP 200
# {"success":true,"data":{"questions":[...],"personalized":false}}

# 认证访问（个性化推荐）
curl -X GET "$BASE_URL/ai-hot-questions" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN"

# 期望响应：
# HTTP 200
# {"success":true,"data":{"questions":[...],"personalized":true}}
```

### 6.2 AI 聊天（SSE 流式）
```bash
curl -X POST "$BASE_URL/ai-chat" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{
    "message": "推荐一些好看的动漫",
    "model": "deepseek-chat"
  }' \
  --no-buffer

# 期望响应（SSE 流）：
# event: meta
# data: {"message_id":"...","conversation_id":"...","model":"deepseek-chat","fields":["content"]}
#
# event: field_start
# data: {"field":"content"}
#
# event: delta
# data: {"field":"content","text":"..."}
#
# event: field_end
# data: {"field":"content"}
#
# event: done
# data: {"tokens_used":...}
```

---

## 7. 观看历史测试

### 7.1 获取观看历史
```bash
curl -X GET "$BASE_URL/get-watch-history?page=1&pageSize=10" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN"

# 期望响应：
# HTTP 200
# {"success":true,"data":[...],"meta":{"timestamp":"...","pagination":{...}}}
```

### 7.2 更新观看进度
```bash
curl -X POST "$BASE_URL/update-watch-progress" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "episode_id": "valid-episode-uuid",
    "progress": 300,
    "duration": 1440
  }'

# 期望响应：
# HTTP 200
# {"success":true,"data":{"id":"...","episode_id":"...","progress":300,...}}
```

---

## 验证清单

### CORS 验证
- [ ] OPTIONS 请求返回 204
- [ ] 包含正确的 CORS 头

### JWT 验证
- [ ] 无 Token 请求返回 401
- [ ] 无效 Token 请求返回 401
- [ ] 过期 Token 请求返回 401
- [ ] 有效 Token 请求正常处理

### 功能验证
- [ ] get-favorites - 获取收藏列表
- [ ] sync-favorites - 同步收藏操作
- [ ] get-profile - 获取用户资料
- [ ] update-profile - 更新用户资料
- [ ] upload-avatar - 上传头像
- [ ] get-signed-url - 获取签名 URL
- [ ] ai-chat - AI 聊天（SSE）
- [ ] ai-hot-questions - 热门问题
- [ ] get-watch-history - 观看历史
- [ ] update-watch-progress - 更新进度

### 错误处理验证
- [ ] 输入验证错误返回 422
- [ ] 资源不存在返回 404
- [ ] 权限不足返回 403
- [ ] 服务器错误返回 500

---

## 常见问题

### 1. JWT 验证失败
- 检查 `JWT_SECRET` 环境变量是否正确配置
- 确保 JWT 使用 HS256 算法签名
- 检查 JWT 是否过期

### 2. 数据库连接失败
- 检查 `SUPABASE_URL` 和 `SUPABASE_SERVICE_ROLE_KEY` 配置
- 确保数据库迁移已执行

### 3. AI 功能不工作
- 检查 `DEEPSEEK_API_KEY` 配置
- 确保 DeepSeek API 可访问

### 4. SSE 流式响应问题
- 确保反向代理（Nginx/Cloudflare）已禁用缓冲
- 检查 `X-Accel-Buffering: no` 头是否生效
