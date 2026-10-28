# 后台部署

记账后台是 FastAPI 进程加一个 SQLite 文件，没有单独的数据库服务。进程启动时会自己建表、补旧库字段，并写入缺失的默认分类。服务器上不要写入示例账单。

本文假设一台 Linux 服务器，代码放在 `/opt/account`，数据库放在 `/var/lib/account/account.db`，对外只开放 HTTPS。

## 环境

| 项目 | 要求 |
|------|------|
| 系统 | Linux。下面的 systemd、nginx 示例按常见发行版来写 |
| Python | 3.9 及以上，需要 `python3` 和 `python3-venv` |
| 网络 | 记账本身不访问外网。要用 AI 时，服务器需要能访问 `api.deepseek.com` 或 `api.moonshot.cn` |
| 端口 | 进程监听 `127.0.0.1:8000`，由本机 Nginx 反代。不要把 8000 直接暴露到公网 |

iPhone 正式包只允许明文访问本地网络。手机连远程后台时请用 HTTPS。Android 当前允许明文 HTTP，仍建议统一走 HTTPS。

## 1. 准备目录和运行用户

```bash
sudo useradd --system --create-home --home-dir /opt/account --shell /usr/sbin/nologin account
sudo mkdir -p /var/lib/account
sudo chown account:account /var/lib/account
```

SQLite 使用 WAL，运行用户必须能在数据库所在目录里创建 `account.db-wal` 和 `account.db-shm`。只给 `.db` 文件写权限不够。

把仓库放到 `/opt/account`，并让 `account` 用户能读代码、写虚拟环境：

```bash
sudo chown -R account:account /opt/account
```

## 2. 安装依赖

```bash
sudo -u account -H bash -lc '
  cd /opt/account/server
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
  cp -n .env.example .env
'
sudo chmod 600 /opt/account/server/.env
```

`.env` 已被 git 忽略。不要把真实密钥提交进仓库。

编辑 `/opt/account/server/.env`：

```env
DATABASE_PATH=/var/lib/account/account.db

DEEPSEEK_API_KEY=sk-你的DeepSeek密钥
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-flash

KIMI_API_KEY=
KIMI_BASE_URL=https://api.moonshot.cn/v1
KIMI_MODEL=kimi-k2.6
```

| 变量 | 作用 |
|------|------|
| `DATABASE_PATH` | SQLite 文件路径。不设置时用 `server/account.db`，进程重装或目录被清掉时会把账本一起带走 |
| `DEEPSEEK_API_KEY` | DeepSeek 密钥。留空则 App 里 DeepSeek 显示未配置 |
| `DEEPSEEK_BASE_URL` | 默认 `https://api.deepseek.com` |
| `DEEPSEEK_MODEL` | 默认模型，可用 `deepseek-flash` 或 `deepseek-v4-pro` |
| `KIMI_API_KEY` | Kimi 密钥。也认 `MOONSHOT_API_KEY` |
| `KIMI_BASE_URL` | 默认 `https://api.moonshot.cn/v1` |
| `KIMI_MODEL` | 默认模型，可用 `kimi-k2.6` 或 `kimi-k3.1-pro` |

改完 `.env` 需要重启进程。程序从 `server/.env` 读取，不会覆盖系统里已经存在的同名环境变量。

## 3. 初始化数据库

```bash
sudo -u account -H bash -lc '
  cd /opt/account/server
  .venv/bin/python init_db.py
'
```

成功时打印 `数据库已就绪: /var/lib/account/account.db`。

这一步会做这些事，并且可以重复执行，不会清空已有账单：

1. 执行 `sql/schema.sql`，创建用户、会话、分类、账单、标签、预算、对话等表。
2. 若是旧库，补充分类收支类型、导入单号、账号字段、会话过期时间、金额「分」、周/月/年预算。
3. 执行 `sql/seed_categories.sql`，按名称和收支类型补上 8 个默认分类。
4. 标签表为空时执行 `sql/seed_tags.sql`。
5. 打开 WAL。

不要加 `--demo`。`--demo` 只给本地开发用，会在交易表为空时写入示例账单。

后端每次启动也会再跑一遍同样的 `init_db()`。手动先跑一次，是为了在对外提供服务前确认数据库路径和权限。

第一个账号在 App 里注册即可。注册成功后，库里那些还没归属账号的默认分类和账单会划给这个账号；之后新建的账号各自有一套默认分类和标签。

## 4. 用 systemd 常驻

先手动确认能起来：

```bash
sudo -u account -H bash -lc '
  cd /opt/account/server
  .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000
'
```

另开一个终端：

```bash
curl -sS http://127.0.0.1:8000/api/health
# {"status":"ok"}

curl -sS http://127.0.0.1:8000/api/auth/status
# 还没有账号时：{"has_users":false}
```

确认后停掉手动进程，再交给 systemd。SQLite 同时只适合一个写进程，不要加 `--workers`。

`/etc/systemd/system/account-api.service`：

```ini
[Unit]
Description=Account API
After=network.target

[Service]
User=account
Group=account
WorkingDirectory=/opt/account/server
EnvironmentFile=/opt/account/server/.env
ExecStart=/opt/account/server/.venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now account-api
sudo systemctl status account-api
journalctl -u account-api -f
```

日志里出现 `Application startup complete` 即表示就绪。

## 5. 用 Nginx 提供 HTTPS

下面把 `https://account.example.com` 转到本机 8000。证书路径按你实际使用的证书修改；用 Let's Encrypt 时，发行版的 certbot 插件通常会替你写入这段配置。

```nginx
server {
    listen 443 ssl;
    server_name account.example.com;

    ssl_certificate     /etc/ssl/certs/account.example.com.fullchain.pem;
    ssl_certificate_key /etc/ssl/private/account.example.com.key;

    client_max_body_size 20m;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }
}
```

`client_max_body_size` 留给支付宝、微信、银行卡账单上传。`proxy_read_timeout` 留给 AI 回复。

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -sS https://account.example.com/api/health
```

防火墙只放行 443（以及你用来登录服务器的 SSH 端口）。8000 保持仅本机访问。

## 6. 让 App 指向这台服务器

地址不要带末尾斜杠，例如 `https://account.example.com`。

| 方式 | 做法 |
|------|------|
| 已安装的 App | 设置页填写 API 地址并保存 |
| 打包时写死 | `flutter build apk --dart-define=API_BASE_URL=https://account.example.com`，iOS / macOS 同理 |

打开 App 后注册第一个账号。用户名 2–20 位，密码 6–64 位。登录令牌 30 天后失效。

AI 不是启动所必需的。配了密钥后，登录状态下访问 `GET /api/chat/status`，`configured` 应为 `true`。

## 升级

```bash
sudo systemctl stop account-api
sudo -u account -H bash -lc '
  cd /opt/account
  git pull
  server/.venv/bin/pip install -r server/requirements.txt
'
sudo systemctl start account-api
curl -sS http://127.0.0.1:8000/api/health
```

启动时会自动补表结构。升级前先做一次下面的备份。

## 备份与恢复

账本就是这一个库文件。服务运行时直接拷贝 `account.db` 会漏掉 WAL 里还没合并的写入，用 SQLite 自己的备份命令：

```bash
sudo -u account sqlite3 /var/lib/account/account.db ".backup '/var/lib/account/account.db.bak'"
```

恢复时先停服务，用备份文件替换原文件，再启动：

```bash
sudo systemctl stop account-api
sudo -u account cp /var/lib/account/account.db.bak /var/lib/account/account.db
sudo systemctl start account-api
```

App 里的「备份」导出的是当前账号的账本，不是服务器上的整库。整库以 `/var/lib/account/account.db` 这份备份为准。

要清空重来时，停掉服务，删掉 `account.db`、`account.db-wal`、`account.db-shm`，再执行 `init_db.py` 并启动。这一步会丢掉全部账号和账单。

## 上线时要注意

- `POST /api/auth/register` 不需要登录。任何能访问这个地址的人都可以注册。已登录用户还可以在 App 里添加、删除其他账号。这是给自己或家里用的服务，不适合对整个互联网开放注册。公网部署时，用防火墙、VPN，或在 Nginx 上限制来源。
- 接口当前允许任意来源的浏览器跨域访问。手机 App 不受这条规定影响。
- 交互式文档在 `/docs`。若不想对外看到，在 Nginx 里拒绝这个路径。
- 同一份数据库不要同时跑两个后端进程。

## 检查

| 检查 | 命令 | 期望 |
|------|------|------|
| 进程 | `systemctl status account-api` | active (running) |
| 健康 | `curl -sS http://127.0.0.1:8000/api/health` | `{"status":"ok"}` |
| 是否已有账号 | `curl -sS http://127.0.0.1:8000/api/auth/status` | `has_users` 为 true 或 false |
| 外网入口 | `curl -sS https://account.example.com/api/health` | `{"status":"ok"}` |
| 数据库文件 | `ls -l /var/lib/account` | `account.db` 属主是 `account` |
| AI | 登录后请求 `/api/chat/status` | 配了密钥时 `configured` 为 true |
