# 小程序上线前检查清单

适用场景：Flutter 客户端用 uni-app 重写为微信小程序，后端复用现有 FastAPI + SQLite。
标记说明：✅ 项目里已有 · ⚠️ 需要改造 · ❌ 当前缺失

---

## 1. 主体与资质

- [ ] 注册小程序账号，确定主体（个人 / 企业）
- [ ] 完成小程序认证（部分能力要求非个人主体）
- [ ] 填写名称、头像、简介、服务类目（记账工具建议选「工具 / 效率」或平台当前的记账相关类目，不要选金融理财，避免资质要求）
- [ ] **完成小程序备案**（工信部要求，通过微信公众平台提交，主体需与小程序一致；未备案不能发布）
- [ ] 准备《用户协议》和《隐私政策》，放到小程序内可访问的页面
- [ ] 个人主体确认能力限制：不支持 web-view、微信支付、手机号快速验证

> 小程序备案和域名 ICP 备案是两件事，都要做。

---

## 2. 服务器与域名

- [ ] 购买**境内**云服务器（1 核 2G 起步即可，SQLite 单进程足够）
- [ ] 系统时区设为 `Asia/Shanghai`（报表按周/月/年统计依赖服务器时区）
- [ ] 注册域名并完成 **ICP 备案**（接入商与服务器一致，备案期间 80/443 不可访问，建议提前启动）
- [ ] DNS 添加 `api.你的域名.com` 的 A 记录指向服务器
- [ ] 配置 HTTPS 证书（Let's Encrypt 或云厂商免费证书），TLS 1.2+
- [ ] 配置证书自动续期并验证（`certbot renew --dry-run`）
- [ ] 防火墙只放行 443 和 SSH；8000 只监听 `127.0.0.1`，不暴露公网
- [ ] 数据库放持久化目录（`/var/lib/account/account.db`），不要放代码目录
- [ ] 配置数据盘快照或每日整库备份（`sqlite3 .backup`，不要直接 cp）
- [ ] 配置日志轮转（journald 或 logrotate），避免磁盘写满

---

## 3. 后端改造（FastAPI）

### 3.1 登录与账号

- [ ] ❌ 新增 `POST /api/auth/wx-login`：接收 `wx.login` 的 `code`，服务端调 `jscode2session` 换 `openid`，查/建用户后签发现有 Bearer token
- [ ] AppSecret 只放服务器 `.env`，绝不能进小程序代码
- [ ] 用户表增加 `wx_openid` 唯一索引（可空，兼容原有账号密码登录）
- [ ] 处理 `wx.checkSession` 失效：token 仍以自有 30 天有效期为准
- [x] ✅ 已新增 `DELETE /api/auth/me` 注销当前账号，并清理全部关联数据；小程序端仍需提供注销入口与二次确认

### 3.2 注册与安全

- [x] ✅ 已支持 `REGISTER_ENABLED` 开关与 `REGISTER_INVITE_CODE` 邀请码；上线时需实际配置（默认仍为开放注册）
- [ ] 登录接口加失败次数限制，防密码爆破
- [ ] ⚠️ CORS 当前 `allow_origins=["*"]`（[main.py](../server/main.py#L46-L48)），生产环境收敛为实际 H5 域名
- [ ] 生产环境关闭或限制 `/docs`、`/openapi.json`
- [ ] `.env` 权限 600，密钥不进仓库
- [ ] 上传接口校验文件大小与类型（Nginx `client_max_body_size` + 后端校验）

### 3.3 导入导出

- [x] ✅ 已新增 `GET /api/exports/transactions.xlsx`，小程序端配合 `wx.downloadFile` + `wx.openDocument` 使用
- [ ] 账单导入保持「上传文件 → 后端解析」，前端改为 `wx.chooseMessageFile`，后端 `bill_import.py` 不用改
- [ ] 导入文件大小限制、解析失败提示、重复单号去重保持现有逻辑

### 3.4 运行配置

- [ ] `DATABASE_PATH` 指向持久化目录
- [ ] 单进程 uvicorn，**禁止 `--workers`**（SQLite 并发写约束）
- [ ] `proxy_read_timeout 120s`（账单上传与 AI 调用）
- [ ] 执行 `init_db.py`，确认数据库文件属主与 WAL 读写权限
- [ ] AI 密钥按需配置；首版前端隐藏 AI 入口

---

## 4. 服务部署

按 [backend-deploy.md](./backend-deploy.md) 执行，逐项确认：

- [ ] 创建 `account` 运行用户与 `/opt/account`、`/var/lib/account` 目录
- [ ] 虚拟环境 + 依赖安装 + `.env` 配置
- [ ] `init_db.py` 初始化成功
- [ ] systemd 服务 `account-api` 开机自启，`systemctl status` 为 active
- [ ] Nginx 反向代理 + HTTPS 正常，`curl https://api.域名/api/health` 返回 `{"status":"ok"}`
- [ ] 进程异常自动重启（`Restart=on-failure`）
- [ ] 备份脚本 + 定时任务，并做过一次**恢复演练**
- [ ] 服务器时间与 `Asia/Shanghai` 一致（`timedatectl`）

---

## 5. 小程序后台配置

- [ ] 开发管理 → 服务器域名：配置 `request`、`uploadFile`、`downloadFile` 三类合法域名
  - 必须是 HTTPS、443 端口、已备案域名
  - 不能是 IP、不能带端口号、不能是 localhost
  - 域名尽量一次定稿，修改次数有限
- [ ] 业务域名：仅 web-view 需要；个人主体不支持 web-view，本项目建议不配置
- [ ] 设置 → 服务内容声明 → **用户隐私保护指引**：声明收集的信息（微信 openid、账单数据、导入文件），与实际一致
- [ ] 配置隐私政策链接和用户协议入口
- [ ] 添加项目成员 / 体验成员
- [ ] 上传体验版，用真机确认核心流程
- [ ] 版本管理 → 提交审核（审核期间服务必须一直在线）

---

## 6. 小程序代码侧

- [ ] API 地址固定为 `https://api.你的域名.com`，移除「用户自填服务器地址」（对应 [api_config.dart](../lib/config/api_config.dart)）
- [ ] 请求封装改用 `uni.request`，统一带 `Authorization: Bearer <token>`
- [ ] token 用 `uni.setStorageSync` 持久化；401 时清 token 并跳登录页（对应 [api_client.dart](../lib/api/api_client.dart#L141-L154)）
- [ ] 登录页改为微信一键登录，保留账号密码作为备选
- [ ] 图表由 `fl_chart` 换成 uCharts / echarts-for-weixin（对应 [report_charts.dart](../lib/widgets/report_charts.dart)）
- [ ] 账单导入用 `wx.chooseMessageFile`（只能从聊天记录/收藏选文件），补充选择失败与空文件提示
- [ ] 导出用 `wx.downloadFile` + `wx.openDocument`
- [ ] 首版隐藏 AI 对话入口（对应 [ai_chat_page.dart](../lib/pages/ai_chat_page.dart)），后端接口保留
- [ ] 「我的」页提供账号注销入口，二次确认并说明后果
- [ ] 首次启动接入微信隐私授权弹窗
- [ ] 请求超时、弱网提示、loading 状态齐全
- [ ] 页面路径、导航栏、底部 tab 在 `pages.json` 配置完整
- [ ] 包体积检查（主包 2MB 以内）

---

## 7. 提审前自测

用体验版在 iOS / Android 真机各走一遍：

- [ ] 首次打开 → 隐私授权 → 微信登录 → 自动创建账号
- [ ] 记一笔收入、一笔支出，账单列表能看到
- [ ] 编辑、删除账单
- [ ] 周/月/年报表切换，图表数据正确
- [ ] 新增/删除分类、标签，预算设置
- [ ] 导入账单文件（微信聊天记录里的 CSV/XLSX）
- [ ] 导出账单并用 `openDocument` 打开
- [ ] 物品新增/修改/出售，对应账单同步生成
- [ ] 账号注销后无法再登录，数据确实被删除
- [ ] 服务端断网/超时时有可读错误提示，不白屏
- [ ] 后台杀掉小程序再打开，登录态仍在

---

## 8. 审核材料

- [ ] 审核说明：说明微信登录会自动创建账号，无需提供密码
- [ ] 如涉及特殊类目，准备对应资质
- [ ] 隐私政策、用户协议可正常打开
- [ ] 服务类目与实际功能一致（不要出现未声明的金融、AI 功能）
- [ ] 审核期间服务器、HTTPS、数据库保持可用

---

## 9. 上线后运维

- [ ] 每日备份 + 每周验证备份可恢复
- [ ] 健康检查与告警（`/api/health`，可用云监控或外部拨测）
- [ ] 日志查看与错误告警（`journalctl -u account-api`）
- [ ] 证书到期监控
- [ ] 注册/登录异常监控，防批量注册与撞库
- [ ] 数据库体积与慢查询观察；日活上升或写入冲突增多时按 [mysql-migration.md](./mysql-migration.md) 迁 MySQL
- [ ] 发布流程：备份 → 更新代码 → 装依赖 → 重启 → 健康检查

---

## 10. 风险清单

| 风险 | 影响 | 应对 |
|---|---|---|
| 小程序备案未完成 | 无法发布 | 提前在微信公众平台提交 |
| 域名未备案或用 IP | 域名无法配置、审核驳回 | 先完成 ICP 备案再联调正式环境 |
| 服务在审核期间不可用 | 审核驳回 | 审核期保持服务在线，提前压测 |
| 注册接口完全开放 | 垃圾账号、数据污染 | 邀请码、验证码或关闭公开注册 |
| 个人主体限制 | 无法用 web-view、支付、手机号验证 | 首版只用微信登录 + 自有页面 |
| AI 功能未备案 | 审核驳回 | 首版隐藏 AI；后续企业主体 + 算法备案 + 内容安全检测 |
| 注销入口缺失或假删除 | 审核驳回、合规风险 | 新增注销自己接口，真实删除全部关联数据 |
| SQLite 单点 | 服务中断、数据丢失 | 定时备份 + 快照；规模上来迁 MySQL |
| 服务器时区错误 | 周/月/年报表边界错 | 服务器时区统一 `Asia/Shanghai` |
