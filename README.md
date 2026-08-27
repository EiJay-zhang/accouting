# account

个人记账 App，包含 Flutter 客户端和 FastAPI 后端。App 通过 HTTP 接口读写交易数据，不再使用本地 Mock 数据。

## 技术栈

| 层级 | 技术 |
|------|------|
| 客户端 | Flutter (Dart) |
| 后端 | FastAPI + SQLite |
| 通信 | REST API / JSON |

## 项目结构

```
account/
├── lib/                 # Flutter 客户端
│   ├── api/             # HTTP 客户端与接口封装
│   ├── config/          # API 地址等配置
│   ├── models/          # 数据模型
│   ├── pages/           # 页面
│   └── services/        # 业务逻辑
├── server/              # 后端服务
│   ├── main.py          # FastAPI 入口
│   ├── database.py      # SQLite 初始化与种子数据
│   └── requirements.txt
└── pubspec.yaml
```

## 环境要求

- Flutter SDK（建议 3.12+）
- Python 3.9+
- 运行 iOS/macOS 原生版需要 Xcode；Web / Android 模拟器可直接调试

## 快速开始

### 1. 启动后端

```bash
cd server
python3 -m pip install -r requirements.txt
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

验证服务是否正常：

```bash
curl http://127.0.0.1:8000/api/health
# {"status":"ok"}
```

首次启动会自动创建 `server/account.db`，并写入默认分类与示例交易数据。

### 2. 启动客户端

另开一个终端：

```bash
flutter pub get
flutter run
```

常用运行目标：

```bash
flutter run -d chrome    # Web
flutter run -d macos     # macOS（需 Xcode）
flutter run              # 自动选择已连接设备
```

## API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查 |
| GET | `/api/categories` | 获取分类列表 |
| GET | `/api/transactions?year=&month=` | 获取某月交易 |
| GET | `/api/transactions/summary?year=&month=` | 获取月度汇总 |
| POST | `/api/transactions` | 新增一笔账 |

创建交易示例：

```bash
curl -X POST http://127.0.0.1:8000/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "title": "午餐",
    "category_id": 1,
    "amount": 35.5,
    "type": "expense"
  }'
```

> 根路径 `/` 没有页面，访问会返回 404，这是正常现象。请使用 `/api/*` 接口。

## API 地址配置

客户端默认地址见 `lib/config/api_config.dart`：

| 平台 | 默认地址 |
|------|----------|
| iOS / macOS / Web | `http://127.0.0.1:8000` |
| Android 模拟器 | `http://10.0.2.2:8000` |
| 真机调试 | 本机局域网 IP |

真机或自定义地址可通过启动参数覆盖：

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

## 功能说明

- **记账**：首页展示当月收支概览与按日分组的交易列表
- **记一笔**：支持收入/支出、分类、金额、备注
- **账单 / 报告 / 设置**：占位页面，待后续实现

## 常见问题

**浏览器报 `ERR_CONNECTION_REFUSED`**

后端未启动，或 8000 端口没有进程在监听。先执行：

```bash
lsof -i :8000
curl http://127.0.0.1:8000/api/health
```

若无响应，重新启动 uvicorn。

**App 显示加载失败**

1. 确认后端已启动
2. 确认 App 使用的 API 地址与运行平台匹配
3. 真机调试时使用 `--dart-define=API_BASE_URL=...` 指向电脑 IP

**macOS 构建失败**

若提示找不到 `xcodebuild`，说明未安装或未配置 Xcode Command Line Tools。可先用 `flutter run -d chrome` 调试。
