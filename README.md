# account

个人记账 App，包含 Flutter 客户端和 FastAPI 后端。App 通过 HTTP 接口读写交易数据，数据持久化在 SQLite 数据库中。支持多账号登录，每个账号的账单、分类、标签、预算和 AI 对话相互隔离。

## 功能特性

- **账号体系**：注册、登录、退出、修改昵称与密码，多账号管理，登录令牌 30 天有效
- **记账**：收入 / 支出分类，标签快捷填入，金额按「分」存储避免浮点误差
- **账单**：按周 / 月 / 年浏览，关键词搜索（标题、分类、标签），按收支类型、分类、标签筛选，编辑与删除
- **报告**：周 / 月 / 年统计，收支环形图、分类饼图、柱状图、趋势图，分类预算与超支提示
- **账单导入**：识别支付宝、微信、银行卡导出的 CSV / XLSX，自动匹配分类、跳过失败交易、按来源与单号去重
- **导入导出**：导出全部账单 CSV；导出当前账号的数据库备份
- **AI 助手**：接入 DeepSeek 与 Kimi，可切换服务商和模型，分析收支、给出建议，并支持在对话中直接生成一笔待确认的记账
- **外观**：浅色 / 深色 / 跟随系统

## 技术栈

| 层级 | 技术 |
|------|------|
| 客户端 | Flutter (Dart) + fl_chart |
| 后端 | FastAPI + SQLite |
| 通信 | REST API / JSON，Bearer Token 鉴权 |
| AI | DeepSeek、Kimi（Moonshot），由后端代理调用 |

## 项目结构

```
account/
├── lib/                     # Flutter 客户端
│   ├── api/                 # HTTP 客户端与接口封装（auth / chat / import / report / transaction）
│   ├── config/              # API 地址、登录态、主题、AI 模型选择
│   ├── constants/           # 颜色、样式常量
│   ├── models/              # 数据模型（用户、交易、对话）
│   ├── pages/               # 页面（登录、记账、账单、报告、AI、我的、分类/标签/导入/用户管理）
│   ├── services/            # 业务逻辑
│   ├── utils/               # 金额精度、文件保存（Web / 非 Web）
│   └── widgets/             # 公共组件与图表
├── server/                  # 后端服务
│   ├── main.py              # FastAPI 入口与路由
│   ├── auth.py              # 注册、登录、会话、账号管理
│   ├── chat_service.py      # AI 对话与记账草稿解析
│   ├── bill_import.py       # 支付宝 / 微信 / 银行卡账单解析
│   ├── money.py             # 元与「分」的换算
│   ├── database.py          # SQLite 连接、建表与旧库迁移
│   ├── init_db.py           # 手动初始化数据库
│   ├── test_ledger.py       # 后端规则测试
│   ├── sql/                 # 建表、默认分类、默认标签、示例数据
│   ├── requirements.txt     # Python 依赖
│   └── account.db           # 默认数据库文件（可用 DATABASE_PATH 改位置）
├── docs/
│   └── backend-deploy.md    # 服务器部署（systemd + Nginx + HTTPS）
├── scripts/
│   └── start_dev.sh         # 一键启动开发环境
└── pubspec.yaml
```

## 环境要求

- **Flutter SDK** 3.12+（Dart SDK `^3.12.2`）
- **Python** 3.9+
- **curl**（用于验证接口，可选）

> 运行 iOS / macOS 原生版需要 Xcode。Web 调试无需 Xcode，推荐使用。

---

## 项目启动

### 首次安装依赖

首次安装依赖时，还需要配置 AI 密钥（见下方「AI 助手配置」）。

```bash
# Python 后端依赖
cd server
python3 -m pip install -r requirements.txt
cp .env.example .env   # 填入 DeepSeek / Kimi 的 API Key（至少配一个）

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
1. 执行 `init_db.py --demo`（本地示例账单，交易表为空时才写入）
2. 启动后端 `http://127.0.0.1:8000`
3. 启动前端 `http://127.0.0.1:8080`
4. 检查后端健康状态

启动成功后，在浏览器打开：**http://127.0.0.1:8080**

首次打开需要注册账号。第一个注册的账号会接管库里尚未归属账号的默认分类和示例账单。

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

### 首次使用

1. 打开 App 后进入登录页，填写用户名和密码注册
2. 用户名 2–20 位，支持中文、字母、数字和下划线，不能有空格
3. 密码 6–64 位
4. 注册成功即自动登录，并生成该账号的 8 个默认分类和常用标签

### 启动验证

| 检查项 | 命令 / 地址 | 期望结果 |
|--------|-------------|----------|
| 后端根路径 | http://127.0.0.1:8000/ | 返回 API 信息 JSON |
| 健康检查 | http://127.0.0.1:8000/api/health | `{"status":"ok"}` |
| 账号状态 | http://127.0.0.1:8000/api/auth/status | `{"has_users":true}` 或 `false` |
| 交互式文档 | http://127.0.0.1:8000/docs | Swagger UI |
| 前端 App | http://127.0.0.1:8080 | 登录页 / 记账界面 |

```bash
# 命令行快速验证
curl http://127.0.0.1:8000/api/health
curl http://127.0.0.1:8000/api/auth/status
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

1. **App 内「我的」页** — 填写 API 地址后保存
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

也可安装 App 后在 **我的 → API 配置** 手动填写 API 地址。

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
- AI 对话依赖后端 `server/.env` 中的密钥，与运行平台无关
- 本机开发默认允许 HTTP 明文请求（Android `usesCleartextTraffic`、iOS 本地网络例外已配置）
- 公网部署请参考 [docs/backend-deploy.md](docs/backend-deploy.md)

---

## 账号与登录

- 登录成功后，App 会保存令牌和用户信息，后续请求自动带上 `Authorization: Bearer <token>`
- 令牌有效期 30 天，过期或失效时接口返回 `401`，App 自动退出到登录页
- 除 `/api/health`、`/api/auth/status`、`/api/auth/register`、`/api/auth/login` 外，其余 `/api` 接口都需要登录
- 已登录用户可以在「我的 → 账号管理」中新增、查看、删除其他账号，不能删除当前登录的账号
- 删除账号会一并删除该账号的分类、标签、账单、预算和 AI 对话
- 每个账号的数据完全隔离，账号之间的分类、标签、账单互不可见

---

## API 接口

**Base URL：** `http://127.0.0.1:8000`

**Content-Type：** `application/json`

**在线文档：** http://127.0.0.1:8000/docs

**鉴权：** 需要登录的接口带请求头 `Authorization: Bearer <token>`；缺失或失效返回 `401`。

### 登录并获取令牌

```bash
curl -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"secret1"}'
```

响应：

```json
{
  "token": "xxxxx",
  "user": {
    "id": 1,
    "username": "demo",
    "display_name": "demo",
    "created_at": "2026-10-28T10:00:00"
  }
}
```

后续请求示例：

```bash
TOKEN="<上一步返回的 token>"
curl -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:8000/api/transactions?year=2026&month=10"
```

### 接口一览

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| GET | `/` | 服务信息与文档入口 | 否 |
| GET | `/api/health` | 健康检查 | 否 |
| GET | `/api/auth/status` | 是否已有账号 | 否 |
| POST | `/api/auth/register` | 注册并登录 | 否 |
| POST | `/api/auth/login` | 登录 | 否 |
| POST | `/api/auth/logout` | 退出登录 | 是 |
| GET | `/api/auth/me` | 当前账号信息 | 是 |
| PUT | `/api/auth/me` | 修改昵称 / 密码 | 是 |
| GET | `/api/users` | 账号列表 | 是 |
| POST | `/api/users` | 新增账号 | 是 |
| DELETE | `/api/users/{id}` | 删除账号 | 是 |
| GET | `/api/categories` | 获取分类，可用 `type=income` / `expense` 筛选 | 是 |
| POST | `/api/categories` | 新增分类 | 是 |
| PUT | `/api/categories/{id}` | 修改分类名称、图标、颜色 | 是 |
| DELETE | `/api/categories/{id}` | 删除没有账单的分类 | 是 |
| GET | `/api/tags` | 获取标签，可用 `category_id` 筛选 | 是 |
| POST | `/api/tags` | 为分类新增标签 | 是 |
| PUT | `/api/tags/{id}` | 修改标签名称 | 是 |
| DELETE | `/api/tags/{id}` | 删除标签 | 是 |
| GET | `/api/transactions` | 查询交易列表（月 / 日期范围 / 搜索 / 筛选） | 是 |
| POST | `/api/transactions` | 新增一笔交易 | 是 |
| PUT | `/api/transactions/{id}` | 修改交易 | 是 |
| DELETE | `/api/transactions/{id}` | 删除交易 | 是 |
| GET | `/api/transactions/summary` | 获取某月收支汇总 | 是 |
| GET | `/api/reports/categories` | 分类统计报告（周 / 月 / 年） | 是 |
| GET | `/api/reports/trend` | 收支趋势（周 / 月 / 年） | 是 |
| PUT | `/api/budgets` | 设置 / 清除分类预算 | 是 |
| POST | `/api/imports/preview` | 预览支付宝、微信或银行卡账单 | 是 |
| POST | `/api/imports/commit` | 确认导入预览中选中的账单 | 是 |
| GET | `/api/chat/status` | AI 服务与模型配置状态 | 是 |
| POST | `/api/chat` | AI 对话 | 是 |
| GET | `/api/chat/history` | 获取 AI 对话历史 | 是 |
| DELETE | `/api/chat/history` | 清空 AI 对话历史 | 是 |
| POST | `/api/chat/messages/{id}/applied` | 标记对话中的记账草稿已入账 | 是 |
| GET | `/api/exports/transactions.csv` | 导出全部账单 CSV | 是 |
| GET | `/api/exports/backup.db` | 导出当前账号的数据库备份 | 是 |

---

### 账号 `/api/auth`

**GET `/api/auth/status`** — 返回是否已有账号，用于 App 判断显示注册还是登录引导。

```json
{ "has_users": true }
```

**POST `/api/auth/register`** — 请求体 `username`、`password`，可选 `display_name`。返回同登录响应。

**POST `/api/auth/login`** — 请求体 `username`、`password`。用户名不区分大小写。用户名或密码错误返回 `401`。

**POST `/api/auth/logout`** — 注销当前令牌，返回 `204`。

**GET `/api/auth/me`** — 返回当前账号资料。

**PUT `/api/auth/me`** — 请求体可选 `display_name`、`current_password`、`new_password`；修改密码时必须同时提供当前密码。返回更新后的资料。

### 账号管理 `/api/users`

**GET `/api/users`** — 返回所有账号（`id`、`username`、`display_name`、`created_at`）。

**POST `/api/users`** — 请求体同注册，返回 `201` 和新账号资料（不返回令牌）。

**DELETE `/api/users/{id}`** — 删除指定账号及其全部数据，返回 `204`；不能删除当前登录账号。

---

### 分类 `/api/categories`

分类区分 `income`（收入）和 `expense`（支出）。同一名称可以各有一条。类型在创建时确定，之后不能修改。分类下还有账单时不能删除。

**GET** 可选查询参数 `type=income` 或 `type=expense`。

**POST** 请求体：`name`、`icon`、`color`（`#RRGGBB`）、`type`。

**PUT** `/api/categories/{id}` 请求体：`name`、`icon`、`color`。

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

### 标签 `/api/tags`

标签属于某个分类。同一分类下名称不能重复。删除分类时，它的标签一并删除。标签可以随账单保存，之后可在账单页搜索和查看。

**GET** 可选查询参数 `category_id`。

**POST** 请求体：`category_id`、`name`。

**PUT** `/api/tags/{id}` 请求体：`name`。

**响应示例：**

```json
[
  {
    "id": 1,
    "category_id": 1,
    "name": "午餐",
    "sort_order": 1
  }
]
```

---

### GET `/api/transactions`

查询交易列表，按日期倒序、ID 倒序排列。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| year | int | 二选一 | 年份，如 2026 |
| month | int | 二选一 | 月份，1–12 |
| start | string | 二选一 | 起始日期 `YYYY-MM-DD`，与 `end` 同时提供 |
| end | string | 二选一 | 结束日期 `YYYY-MM-DD`，与 `start` 同时提供 |
| q | string | 否 | 关键词，匹配标题、分类名、标签名，最多 50 字 |
| category_id | int | 否 | 按分类筛选 |
| type | string | 否 | `income` 或 `expense` |
| tag_id | int | 否 | 按标签筛选 |

> `year` + `month` 与 `start` + `end` 二选一：不传日期范围时按整月查询；两者都不完整或 `end < start` 返回 `400`。

**请求示例：**

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:8000/api/transactions?year=2026&month=10&q=午餐"
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
    "date": "2026-10-07",
    "tags": [
      { "id": 2, "category_id": 1, "name": "午餐", "sort_order": 2 }
    ]
  }
]
```

### POST `/api/transactions`

新增一笔交易，成功返回 `201` 和完整的 `TransactionOut`。

**请求 Body：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| title | string | 是 | 标题，1–200 字符 |
| category_id | int | 是 | 分类 ID，类型需与 `type` 一致 |
| amount | float | 是 | 金额，必须 > 0，按「分」存储 |
| type | string | 是 | `income`（收入）或 `expense`（支出） |
| date | string | 否 | 日期，格式 `YYYY-MM-DD`，默认当天 |
| tag_ids | int[] | 否 | 标签 ID，最多 8 个，且必须属于该分类 |

**请求示例：**

```bash
curl -X POST http://127.0.0.1:8000/api/transactions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "午餐",
    "category_id": 1,
    "amount": 35.5,
    "type": "expense",
    "tag_ids": [2]
  }'
```

### PUT `/api/transactions/{id}`

请求体同新增。分类类型不匹配、金额无效返回 `400`，交易不存在返回 `404`。

### DELETE `/api/transactions/{id}`

删除指定交易，返回 `204`；不存在返回 `404`。

---

### GET `/api/transactions/summary`

获取指定年月的收支汇总。

**Query 参数：** `year`、`month`（必填）。

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:8000/api/transactions/summary?year=2026&month=10"
```

**响应示例：**

```json
{
  "year": 2026,
  "month": 10,
  "income": 21700.0,
  "expense": 757.5,
  "total": 20942.5
}
```

> `total = income - expense`

---

### GET `/api/reports/categories`

获取指定周期的分类统计，供「报告」页图表与列表使用。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| period | string | 否 | `week` / `month` / `year`，默认 `month` |
| year | int | 视周期 | 年份；`week` 可省略 |
| month | int | 视周期 | 月份；`year` 周期可省略 |
| anchor | string | 周必填 | 周内任意一天 `YYYY-MM-DD`，用于定位自然周 |

**响应示例：**

```json
{
  "year": 2026,
  "month": 10,
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
      "transaction_count": 2,
      "budget": 500.0
    }
  ],
  "period": "month",
  "start": "2026-10-01",
  "end": "2026-10-31"
}
```

### GET `/api/reports/trend`

获取趋势数据，用于报告页趋势图。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| period | string | 否 | `week` / `month` / `year`，默认 `month` |
| year | int | 视周期 | 年份 |
| month | int | 视周期 | 月份 |
| anchor | string | 周必填 | 周内任意一天 |
| months | int | 否 | `month` 周期取最近几个月，2–12，默认 6 |

**响应示例：**

```json
{
  "points": [
    { "year": 2026, "month": 5, "income": 0.0, "expense": 0.0, "label": "5月", "day": 1 }
  ],
  "income_delta": 1200.0,
  "expense_delta": -35.5
}
```

### PUT `/api/budgets`

设置或清除分类预算，返回 `204`。只有支出分类可以设置预算。

**请求 Body：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| category_id | int | 是 | 支出分类 ID |
| year | int | 是 | 年份 |
| month | int | 否 | 月份，默认 1；`scope=week` 时由 `anchor` 定位 |
| amount | float | 是 | 预算金额，`<= 0` 表示清除该周期预算 |
| scope | string | 否 | `week` / `month` / `year`，默认 `month` |
| anchor | string | 周必填 | 周内任意一天 `YYYY-MM-DD` |

---

### POST `/api/imports/preview`

预览账单文件（multipart/form-data）。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| file | file | 是 | CSV 或 XLSX，最大 8MB |
| source | string | 否 | 指定 `alipay` / `wechat` / `bank`，不传则自动识别 |

规则：

- 支持 UTF-8、UTF-8 BOM、GB18030 编码的 CSV，以及 XLSX
- 自动识别支付宝、微信支付、银行卡账单的表头和来源
- 按分类关键词自动匹配分类，匹配失败时归入该类型的第一个分类
- 失败 / 关闭 / 不计收支的交易会标记为跳过并给出原因
- 按「来源 + 外部单号」识别重复，单次最多 3000 条

```bash
curl -X POST http://127.0.0.1:8000/api/imports/preview \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@alipay.csv"
```

**响应示例：**

```json
{
  "source": "alipay",
  "source_label": "支付宝",
  "total": 3,
  "ready_count": 2,
  "duplicate_count": 0,
  "skipped_count": 1,
  "items": [
    {
      "external_id": "2026102800001",
      "title": "美团外卖",
      "amount": 28.5,
      "type": "expense",
      "date": "2026-10-28",
      "category_id": 1,
      "category_name": "餐饮",
      "matched": true,
      "counterparty": "美团",
      "duplicate": false,
      "skipped": false,
      "skip_reason": ""
    }
  ]
}
```

### POST `/api/imports/commit`

确认导入选中的账单。

**请求 Body：**

```json
{
  "items": [
    {
      "external_id": "2026102800001",
      "title": "美团外卖",
      "amount": 28.5,
      "type": "expense",
      "date": "2026-10-28",
      "category_id": 1,
      "source": "alipay"
    }
  ]
}
```

**响应示例：**

```json
{ "imported": 2, "duplicates": 0 }
```

> 同一账号重复导入相同来源、相同单号的账单会被跳过并计入 `duplicates`。

---

### GET `/api/chat/status`

检查已配置的 AI 服务与可选模型。需要登录。任一服务商配置了密钥时，`configured` 为 `true`。

```json
{
  "configured": true,
  "provider": "deepseek",
  "model": "deepseek-flash",
  "providers": [
    {
      "id": "deepseek",
      "name": "DeepSeek",
      "available": true,
      "configured": true,
      "hint": "",
      "key_env": "DEEPSEEK_API_KEY",
      "models": [
        { "id": "deepseek-flash", "name": "DeepSeek Flash", "description": "回答更快，适合日常记账问答" },
        { "id": "deepseek-v4-pro", "name": "DeepSeek V4 Pro", "description": "分析更细，适合复杂的收支建议" }
      ]
    },
    {
      "id": "kimi",
      "name": "Kimi",
      "available": true,
      "configured": false,
      "hint": "未配置密钥",
      "key_env": "KIMI_API_KEY",
      "models": [
        { "id": "kimi-k2.6", "name": "Kimi K2.6", "description": "回答更快，适合日常记账问答" },
        { "id": "kimi-k3.1-pro", "name": "Kimi K3.1 Pro", "description": "分析更细，适合复杂的收支建议" }
      ]
    }
  ]
}
```

### POST `/api/chat`

AI 对话接口，后端代理转发至对应服务商。

**请求 Body：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| messages | array | 是 | 对话历史，1–30 条，每项含 `role`（user/assistant）和 `content`（1–4000 字） |
| include_context | bool | 否 | 是否带入当月记账数据，默认 `true` |
| year | int | 否 | 上下文年份，默认当前年 |
| month | int | 否 | 上下文月份，默认当前月 |
| provider | string | 否 | `deepseek` / `kimi`，默认 `deepseek` |
| model | string | 否 | 服务商下的模型 ID，默认取 `.env` 或内置默认 |

**请求示例：**

```bash
curl -X POST http://127.0.0.1:8000/api/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "分析我本月支出结构"}
    ],
    "include_context": true,
    "year": 2026,
    "month": 10,
    "provider": "deepseek",
    "model": "deepseek-flash"
  }'
```

**响应示例：**

```json
{
  "reply": "根据你 10 月的记账数据，支出主要集中在餐饮……",
  "provider": "deepseek",
  "model": "deepseek-flash",
  "assistant_message_id": 12,
  "proposal": null
}
```

当用户明确要求记账时，`proposal` 会返回一条待确认草稿，App 确认后才写入账单：

```json
{
  "title": "午餐",
  "amount": 28.0,
  "type": "expense",
  "category_id": 1,
  "category_name": "餐饮",
  "date": "2026-10-28"
}
```

**错误响应：**

| HTTP 状态码 | 说明 |
|-------------|------|
| 400 | 服务商或模型不支持 |
| 401 | 未登录或令牌失效 |
| 503 | 对应服务商的 API Key 未配置 |
| 502 | 服务商连接失败、返回错误或空内容 |

### 对话历史 `/api/chat/history`

**GET** — 返回当前账号最近 200 条对话（正序），每项含 `id`、`role`、`content`、`proposal`、`applied`。

**DELETE** — 清空当前账号的全部对话，返回 `204`。

**POST `/api/chat/messages/{id}/applied`** — 将某条 AI 回复中的记账草稿标记为已入账，返回 `204`。

---

### 导出 `/api/exports`

**GET `/api/exports/transactions.csv`** — 导出当前账号全部账单，列为「日期、类型、分类、标题、金额、标签」，UTF-8 BOM 编码，Excel 可直接打开。

**GET `/api/exports/backup.db`** — 导出当前账号的 SQLite 备份，包含分类、标签、账单、标签关联、预算和 AI 对话，不含账号、密码和登录令牌。

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

**TagOut**

```json
{
  "id": 2,
  "category_id": 1,
  "name": "午餐",
  "sort_order": 2
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
  "date": "2026-10-28",
  "tags": []
}
```

**金额精度：** 后端以整数「分」存储（`amount_cents`），接口返回元为单位的两位小数，汇总时不会出现 `0.1 + 0.2` 的浮点误差。

---

## 功能说明

| 页面 | 功能 | 使用的接口 |
|------|------|-----------|
| 登录 | 注册、登录，未登录时作为入口 | `auth/status` + `auth/register` + `auth/login` |
| 记账 | 当月收支概览、按日分组交易列表、快速记一笔 | `summary` + `transactions` |
| 账单 | 按周 / 月 / 年浏览，搜索标题、分类、标签，按类型 / 分类筛选，编辑、删除 | `transactions` + `categories` + `tags` |
| AI | 选择服务商与模型，带入当月数据对话，支持对话生成记账草稿并确认入账，可清空历史 | `chat/status` + `chat` + `chat/history` |
| 报告 | 周 / 月 / 年统计，收支环形图、分类饼图、柱状图、趋势图，设置分类预算与超支提示 | `reports/categories` + `reports/trend` + `budgets` |
| 我的 | 账号资料与账号管理、主题、API 地址、分类、标签、导入账单、导出 CSV / 备份、AI 模型选择、退出登录 | 各模块接口 + 本地持久化 |

---

## AI 助手配置

AI 对话通过后端代理调用，**API Key 只保存在服务端**，不会暴露给 App。支持 DeepSeek 和 Kimi，可只配置其中一个。

### 1. 获取 API Key

- DeepSeek：登录 [DeepSeek 开放平台](https://platform.deepseek.com/) 创建 API Key
- Kimi：登录 [Moonshot 开放平台](https://platform.moonshot.cn/) 创建 API Key

### 2. 配置 `server/.env`

```bash
cd server
cp .env.example .env
```

编辑 `.env`：

```env
# DeepSeek
DEEPSEEK_API_KEY=sk-你的密钥
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-flash

# Kimi
KIMI_API_KEY=
KIMI_BASE_URL=https://api.moonshot.cn/v1
KIMI_MODEL=kimi-k2.6

# 数据库路径，服务器上建议改成持久化目录
# DATABASE_PATH=/var/lib/account/account.db
```

| 变量 | 作用 |
|------|------|
| `DEEPSEEK_API_KEY` | DeepSeek 密钥，留空则 DeepSeek 显示未配置 |
| `DEEPSEEK_BASE_URL` | 默认 `https://api.deepseek.com` |
| `DEEPSEEK_MODEL` | 默认模型：`deepseek-flash` 或 `deepseek-v4-pro` |
| `KIMI_API_KEY` | Kimi 密钥，也认 `MOONSHOT_API_KEY` |
| `KIMI_BASE_URL` | 默认 `https://api.moonshot.cn/v1` |
| `KIMI_MODEL` | 默认模型：`kimi-k2.6` 或 `kimi-k3.1-pro` |
| `DATABASE_PATH` | SQLite 文件路径，默认 `server/account.db` |

`KIMI_API_KEY` 留空时，Kimi 在 App 中显示「未配置密钥」，DeepSeek 仍可正常使用。

### 3. 重启后端并验证

```bash
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

登录后请求状态接口：

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://127.0.0.1:8000/api/chat/status
# 至少一个服务 configured 为 true
```

### 4. 在 App 中使用

底部导航 **AI** 标签，或 **我的 → AI 记账助手**。

- 默认带入当月记账数据作为上下文（右上角图标可开关）
- 在 **我的 → AI 助手** 中切换 DeepSeek / Kimi 以及具体模型，选择本地保存
- 支持快捷提问，如「分析我本月支出结构」「有哪些地方可以省钱？」
- 对话里让 AI 记账时，会生成一条草稿，确认后才真正写入账单
- 对话历史保存在服务端，退出 App 后再次进入仍可查看

---

## 数据库

项目使用单个 SQLite 文件，服务启动时会自动建表和迁移旧库，不需要额外安装数据库服务。

### 表结构

| 表 | 作用 |
|------|------|
| `users` | 账号（用户名、密码哈希、昵称、创建时间） |
| `sessions` | 登录令牌与过期时间（30 天） |
| `categories` | 分类，按账号区分 |
| `transactions` | 账单，金额同时保存 `amount` 与整数 `amount_cents` |
| `tags` | 分类下的标签 |
| `transaction_tags` | 账单与标签的关联 |
| `budgets` | 周 / 月 / 年分类预算 |
| `chat_messages` | AI 对话历史与记账草稿 |

密码使用 `PBKDF2-SHA256`（20 万次迭代）加盐哈希存储，不保存明文。

### 脚本

脚本在 `server/sql/`：

| 文件 | 作用 | 何时执行 |
|------|------|----------|
| `schema.sql` | 建表和索引 | 每次 `init_db`，以及后端启动时 |
| `seed_categories.sql` | 8 个默认分类（工资为收入，其余为支出） | 同上，按名称和类型去重 |
| `seed_tags.sql` | 默认分类的常用标签 | 仅当标签表为空 |
| `migrate_category_type.sql` | 给旧库的分类补上收支类型 | 仅当 `categories` 还没有 `type` 列 |
| `seed_demo.sql` | 2026 年 8 月示例账单 | 仅 `python3 init_db.py --demo`，且交易表为空 |

`database.py` 在启动时还会自动处理这些旧库迁移：账号字段、导入单号、会话过期时间、金额「分」、周 / 月 / 年预算。迁移可重复执行，不会清空已有账单。

### 初始化

```bash
cd server
cp .env.example .env
# 在 .env 中按需设置 DATABASE_PATH

python3 init_db.py          # 服务器：只建空库和默认分类
python3 init_db.py --demo   # 本地：额外写入示例账单
```

未设置 `DATABASE_PATH` 时，数据库文件是 `server/account.db`。后端启动也会执行同样的建表和默认分类逻辑，已有交易不会被覆盖或清空。

本地一键启动 `scripts/start_dev.sh` 会执行 `init_db.py --demo`。交易表里已经有数据时，示例账单不会再次写入。

**重置：** 停掉后端，删除数据库文件（默认 `server/account.db`，或 `.env` 里的 `DATABASE_PATH`），再执行 `python3 init_db.py`。需要示例数据时加上 `--demo`。SQLite 使用 WAL 模式，删除时一并删除 `-wal` 和 `-shm` 文件。

### 备份与恢复

服务运行时直接拷贝 `.db` 会漏掉 WAL 中尚未合并的写入，使用 SQLite 自带的备份命令：

```bash
sqlite3 server/account.db ".backup 'account.db.bak'"
```

恢复时先停掉后端，用备份文件替换原文件，再启动。

App 里的「下载数据库备份」只包含当前账号的账本，不含账号和密码；服务器整库备份以上面的命令为准。完整部署步骤见 [docs/backend-deploy.md](docs/backend-deploy.md)。

### 测试

```bash
cd server
python3 test_ledger.py
```

覆盖金额「分」精度、汇总、令牌过期、周 / 月 / 年预算独立性，以及旧库迁移保留数据。

---

## 常见问题

**浏览器报 `ERR_CONNECTION_REFUSED`**

后端未启动。执行：

```bash
lsof -i :8000
curl http://127.0.0.1:8000/api/health
```

无响应则重新启动 uvicorn。

**接口返回 401**

- 未登录或令牌已过期（30 天）
- 请求未带 `Authorization: Bearer <token>`
- 令牌对应的账号已被删除

在 App 中重新登录即可；命令行请先调用 `/api/auth/login` 获取新令牌。

**App 显示加载失败**

1. 确认后端已启动（8000 端口）
2. 确认访问的是 App 地址（8080），不是 API 地址（8000）
3. 在「我的 → API 配置」检查 API 地址是否正确
4. 真机调试时使用局域网 IP

**macOS 构建失败**

提示找不到 `xcodebuild` 时，改用 Web 模式：

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

**后端进程意外退出（exit 143）**

通常是终端关闭或被手动 kill，重新执行启动命令即可。

**AI 提示 API Key 未配置（503）**

1. 确认 `server/.env` 中已填写对应服务商的 `*_API_KEY`
2. 重启后端（修改 `.env` 后必须重启）
3. 登录后请求 `GET /api/chat/status`，确认目标服务 `configured` 为 `true`
4. 在「我的 → AI 助手」确认选中的服务商已配置

**AI 回复失败（502）**

通常是服务商余额不足、Key 无效或网络问题。登录对应平台检查余额与 Key 状态；服务器还需能访问 `api.deepseek.com` 或 `api.moonshot.cn`。

**导入账单失败**

- 只支持支付宝、微信、银行卡导出的 CSV / XLSX，文件不能超过 8MB
- 表头需包含日期列和金额列，缺少时返回「没有找到账单表头」
- 单次最多 3000 条；重复单号会被跳过
- 若来源识别错误，可在导入页手动指定来源
