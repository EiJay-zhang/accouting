#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> 启动后端 http://127.0.0.1:8000"
cd "$ROOT/server"
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!

cleanup() {
  kill "$BACKEND_PID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 1
if ! curl -sf http://127.0.0.1:8000/api/health > /dev/null; then
  echo "后端启动失败，请检查 Python 依赖是否已安装："
  echo "  cd server && python3 -m pip install -r requirements.txt"
  exit 1
fi

echo "==> 启动前端 http://127.0.0.1:8080"
echo "    请在浏览器打开: http://127.0.0.1:8080"
cd "$ROOT"
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
