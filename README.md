# account

个人记账 App，包含 Flutter 客户端和 FastAPI 后端。App 通过 HTTP 接口读写交易数据，数据持久化在 SQLite 数据库中。

## 技术栈

| 层级 | 技术 |
|------|------|
| 客户端 | Flutter (Dart) + fl_chart |
| 后端 | FastAPI + SQLite |
| 通信 | REST API / JSON |

## 项目结构

```
account/
├── lib/                     # Flutter 客户端
│   ├── api/                 # HTTP 客户端与接口封装
│   ├── config/              # API 地址等配置
│   ├── constants/           # 颜色、样式常量
│   ├── models/              # 数据模型
│   ├── pages/               # 页面（记账、账单、报告、设置）
│   ├── services/            # 业务逻辑
│   └── widgets/             # 公共组件与图表
├── server/                  # 后端服务
│   ├── main.py              # FastAPI 入口与路由
│   ├── database.py          # SQLite 连接，启动时执行建表脚本
│   ├── init_db.py           # 手动初始化数据库
│   ├── sql/                 # 建表、默认分类、示例数据
│   ├── requirements.txt     # Python 依赖
│   └── account.db           # 默认数据库文件（可用 DATABASE_PATH 改位置）
├── scripts/
│   └── start_dev.sh         # 一键启动开发环境
└── pubspec.yaml
```

## 环境要求

- **Flutter SDK** 3.12+
- **Python** 3.9+
- **curl**（用于验证接口，可选）

> 运行 iOS / macOS 原生版需要 Xcode。Web 调试无需 Xcode，推荐使用。

---

## 项目启动

### 首次安装依赖

首次安装依赖时，还需配置 DeepSeek（见下方「DeepSeek AI 配置」）。

```bash
# Python 后端依赖
cd server
python3 -m pip install -r requirements.txt
cp .env.example .env   # 填入你的 DeepSeek API Key

# Flutter 客户端依赖
cd ..
flutter pub get
```

### 方式一：一键启动（推荐）

在项目根目录执行：

```bash
bash scripts/start_dev.sh
```

脚本会自动：
1. 启动后端 `http://127.0.0.1:8000`
2. 启动前端 `http://127.0.0.1:8080`
3. 检查后端健康状态

启动成功后，在浏览器打开：**http://127.0.0.1:8080**

### 方式二：手动分终端启动

**终端 1 — 后端**

```bash
cd server
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

看到 `Application startup complete` 表示后端已就绪。

**终端 2 — 前端（Web 固定端口）**

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

浏览器访问：**http://127.0.0.1:8080**

**其他运行目标**

```bash
flutter run -d chrome     # 自动打开 Chrome
flutter run -d macos      # macOS 桌面版（需 Xcode）
flutter run               # 自动选择已连接设备
```

### 启动验证

| 检查项 | 命令 / 地址 | 期望结果 |
|--------|-------------|----------|
| 后端根路径 | http://127.0.0.1:8000/ | 返回 API 信息 JSON |
| 健康检查 | http://127.0.0.1:8000/api/health | `{"status":"ok"}` |
| 交互式文档 | http://127.0.0.1:8000/docs | Swagger UI |
| 前端 App | http://127.0.0.1:8080 | 记账 App 界面 |

```bash
# 命令行快速验证
curl http://127.0.0.1:8000/api/health
lsof -i :8000    # 确认后端端口在监听
lsof -i :8080    # 确认前端端口在监听
```

### 地址说明

| 地址 | 用途 |
|------|------|
| `http://127.0.0.1:8000` | 后端 API 服务 |
| `http://127.0.0.1:8080` | Flutter Web App |

> **注意：** 8000 是接口地址，8080 才是 App 页面。请勿在浏览器直接访问 8000 当作前端使用。

### 客户端 API 地址配置

默认配置见 `lib/config/api_config.dart`：

| 平台 | 默认 API 地址 |
|------|---------------|
| iOS / macOS / Web | `http://127.0.0.1:8000` |
| Android 模拟器 | `http://10.0.2.2:8000` |
| 真机调试 | 电脑局域网 IP，如 `http://192.168.1.100:8000` |

修改方式（三选一）：

1. **App 内设置页** — 填写 API 地址后保存
2. **启动参数** — `flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000`
3. **查本机 IP（macOS）** — `ipconfig getifaddr en0`

---

## 真机运行与打包

App 可以运行在 Android / iOS 真机上。手机上的 App 仍需要通过 HTTP 访问你电脑或服务器上的后端 API。

### 环境准备

| 平台 | 需要安装 |
|------|----------|
| Android 真机 | [Android Studio](https://developer.android.com/studio) + SDK，开启 USB 调试 |
| iPhone 真机 | Xcode（App Store）+ Apple 开发者账号（免费账号可本机调试） |

当前机器若 `flutter doctor` 提示 Android SDK / Xcode 未就绪，需先完成安装。

### 第一步：让后端可被手机访问

手机不能访问 `127.0.0.1`（那是手机自己）。后端需监听所有网卡，且电脑与手机在同一 Wi‑Fi：

```bash
cd server
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

查电脑局域网 IP：

```bash
ipconfig getifaddr en0
# 例如得到 192.168.1.100
```

手机浏览器访问 `http://192.168.1.100:8000/api/health` 应返回 `{"status":"ok"}`。

### 第二步：连接真机并运行

**Android：**

```bash
# USB 连接手机，开启开发者模式与 USB 调试
flutter devices
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

**iOS：**

```bash
# USB 连接 iPhone，Xcode 中信任开发者
flutter devices
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

也可安装 App 后在 **设置** 页手动填写 API 地址 `http://192.168.1.100:8000`。

### 第三步：打包安装包

**Android APK（可直接装到手机）：**

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.100:8000
# 输出：build/app/outputs/flutter-apk/app-release.apk
```

**iOS（需 Mac + Xcode）：**

```bash
flutter build ios --release --dart-define=API_BASE_URL=http://192.168.1.100:8000
# 然后用 Xcode 打开 ios/Runner.xcworkspace 签名并安装到设备
```

### 注意事项

- 打包时 `--dart-define=API_BASE_URL=...` 需改成你实际的后端地址；上线生产环境建议使用 HTTPS 域名
- AI 对话依赖后端 `server/.env` 中的 DeepSeek Key，与运行平台无关
- 本机开发默认允许 HTTP 明文请求（Android `usesCleartextTraffic`、iOS 本地网络例外已配置）

---

## API 接口

**Base URL：** `http://127.0.0.1:8000`

**Content-Type：** `application/json`

**在线文档：** http://127.0.0.1:8000/docs

### 接口一览

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/` | 服务信息与文档入口 |
| GET | `/api/health` | 健康检查 |
| GET | `/api/categories` | 获取分类，可用 `type=income` 或 `expense` 筛选 |
| POST | `/api/categories` | 新增分类 |
| PUT | `/api/categories/{id}` | 修改分类名称、图标、颜色 |
| DELETE | `/api/categories/{id}` | 删除没有账单的分类 |
| GET | `/api/tags` | 获取标签，可用 `category_id` 筛选 |
| POST | `/api/tags` | 为分类新增标签 |
| PUT | `/api/tags/{id}` | 修改标签名称 |
| DELETE | `/api/tags/{id}` | 删除标签 |
| POST | `/api/imports/preview` | 预览支付宝、微信或银行卡账单 |
| POST | `/api/imports/commit` | 确认导入预览中选中的账单 |
| GET | `/api/transactions` | 获取某月交易列表 |
| GET | `/api/transactions/summary` | 获取某月收支汇总 |
| GET | `/api/reports/categories` | 获取某月分类统计报告 |
| GET | `/api/chat/status` | 检查 DeepSeek 是否已配置 |
| POST | `/api/chat` | AI 对话 |
| POST | `/api/transactions` | 新增一笔交易 |

---

### GET `/`

服务信息。

**响应示例：**

```json
{
  "name": "Account API",
  "status": "ok",
  "docs": "/docs",
  "health": "/api/health"
}
```

---

### GET `/api/health`

健康检查，用于确认后端是否正常运行。

**响应示例：**

```json
{
  "status": "ok"
}
```

---

### 分类 `/api/categories`

分类区分 `income`（收入）和 `expense`（支出）。同一名称可以各有一条。类型在创建时确定，之后不能修改。分类下还有账单时不能删除。

**GET** 可选查询参数 `type=income` 或 `type=expense`。

**POST** 请求体：`name`、`icon`、`color`（`#RRGGBB`）、`type`。

**PUT** `/api/categories/{id}` 请求体：`name`、`icon`、`color`。

### 标签 `/api/tags`

标签属于某个分类。同一分类下名称不能重复。删除分类时，它的标签一并删除。标签只用于记一笔时快捷填入备注，不会单独记在账单上。

**GET** 可选查询参数 `category_id`。

**POST** 请求体：`category_id`、`name`。

**PUT** `/api/tags/{id}` 请求体：`name`。

**响应示例：**

```json
[
  {
    "id": 1,
    "name": "餐饮",
    "icon": "🍜",
    "color": "#FF9800",
    "type": "expense"
  },
  {
    "id": 4,
    "name": "工资",
    "icon": "💰",
    "color": "#4CAF50",
    "type": "income"
  }
]
```

---

### GET `/api/transactions`

获取指定年月的交易列表，按日期倒序排列。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| year | int | 是 | 年份，如 2026 |
| month | int | 是 | 月份，1–12 |

**请求示例：**

```bash
curl "http://127.0.0.1:8000/api/transactions?year=2026&month=8"
```

**响应示例：**

```json
[
  {
    "id": 1,
    "title": "午餐·外卖",
    "category": {
      "id": 1,
      "name": "餐饮",
      "icon": "🍜",
      "color": "#FF9800",
      "type": "expense"
    },
    "amount": 68.5,
    "type": "expense",
    "date": "2026-08-07"
  }
]
```

---

### GET `/api/transactions/summary`

获取指定年月的收支汇总。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| year | int | 是 | 年份 |
| month | int | 是 | 月份 |

**请求示例：**

```bash
curl "http://127.0.0.1:8000/api/transactions/summary?year=2026&month=8"
```

**响应示例：**

```json
{
  "year": 2026,
  "month": 8,
  "income": 21700.0,
  "expense": 757.5,
  "total": 20942.5
}
```

> `total = income - expense`

---

### GET `/api/reports/categories`

获取指定年月的分类统计，供「报告」页图表与列表使用。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| year | int | 是 | 年份 |
| month | int | 是 | 月份 |

**请求示例：**

```bash
curl "http://127.0.0.1:8000/api/reports/categories?year=2026&month=8"
```

**响应示例：**

```json
{
  "year": 2026,
  "month": 8,
  "income": 21700.0,
  "expense": 757.5,
  "categories": [
    {
      "category": {
        "id": 1,
        "name": "餐饮",
        "icon": "🍜",
        "color": "#FF9800",
        "type": "expense"
      },
      "income": 0.0,
      "expense": 83.5,
      "transaction_count": 2
    }
  ]
}
```

---

### GET `/api/chat/status`

检查 DeepSeek API Key 是否已在后端配置。

**响应示例：**

```json
{
  "configured": true,
  "model": "deepseek-chat"
}
```

---

### POST `/api/chat`

AI 对话接口，后端代理转发至 DeepSeek。

**请求 Body：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| messages | array | 是 | 对话历史，每项含 `role`（user/assistant）和 `content` |
| include_context | bool | 否 | 是否带入记账数据，默认 `true` |
| year | int | 否 | 上下文月份年份，默认当前年 |
| month | int | 否 | 上下文月份，默认当前月 |

**请求示例：**

```bash
curl -X POST http://127.0.0.1:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "分析我本月支出结构"}
    ],
    "include_context": true,
    "year": 2026,
    "month": 8
  }'
```

**响应示例：**

```json
{
  "reply": "根据你 8 月的记账数据，支出主要集中在..."
}
```

**错误响应：**

| HTTP 状态码 | 说明 |
|-------------|------|
| 503 | `DEEPSEEK_API_KEY` 未配置 |
| 502 | DeepSeek 服务连接失败或返回错误 |

---

### POST `/api/transactions`

新增一笔交易。

**请求 Body：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| title | string | 是 | 标题，1–200 字符 |
| category_id | int | 是 | 分类 ID |
| amount | float | 是 | 金额，必须 > 0 |
| type | string | 是 | `income`（收入）或 `expense`（支出） |
| date | string | 否 | 日期，格式 `YYYY-MM-DD`，默认当天 |

**请求示例：**

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

**成功响应：** HTTP 201，Body 为完整的 `TransactionOut` 对象。

**错误响应：**

| HTTP 状态码 | 说明 |
|-------------|------|
| 400 | 参数无效、分类不存在、日期格式错误 |
| 422 | 请求体字段校验失败 |

---

### 数据模型

**TransactionType**

```
income   — 收入
expense  — 支出
```

**CategoryOut**

```json
{
  "id": 1,
  "name": "餐饮",
  "icon": "🍜",
  "color": "#FF9800",
  "type": "expense"
}
```

**TransactionOut**

```json
{
  "id": 1,
  "title": "午餐",
  "category": { "...CategoryOut" },
  "amount": 35.5,
  "type": "expense",
  "date": "2026-08-27"
}
```

---

## 功能说明

| 页面 | 功能 | 使用的接口 |
|------|------|-----------|
| 记账 | 当月收支概览、按日分组交易列表 | `summary` + `transactions` |
| 记一笔 | 新增收入/支出，选分类后可点标签填入备注 | `categories` + `tags` + `POST transactions` |
| 账单 | 按月浏览账单明细 | `summary` + `transactions` |
| 报告 | 收支环形图、分类饼图、柱状图 | `reports/categories` |
| AI | DeepSeek 对话，分析收支与理财建议 | `chat` |
| 设置 | 配置 API 地址、外观、分类、标签，导入支付宝/微信/银行卡账单 | 本地持久化；导入走 `imports` |

---

## DeepSeek AI 配置

AI 对话通过后端代理调用 DeepSeek，**API Key 只保存在服务端**，不会暴露给 App。

### 1. 获取 API Key

登录 [DeepSeek 开放平台](https://platform.deepseek.com/)，创建 API Key。

### 2. 配置 `server/.env`

```bash
cd server
cp .env.example .env
```

编辑 `.env` 文件：

```env
DEEPSEEK_API_KEY=sk-你的密钥
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat
```

### 3. 重启后端并验证

```bash
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000

curl http://127.0.0.1:8000/api/chat/status
# {"configured":true,"model":"deepseek-chat"}
```

### 4. 在 App 中使用

底部导航 **AI** 标签，或 **设置 → AI 记账助手**。

- 默认带入当月记账数据作为上下文（右上角图标可开关）
- 支持快捷提问，如「分析我本月支出结构」

---

## 数据库

脚本在 `server/sql/`：

| 文件 | 作用 | 何时执行 |
|------|------|----------|
| `schema.sql` | 建表和索引 | 每次 `init_db`，以及后端启动时 |
| `seed_categories.sql` | 8 个默认分类（工资为收入，其余为支出） | 同上，按名称和类型去重 |
| `seed_tags.sql` | 默认分类的常用标签 | 仅当标签表为空 |
| `migrate_category_type.sql` | 给旧库的分类补上收支类型 | 仅当 `categories` 还没有 `type` 列 |
| `seed_demo.sql` | 2026 年 8 月示例账单 | 仅 `python3 init_db.py --demo`，且交易表为空 |

服务器上只建空库和默认分类，不要加 `--demo`。

```bash
cd server
cp .env.example .env
# 在 .env 中设置 DATABASE_PATH=/var/lib/account/account.db

python3 init_db.py
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

未设置 `DATABASE_PATH` 时，数据库文件是 `server/account.db`。后端启动仍会执行建表和默认分类，已有交易不会被覆盖或清空。

本地一键启动 `scripts/start_dev.sh` 会执行 `init_db.py --demo`。交易表里已经有数据时，示例账单不会再次写入。

重置：停掉后端，删除数据库文件，再执行 `python3 init_db.py`。需要示例数据时加上 `--demo`。

## 常见问题

**浏览器报 `ERR_CONNECTION_REFUSED`**

后端未启动。执行：

```bash
lsof -i :8000
curl http://127.0.0.1:8000/api/health
```

无响应则重新启动 uvicorn。

**App 显示加载失败**

1. 确认后端已启动（8000 端口）
2. 确认访问的是 App 地址（8080），不是 API 地址（8000）
3. 在「设置」页检查 API 地址是否正确
4. 真机调试时使用局域网 IP

**macOS 构建失败**

提示找不到 `xcodebuild` 时，改用 Web 模式：

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

**后端进程意外退出（exit 143）**

通常是终端关闭或被手动 kill，重新执行启动命令即可。

**数据库重置**

停掉后端，删除数据库文件（默认 `server/account.db`，或 `.env` 里的 `DATABASE_PATH`），再执行 `cd server && python3 init_db.py`。本地需要示例账单时加上 `--demo`。

**AI 提示 API Key 未配置**

1. 确认 `server/.env` 中已填写 `DEEPSEEK_API_KEY`
2. 重启后端（修改 `.env` 后必须重启）
3. 执行 `curl http://127.0.0.1:8000/api/chat/status` 确认 `configured` 为 `true`

**AI 回复失败（502）**

通常是 DeepSeek 余额不足、Key 无效或网络问题。登录 DeepSeek 控制台检查余额与 Key 状态。
