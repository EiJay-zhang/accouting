# 微信小程序上线清单

适用场景：`miniapp/`（uni-app + Vue 3）作为微信小程序客户端，复用 `server/`（FastAPI + SQLite）后端，Flutter 客户端保留。

更新日期：2026-11-18

## 当前进度

| 项目                                               | 状态                        |
| ------------------------------------------------ | ------------------------- |
| 功能迁移（批次 1–6）                                     | ✅ 完成                      |
| `npm run type-check` / `npm run build:mp-weixin` | ✅ 通过                      |
| H5 浏览器与后端接口冒烟                                    | ✅ 通过                      |
| 主包体积                                             | ✅ 0.69MB（微信限制 2MB）        |
| 真机回归                                             | ⬜ 待做，需要真实 AppID + 微信开发者工具 |
| 小程序注册、认证、备案                                      | ⬜ 待做                      |
| 域名 ICP 备案、服务器、HTTPS                              | ⬜ 待做                      |
| 提审与发布                                            | ⬜ 待做                      |

**结论**：代码已具备上线条件，剩余工作集中在平台资质、生产配置、真机验收和审核发布。

你需要准备的关键材料：小程序 AppID、AppSecret、已备案的 HTTPS 域名、境内服务器、可用的用户反馈渠道（邮箱或客服）。

***

## 0. 上线路线

按顺序执行，备案周期最长，建议最先启动：

1. 注册小程序、确定主体、启动小程序备案
2. 准备域名、服务器、完成 ICP 备案与 HTTPS
3. 部署后端，配置微信登录与注册策略
4. 替换小程序 AppID 和生产 API 地址
5. 构建并上传体验版，完成真机回归
6. 配置服务器域名、用户隐私保护指引、体验成员
7. 提交审核、发布
8. 上线后备份、监控与告警

***

## 1. 账号、主体与备案

- [ ] 在 [微信公众平台](https://mp.weixin.qq.com) 注册小程序账号，确定主体（个人 / 企业）
- [ ] 完成主体认证（部分能力要求非个人主体）
- [ ] 填写名称、头像（可用 [app-icon.png](../miniapp/src/static/app-icon.png)）、简介
- [ ] 选择服务类目：建议「工具 / 效率」，**不要选金融理财类**，避免额外资质和审核风险
- [ ] **完成小程序备案**：在微信公众平台提交，主体需与小程序一致，未备案不能发布
- [ ] 确认个人主体限制：不支持 web-view、微信支付、手机号快速验证；本项目不依赖这些能力
- [ ] 准备《用户协议》《隐私政策》的正式文案（页面已内置：[privacy/index.vue](../miniapp/src/pages/privacy/index.vue)）
- [ ] 补一个真实可用的反馈渠道（邮箱或小程序客服），隐私政策里写到「反馈渠道」，审核时可能核对

> 小程序备案和域名 ICP 备案是两件事，都要做，且主体信息要保持一致。

***

## 2. 域名与服务器

- [ ] 购买境内云服务器（1 核 2G 起步，SQLite 单进程足够）
- [ ] 服务器时区设为 `Asia/Shanghai`（周 / 月 / 年报表依赖服务器时区）
- [ ] 注册域名，完成 **ICP 备案**（接入商与服务器一致；备案期间 80/443 不可访问）
- [ ] DNS 添加 `api.你的域名.com` 的 A 记录指向服务器
- [ ] 配置 HTTPS 证书（Let's Encrypt 或云厂商免费证书），TLS 1.2+
- [ ] 配置证书自动续期并验证（`certbot renew --dry-run`）
- [ ] 防火墙只放行 443 和 SSH；8000 只监听 `127.0.0.1`
- [ ] 数据库放在持久化目录 `/var/lib/account/account.db`，不要放代码目录
- [ ] 配置每日整库备份（`sqlite3 .backup`，不要直接 `cp`）
- [ ] 配置日志轮转（journald 或 logrotate）

***

## 3. 后端生产配置

部署步骤按 [backend-deploy.md](./backend-deploy.md) 执行，这里只列上线新增项。

### 3.1 必填环境变量

编辑 `/opt/account/server/.env`：

```env
DATABASE_PATH=/var/lib/account/account.db

# 微信登录，两项都填后小程序才显示「微信一键登录」
WX_APPID=wx你的AppID
WX_SECRET=你的AppSecret

# 注册控制：公网环境建议至少启用其中一项
REGISTER_ENABLED=false
REGISTER_INVITE_CODE=你的邀请码
```

- [ ] `WX_SECRET` 只放服务器 `.env`，绝不写入小程序代码或仓库
- [ ] 服务器可访问 `https://api.weixin.qq.com`（微信登录换 openid 需要）
- [ ] 改完 `.env` 重启 `account-api`
- [ ] 登录后确认 `/api/auth/status` 返回 `wechat_login_configured: true`

### 3.2 建议在提审前完成的加固

当前代码仍有以下默认行为，公网开放前建议处理：

- [ ] **CORS 收敛**：目前 `allow_origins=["*"]`（[main.py](../server/main.py#L50-L56)）。小程序请求不受 CORS 影响；若不部署 H5，可改为只允许实际 H5 域名或直接移除该中间件
- [ ] **限制 `/docs` 与 `/openapi.json`**：可在 Nginx 里拒绝这两个路径，避免接口文档公开
- [ ] **登录失败限流**：当前未实现。公开注册时建议在 Nginx 层加 `limit_req`，或先关闭公开注册
- [ ] **上传大小限制**：Nginx 已配 `client_max_body_size 20m`；后端尚无显式文件大小校验，可接受 20MB 上限或补校验
- [ ] 关闭公开注册后，确认首个账号已提前注册（首个账号始终允许注册）

### 3.3 部署验收

```bash
curl -sS https://api.你的域名.com/api/health
# {"status":"ok"}

curl -sS https://api.你的域名.com/api/auth/status
```

- [ ] `has_users` 符合预期
- [ ] `registration_open` 与注册策略一致
- [ ] `wechat_login_configured` 为 `true`
- [ ] `systemctl status account-api` 为 active，日志出现 `Application startup complete`

***

## 4. 小程序生产配置

### 4.1 代码配置

- [ ] 把 [manifest.json](../miniapp/src/manifest.json) 的 `mp-weixin.appid` 从 `wx0000000000000000` 改成真实 AppID
- [ ] 把 [.env.production](../miniapp/.env.production) 改成生产地址：
  ```env
  VITE_API_BASE_URL=https://api.你的域名.com
  ```
- [ ] 域名配置完成后，把 `mp-weixin.setting.urlCheck` 改为 `true`，让开发者工具校验合法域名
- [ ] 重新构建：`npm run type-check && npm run build:mp-weixin`
- [ ] 确认 `dist/build/mp-weixin/project.config.json` 里的 `appid` 已更新

### 4.2 微信公众平台配置

- [ ] 开发管理 → 开发设置 → 服务器域名，配置三类合法域名：
  | 类型                | 用途      | 值                      |
  | ----------------- | ------- | ---------------------- |
  | request 合法域名      | 所有接口    | `https://api.你的域名.com` |
  | uploadFile 合法域名   | 导入账单    | `https://api.你的域名.com` |
  | downloadFile 合法域名 | 导出 XLSX | `https://api.你的域名.com` |
  要求：HTTPS、443 端口、域名已备案；不能是 IP、不能带端口号、不能是 localhost。
- [ ] 业务域名：本项目无 web-view，不需要配置
- [ ] 设置 → 服务内容声明 → **用户隐私保护指引**：声明微信 openid（登录识别）、账单 / 物品数据、主动上传的导入文件
- [ ] 管理 → 成员管理：添加体验成员
- [ ] 基本信息：上传小程序头像、确认名称与简介

> 代码只使用 `wx.login`，未调用位置、相册、剪贴板等敏感隐私接口；隐私弹窗以平台《用户隐私保护指引》为准，登录页已有协议勾选。

***

## 5. 构建与上传体验版

```bash
cd miniapp
npm run type-check
npm run build:mp-weixin
```

- [ ] 微信开发者工具「导入项目」，目录选 `miniapp/dist/build/mp-weixin`
- [ ] 确认 AppID、项目名称、域名校验设置正确
- [ ] 模拟器走一遍登录与核心页面
- [ ] 点击「上传」，填写版本号（与 `manifest.json` 的 `1.0.0` 一致）和备注
- [ ] 在公众平台「版本管理」把该版本设为体验版
- [ ] 用体验成员微信扫码，执行第 7 节真机回归

***

## 6. 审核材料

- [ ] 审核说明写清楚：微信一键登录会自动创建账号，无需密码；未配置微信登录时可用账号密码
- [ ] 服务类目与实际功能一致，不出现未声明的金融、理财、AI 能力
- [ ] 《用户协议》《隐私政策》可在小程序内正常打开
- [ ] 「我的」页有真实的账号注销入口（已实现，二次确认 + 真实删除）
- [ ] 审核期间服务器、HTTPS、数据库保持在线
- [ ] 准备好测试账号（若审核员需要账号密码登录）

***

## 7. 提审前自测

### 7.1 已完成（桌面 / 接口）

- [x] 账号密码注册、登录、退出
- [x] 首页月度汇总、账单分组、切月
- [x] 新增 / 编辑 / 删除账单
- [x] 账单周 / 月 / 年浏览、搜索、分类 / 标签 / 类型筛选
- [x] 报告图表、预算设置、分类跳账单
- [x] 物品列表、汇总、筛选、新增 / 编辑 / 出售 / 删除及账单联动
- [x] 分类、标签、多账号管理
- [x] 注销账号并清空数据
- [x] CSV / XLSX 导入：预览、补分类、提交、重复识别
- [x] XLSX 导出并确认文件可解析
- [x] 主包 0.69MB

### 7.2 待真机回归

用体验版在 iOS / Android 各走一遍：

- [ ] 首次打开 → 隐私协议勾选 → 微信一键登录 → 自动创建账号
- [ ] 未配置微信登录时，账号密码登录可用
- [ ] 记一笔收入、一笔支出，首页与账单页同步
- [ ] 编辑、删除账单
- [ ] 周 / 月 / 年报表切换，图表渲染清晰、数据正确
- [ ] 新增 / 删除分类、标签，预算设置
- [ ] 从微信聊天选择 CSV / XLSX 导入，改分类后提交
- [ ] 导出 XLSX，`openDocument` 能打开并转发
- [ ] 物品新增 / 修改 / 出售，收入账单自动生成；状态回退后账单删除
- [ ] 账号注销后无法再登录，数据被清空
- [ ] 弱网 / 超时有可读提示，不白屏
- [ ] 后台杀掉小程序再打开，登录态仍在
- [ ] 真机主包体积与上传版本一致

***

## 8. 发布与上线后运维

- [ ] 版本管理 → 提交审核；通过后发布（可选分阶段发布）
- [ ] 每日备份 + 每周验证备份可恢复
- [ ] `/api/health` 外部拨测与告警
- [ ] `journalctl -u account-api` 日志巡检
- [ ] HTTPS 证书到期监控
- [ ] 注册 / 登录异常监控，防批量注册与撞库
- [ ] 数据库体积与写入冲突观察；规模上来后按 [mysql-migration.md](./mysql-migration.md) 迁移
- [ ] 发布流程固定为：备份 → 更新代码 → 装依赖 → 重启 → 健康检查

***

## 9. 代码侧已完成项（归档）

| 能力                               | 位置                                                                                                            |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 微信登录接口 `POST /api/auth/wx-login` | [main.py](../server/main.py#L557-L559)、[auth.py](../server/auth.py#L241-L260)                                 |
| `users.wx_openid` 迁移与唯一索引        | [database.py](../server/database.py#L316-L322)                                                                |
| 注销当前账号                           | `DELETE /api/auth/me`                                                                                         |
| 账单导入预览 / 提交                      | [import.ts](../miniapp/src/api/import.ts)、[bill-import/index.vue](../miniapp/src/pages/bill-import/index.vue) |
| XLSX 导出                          | [export.ts](../miniapp/src/api/export.ts)、[settings/index.vue](../miniapp/src/pages/settings/index.vue)       |
| 用户协议与隐私政策                        | [privacy/index.vue](../miniapp/src/pages/privacy/index.vue)                                                   |
| 小程序运行说明                          | [README.md](../README.md)                                                                                     |

***

## 10. 风险清单

| 风险         | 影响              | 应对                            |
| ---------- | --------------- | ----------------------------- |
| 小程序备案未完成   | 无法发布            | 最先启动，预留审核时间                   |
| 域名未备案或用 IP | 无法配置合法域名、审核驳回   | 先完成 ICP 备案再联调正式环境             |
| 审核期间服务不可用  | 审核驳回            | 审核期保持服务在线                     |
| 注册接口完全开放   | 垃圾账号、数据污染       | `REGISTER_ENABLED=false` 或邀请码 |
| 登录无限流      | 密码爆破            | Nginx `limit_req` 或关闭公开注册     |
| 个人主体限制     | 无法用 web-view、支付 | 首版不依赖这些能力                     |
| AI 功能未备案   | 审核驳回            | 首版已隐藏 AI，不入驻审核版本              |
| 注销入口缺失或假删除 | 审核驳回、合规风险       | 已实现真实删除并二次确认                  |
| SQLite 单点  | 服务中断、数据丢失       | 每日备份 + 快照；规模上来迁 MySQL         |
| 服务器时区错误    | 周 / 月 / 年边界错    | 统一 `Asia/Shanghai`            |

***

## 附：最小上线路径

如果只想尽快上线、不做额外加固：

1. 个人主体注册 + 小程序备案
2. 一台已备案域名 + HTTPS 的服务器
3. 配好 `WX_APPID` / `WX_SECRET`，关闭公开注册
4. 替换 AppID 与 `VITE_API_BASE_URL`，构建上传
5. 配三类合法域名 + 隐私保护指引
6. 真机走第 7.2 节清单，提审发布

CORS、`/docs`、登录限流可以放到上线后的第一轮迭代。
