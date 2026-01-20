# 中国大陆开发者可在服务器配置代理环境使用 API，该文档示例代理端口为 7890

#!/bin/bash

echo "检查代理配置..."
echo ""
echo "1. 测试代理是否可用:"
curl -x http://172.21.0.1:7890 -sS --max-time 5 https://www.google.com -o /dev/null && echo "✓ 代理可用" || echo "✗ 代理不可用"
echo ""
echo "2. 测试直连 TMDB (可能失败):"
curl -sS --max-time 5 https://api.themoviedb.org/3/configuration -o /dev/null && echo "✓ 直连成功" || echo "✗ 直连失败"
echo ""
echo "3. 测试通过代理访问 TMDB:"
curl -x http://172.21.0.1:7890 -sS --max-time 5 https://api.themoviedb.org/3/configuration -o /dev/null && echo "✓ 代理访问成功" || echo "✗ 代理访问失败"
