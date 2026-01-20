# Gismis - 动漫追番助手

<div align="center">

![Gismis Logo](logo/2/pink.png)

一个现代化的动漫追番应用，基于 Flutter 和 Supabase 构建

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![TMDB](https://img.shields.io/badge/TMDB-Data%20Source-01D277?logo=themoviedatabase)](https://www.themoviedb.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[功能特性](#功能特性) • [技术栈](#技术栈) • [快速开始](#快速开始) • [项目结构](#项目结构) • [开发指南](#开发指南)

</div>

---

## 📱 功能特性

### 核心功能
- **动漫浏览** - 基于 TMDB 的海量动漫数据库，支持分页加载
- **智能搜索** - 快速搜索动漫，支持中文、日文标题
- **详情查看** - 完整的动漫信息展示，包括简介、评分、状态等
- **收藏管理** - 本地优先的收藏系统，支持离线访问
- **观看历史** - 自动记录观看进度，跨设备同步
- **番剧时间表** - 按星期分组的新番播放时间表

### AI 助手
- **智能对话** - 基于 DeepSeek 的 AI 助手，提供动漫推荐和问答
- **流式响应** - SSE 实时流式输出，体验流畅
- **热门问题** - 预设常见问题，快速获取答案
- **个性化推荐** - 基于用户观看历史的智能推荐

### 用户体验
- **离线优先** - 缓存优先策略，支持离线浏览
- **自动刷新** - 后台自动更新缓存数据
- **响应式设计** - 适配多种屏幕尺寸
- **流畅动画** - 精心设计的过渡动画和交互效果

---

## 🛠 技术栈

### 前端 (Flutter)
- **框架**: Flutter 3.0+
- **状态管理**: Riverpod
- **网络请求**: Dio
- **本地存储**: Hive
- **安全存储**: flutter_secure_storage
- **路由**: go_router

### 后端 (Supabase)
- **Edge Functions**: Deno Runtime
- **数据库**: PostgreSQL
- **认证**: Supabase Auth (JWT)
- **存储**: Supabase Storage
- **实时**: PostgreSQL RLS

### 数据源
- **TMDB API** - 动漫元数据、海报、评分
- **DeepSeek AI** - AI 对话和推荐

### 开发工具
- **测试**: Property-Based Testing (PBT)
- **代码质量**: Dart Analyzer
- **CI/CD**: GitHub Actions (待配置)

---

## 🚀 快速开始

### 前置要求

- Flutter SDK 3.0+
- Dart SDK 3.0+
- Supabase CLI
- Node.js 18+ (用于 Edge Functions)
- Docker (可选，用于本地 Supabase)

### 安装步骤

1. **克隆仓库**
```bash
git clone https://github.com/yourusername/gismis.git
cd gismis
```

2. **安装 Flutter 依赖**
```bash
cd gismis
flutter pub get
```

3. **配置环境变量**

创建 `gismis/.env` 文件：
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

创建 `supabase/functions/.env` 文件：
```env
TMDB_API_TOKEN=your-tmdb-bearer-token
DEEPSEEK_API_KEY=your-deepseek-api-key
DEEPSEEK_API_URL=https://api.deepseek.com
```

4. **启动 Supabase 本地环境** (可选)
```bash
cd supabase
supabase start
```

5. **部署 Edge Functions**
```bash
cd supabase
supabase functions deploy get-anime-list
supabase functions deploy get-anime-detail
supabase functions deploy search-anime
supabase functions deploy ai-chat
supabase functions deploy ai-hot-questions
# ... 部署其他函数
```

6. **运行应用**
```bash
cd gismis
flutter run
```

---

## 📁 项目结构

```
gismis/
├── gismis/                      # Flutter 应用
│   ├── lib/
│   │   ├── app/                 # 应用配置和路由
│   │   │   ├── router.dart      # 路由配置
│   │   │   └── theme/           # 主题配置
│   │   ├── core/                # 核心功能
│   │   │   ├── network/         # 网络层 (Dio, SSE)
│   │   │   ├── storage/         # 存储层 (Hive, Secure Storage)
│   │   │   └── supabase/        # Supabase 客户端
│   │   ├── features/            # 功能模块
│   │   │   ├── home/            # 首页 (动漫列表)
│   │   │   ├── anime_detail/    # 动漫详情
│   │   │   ├── search/          # 搜索
│   │   │   ├── favorites/       # 收藏
│   │   │   ├── schedule/        # 时间表
│   │   │   ├── ai_assistant/    # AI 助手
│   │   │   ├── profile/         # 用户资料
│   │   │   └── auth/            # 认证
│   │   └── shared/              # 共享组件
│   │       ├── models/          # 数据模型
│   │       └── widgets/         # 通用组件
│   └── test/                    # 测试
│       ├── unit/                # 单元测试
│       ├── property/            # 属性测试 (PBT)
│       └── integration/         # 集成测试
│
├── supabase/                    # Supabase 后端
│   ├── functions/               # Edge Functions
│   │   ├── get-anime-list/      # 获取动漫列表
│   │   ├── get-anime-detail/    # 获取动漫详情
│   │   ├── search-anime/        # 搜索动漫
│   │   ├── ai-chat/             # AI 聊天
│   │   ├── get-favorites/       # 获取收藏
│   │   ├── sync-favorites/      # 同步收藏
│   │   └── _shared/             # 共享代码
│   │       ├── adapters/        # 数据适配器 (TMDB)
│   │       ├── aggregator/      # 数据聚合器
│   │       ├── auth.ts          # JWT 认证
│   │       ├── cors.ts          # CORS 处理
│   │       └── response.ts      # 响应格式化
│   └── migrations/              # 数据库迁移
│
└── docs/                        # 文档
    ├── TMDB.md                  # TMDB API 文档
    ├── edge-functions-verification.md  # API 测试指南
    └── timeline.md              # 开发时间线
```

---

## 🔧 开发指南

### 运行测试

```bash
# 运行所有测试
cd gismis
flutter test

# 运行单元测试
flutter test test/unit/

# 运行属性测试 (PBT)
flutter test test/property/

# 运行集成测试
flutter test test/integration/
```

### 代码规范

项目使用 Dart 官方代码规范，配置在 `analysis_options.yaml`：

```bash
# 分析代码
flutter analyze

# 格式化代码
dart format .
```

### Edge Functions 开发

```bash
# 本地测试 Edge Function
cd supabase
supabase functions serve get-anime-list --env-file functions/.env

# 测试 API
curl http://localhost:54321/functions/v1/get-anime-list?page=1
```

### 数据库迁移

```bash
# 创建新迁移
supabase migration new migration_name

# 应用迁移
supabase db push

# 重置数据库
supabase db reset
```

---

## 🌐 API 端点

### 动漫相关
- `GET /functions/v1/get-anime-list` - 获取动漫列表
- `GET /functions/v1/get-anime-detail/:id` - 获取动漫详情
- `GET /functions/v1/search-anime` - 搜索动漫
- `GET /functions/v1/get-schedule` - 获取番剧时间表

### 用户相关
- `GET /functions/v1/get-favorites` - 获取收藏列表 (需认证)
- `POST /functions/v1/sync-favorites` - 同步收藏 (需认证)
- `GET /functions/v1/get-profile` - 获取用户资料 (需认证)
- `PUT /functions/v1/update-profile` - 更新用户资料 (需认证)
- `POST /functions/v1/upload-avatar` - 上传头像 (需认证)

### AI 助手
- `POST /functions/v1/ai-chat` - AI 聊天 (SSE 流式)
- `GET /functions/v1/ai-hot-questions` - 获取热门问题

### 观看历史
- `GET /functions/v1/get-watch-history` - 获取观看历史 (需认证)
- `POST /functions/v1/update-watch-progress` - 更新观看进度 (需认证)

详细 API 文档请参考 [docs/edge-functions-verification.md](docs/edge-functions-verification.md)

---

## 🎨 设计理念

### 架构原则
- **Clean Architecture** - 清晰的分层架构，业务逻辑与 UI 分离
- **Repository Pattern** - 统一的数据访问层
- **Provider Pattern** - 使用 Riverpod 进行依赖注入和状态管理
- **Cache-First** - 缓存优先策略，提升用户体验

### 数据流
```
UI Layer (Widgets)
    ↓
Domain Layer (Providers)
    ↓
Data Layer (Repositories)
    ↓
Network/Cache (Dio/Hive)
```

### 测试策略
- **单元测试** - 测试独立函数和类
- **属性测试 (PBT)** - 验证通用属性和不变量
- **集成测试** - 测试完整的用户流程

---

## 🔐 环境变量

### Flutter 应用 (`gismis/.env`)
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Edge Functions (`supabase/functions/.env`)
```env
# TMDB API
TMDB_API_TOKEN=your-tmdb-bearer-token

# DeepSeek AI
DEEPSEEK_API_KEY=your-deepseek-api-key
DEEPSEEK_API_URL=https://api.deepseek.com

# Supabase (自动注入)
SUPABASE_URL=auto-injected
SUPABASE_SERVICE_ROLE_KEY=auto-injected
SUPABASE_ANON_KEY=auto-injected
```

---

## 📝 待办事项

- [ ] 完善用户认证流程
- [ ] 添加社交分享功能
- [ ] 实现评论系统
- [ ] 支持多语言 (i18n)
- [ ] 添加深色模式切换
- [ ] 优化图片加载和缓存
- [ ] 实现推送通知
- [ ] 添加 Web 端支持
- [ ] 完善 CI/CD 流程
- [ ] 编写更多测试用例

---

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

请确保：
- 代码通过 `flutter analyze` 检查
- 添加必要的测试
- 更新相关文档

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [TMDB](https://www.themoviedb.org) - 提供动漫数据
- [Supabase](https://supabase.com) - 后端服务
- [Flutter](https://flutter.dev) - 跨平台框架
- [DeepSeek](https://www.deepseek.com) - AI 服务

---

## 📧 联系方式

- 项目主页: [https://github.com/yourusername/gismis](https://github.com/yourusername/gismis)
- 问题反馈: [Issues](https://github.com/yourusername/gismis/issues)
- 邮箱: your.email@example.com

---

<div align="center">

**[⬆ 回到顶部](#gismis---动漫追番助手)**

Made with ❤️ by Gismis Team

</div>
