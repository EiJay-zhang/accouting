# MySQL 迁移改造方案

> 适用项目：当前 `server/` 下的 FastAPI + SQLite 实现。
> 目标：保留现有 REST API 协议，把持久层从 SQLite 迁移到 MySQL 8.0，同时让本地开发与单元测试继续使用 SQLite。

## 1. 设计结论

| 项目 | 方案 |
|------|------|
| ORM | SQLAlchemy 2.0（声明式模型） |
| 迁移工具 | Alembic |
| MySQL 驱动 | PyMySQL |
| 双后端 | `DATABASE_URL` 决定 SQLite / MySQL |
| 金额 | 继续以整数「分」为准，`amount_cents BIGINT`；`amount DECIMAL(12,2)` 仅用于展示兼容 |
| 日期 | MySQL 用 `DATE`，接口仍输出 `YYYY-MM-DD` 字符串 |
| 删除策略 | 账号删除继续由应用层显式按顺序删除，账本表外键使用 `RESTRICT`，避免多级级联顺序问题 |
| 字符集 | `utf8mb4`，支持中文分类名与 emoji 图标 |

改造后建议保留两套运行方式：

```text
本地开发 / 单元测试   →  sqlite:///server/account.db
预发 / 生产           →  mysql+pymysql://user:pass@host:3306/account?charset=utf8mb4
```

客户端不需要改，API 路径、请求体、响应结构保持不变。

---

## 2. 依赖与配置

### 2.1 新增 Python 依赖

编辑 `server/requirements.txt`：

```text
fastapi==0.115.6
uvicorn[standard]==0.34.0
httpx==0.28.1
python-dotenv==1.0.1
python-multipart==0.0.20
openpyxl==3.1.5
SQLAlchemy==2.0.36
alembic==1.14.0
PyMySQL==1.1.1
cryptography==44.0.0
```

`cryptography` 用于 MySQL 8 的 `caching_sha2_password` 认证。

### 2.2 环境变量

`server/.env`：

```env
# 生产：MySQL
DATABASE_URL=mysql+pymysql://account:密码@127.0.0.1:3306/account?charset=utf8mb4

# 本地：不设置 DATABASE_URL 时沿用 SQLite
# DATABASE_PATH=server/account.db

# 连接池
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20
DB_POOL_RECYCLE=3600
```

规则：

1. 设置 `DATABASE_URL` 时优先使用它。
2. 未设置时读取 `DATABASE_PATH`，拼成 `sqlite:///...`。
3. `scripts/start_dev.sh` 不设置 `DATABASE_URL`，继续跑 SQLite。

---

## 3. MySQL 表结构

以下 DDL 可直接用于 MySQL 8.0.16+（`CHECK` 约束在此版本起生效）。

```sql
CREATE DATABASE IF NOT EXISTS account
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE account;

-- 账号
CREATE TABLE users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  username      VARCHAR(20)  NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  display_name  VARCHAR(20)  NOT NULL,
  created_at    DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 登录会话
CREATE TABLE sessions (
  token      VARCHAR(64) NOT NULL,
  user_id    BIGINT      NOT NULL,
  created_at DATETIME    NOT NULL,
  expires_at DATETIME    NULL,
  PRIMARY KEY (token),
  KEY idx_sessions_user_id (user_id),
  CONSTRAINT fk_sessions_user
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 分类。user_id 允许为空，用于首次注册前尚未归属账号的默认分类
CREATE TABLE categories (
  id      BIGINT      NOT NULL AUTO_INCREMENT,
  user_id BIGINT      NULL,
  name    VARCHAR(20) NOT NULL,
  icon    VARCHAR(16) NOT NULL,
  color   CHAR(7)     NOT NULL,
  type    VARCHAR(7)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_categories_user_name_type (user_id, name, type),
  CONSTRAINT chk_categories_type
    CHECK (type IN ('income', 'expense')),
  CONSTRAINT fk_categories_user
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 账单
CREATE TABLE transactions (
  id           BIGINT       NOT NULL AUTO_INCREMENT,
  user_id      BIGINT       NULL,
  title        VARCHAR(200) NOT NULL,
  category_id  BIGINT       NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  amount_cents BIGINT       NOT NULL,
  type         VARCHAR(7)   NOT NULL,
  `date`       DATE         NOT NULL,
  source       VARCHAR(16)  NULL,
  external_id  VARCHAR(80)  NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_transactions_import (user_id, source, external_id),
  KEY idx_transactions_user_date (user_id, `date`),
  KEY idx_transactions_user_category (user_id, category_id),
  KEY idx_transactions_user_type (user_id, type),
  CONSTRAINT chk_transactions_amount
    CHECK (amount > 0),
  CONSTRAINT chk_transactions_cents
    CHECK (amount_cents > 0),
  CONSTRAINT chk_transactions_type
    CHECK (type IN ('income', 'expense')),
  CONSTRAINT fk_transactions_category
    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
  CONSTRAINT fk_transactions_user
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 标签
CREATE TABLE tags (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  category_id BIGINT      NOT NULL,
  name        VARCHAR(20) NOT NULL,
  sort_order  INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_tags_category_name (category_id, name),
  CONSTRAINT fk_tags_category
    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 账单与标签关联
CREATE TABLE transaction_tags (
  transaction_id BIGINT NOT NULL,
  tag_id         BIGINT NOT NULL,
  PRIMARY KEY (transaction_id, tag_id),
  KEY idx_transaction_tags_tag (tag_id),
  CONSTRAINT fk_tt_transaction
    FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
  CONSTRAINT fk_tt_tag
    FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 预算。week 用 YYYY-MM-DD，month 用 YYYY-MM，year 用 YYYY
CREATE TABLE budgets (
  category_id  BIGINT      NOT NULL,
  scope        VARCHAR(5)  NOT NULL,
  period_key   VARCHAR(10) NOT NULL,
  amount_cents BIGINT      NOT NULL,
  PRIMARY KEY (category_id, scope, period_key),
  CONSTRAINT chk_budgets_scope
    CHECK (scope IN ('week', 'month', 'year')),
  CONSTRAINT chk_budgets_cents
    CHECK (amount_cents > 0),
  CONSTRAINT fk_budgets_category
    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- AI 对话
CREATE TABLE chat_messages (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  user_id    BIGINT      NULL,
  role       VARCHAR(9)  NOT NULL,
  content    TEXT        NOT NULL,
  proposal   TEXT        NULL,
  applied    TINYINT(1)  NOT NULL DEFAULT 0,
  created_at DATETIME    NOT NULL,
  PRIMARY KEY (id),
  KEY idx_chat_messages_user_id (user_id),
  CONSTRAINT chk_chat_role
    CHECK (role IN ('user', 'assistant')),
  CONSTRAINT chk_chat_applied
    CHECK (applied IN (0, 1)),
  CONSTRAINT fk_chat_user
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### 3.1 几个关键取舍

1. **`users.username` 大小写不敏感**
   - 表使用 `utf8mb4_0900_ai_ci`，与当前 `COLLATE NOCASE` 行为接近。
   - 如果使用 MySQL 5.7，改为 `utf8mb4_unicode_ci`。

2. **`transactions.date` 使用 `DATE`**
   - 当前 SQLite 存的是 `TEXT`，并用 `LIKE 'YYYY-MM%'` 查询。
   - 迁移后改用 `date >= 月初 AND date <= 月末`，查询更可靠，也不依赖字符串前缀。

3. **导入去重**
   - `UNIQUE (user_id, source, external_id)` 已足够。
   - MySQL 唯一索引把 `NULL` 视为不同值，所以未归属账号、未导入来源的记录不会互相冲突。
   - SQLite 的部分唯一索引在 MySQL 中不再需要。

4. **账号删除**
   - `sessions`、`chat_messages` 随账号级联删除。
   - `categories`、`transactions` 使用 `RESTRICT`，由 `delete_account()` 显式按顺序删除：
     `sessions → chat_messages → transaction_tags → budgets → transactions → tags → categories → users`。
   - 避免 MySQL 在多个级联路径上出现删除顺序冲突。

---

## 4. SQLAlchemy 模型

新建 `server/models.py`。模型同时兼容 SQLite 与 MySQL，关键点是主键类型：

> SQLite 只有 `INTEGER PRIMARY KEY` 才能自增，直接使用 `BIGINT` 会导致本地库主键不自增。因此用 `BigInteger().with_variant(Integer, "sqlite")`。

```python
from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


# MySQL 用 BIGINT，SQLite 用 INTEGER，保证自增主键在两端都正常
IDType = BigInteger().with_variant(Integer, "sqlite")


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("username", name="uk_users_username"),
    )

    id: Mapped[int] = mapped_column(IDType, primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(20), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str] = mapped_column(String(20), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class AuthSession(Base):
    __tablename__ = "sessions"
    __table_args__ = (
        Index("idx_sessions_user_id", "user_id"),
    )

    token: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(
        IDType,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class Category(Base):
    __tablename__ = "categories"
    __table_args__ = (
        UniqueConstraint("user_id", "name", "type", name="uk_categories_user_name_type"),
        CheckConstraint("type IN ('income', 'expense')", name="chk_categories_type"),
    )

    id: Mapped[int] = mapped_column(IDType, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[int]] = mapped_column(
        IDType,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=True,
    )
    name: Mapped[str] = mapped_column(String(20), nullable=False)
    icon: Mapped[str] = mapped_column(String(16), nullable=False)
    color: Mapped[str] = mapped_column(String(7), nullable=False)
    type: Mapped[str] = mapped_column(String(7), nullable=False)


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "source", "external_id",
            name="uk_transactions_import",
        ),
        Index("idx_transactions_user_date", "user_id", "date"),
        Index("idx_transactions_user_category", "user_id", "category_id"),
        Index("idx_transactions_user_type", "user_id", "type"),
        CheckConstraint("amount > 0", name="chk_transactions_amount"),
        CheckConstraint("amount_cents > 0", name="chk_transactions_cents"),
        CheckConstraint("type IN ('income', 'expense')", name="chk_transactions_type"),
    )

    id: Mapped[int] = mapped_column(IDType, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[int]] = mapped_column(
        IDType,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    category_id: Mapped[int] = mapped_column(
        IDType,
        ForeignKey("categories.id", ondelete="RESTRICT"),
        nullable=False,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    amount_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)
    type: Mapped[str] = mapped_column(String(7), nullable=False)
    date: Mapped[date] = mapped_column("date", Date, nullable=False)
    source: Mapped[Optional[str]] = mapped_column(String(16), nullable=True)
    external_id: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)


class Tag(Base):
    __tablename__ = "tags"
    __table_args__ = (
        UniqueConstraint("category_id", "name", name="uk_tags_category_name"),
    )

    id: Mapped[int] = mapped_column(IDType, primary_key=True, autoincrement=True)
    category_id: Mapped[int] = mapped_column(
        IDType,
        ForeignKey("categories.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(20), nullable=False)
    sort_order: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0"),
    )


class TransactionTag(Base):
    __tablename__ = "transaction_tags"
    __table_args__ = (
        Index("idx_transaction_tags_tag", "tag_id"),
    )

    transaction_id: Mapped[int] = mapped_column(
        IDType,
        ForeignKey("transactions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    tag_id: Mapped[int] = mapped_column(
        IDType,
        ForeignKey("tags.id", ondelete="CASCADE"),
        primary_key=True,
    )


class Budget(Base):
    __tablename__ = "budgets"
    __table_args__ = (
        CheckConstraint("scope IN ('week', 'month', 'year')", name="chk_budgets_scope"),
        CheckConstraint("amount_cents > 0", name="chk_budgets_cents"),
    )

    category_id: Mapped[int] = mapped_column(
        IDType,
        ForeignKey("categories.id", ondelete="CASCADE"),
        primary_key=True,
    )
    scope: Mapped[str] = mapped_column(String(5), primary_key=True)
    period_key: Mapped[str] = mapped_column(String(10), primary_key=True)
    amount_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    __table_args__ = (
        Index("idx_chat_messages_user_id", "user_id"),
        CheckConstraint("role IN ('user', 'assistant')", name="chk_chat_role"),
        CheckConstraint("applied IN (0, 1)", name="chk_chat_applied"),
    )

    id: Mapped[int] = mapped_column(IDType, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[int]] = mapped_column(
        IDType,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
    )
    role: Mapped[str] = mapped_column(String(9), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    proposal: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    applied: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=text("0"),
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
```

### 4.1 使用约定

- 不在模型上挂大量 `relationship(lazy="select")`，避免迁移后出现隐式懒加载和 N+1 查询；列表/报表用显式 `join`。
- `amount` 从 MySQL 读出后是 `Decimal`，接口层统一 `float(amount)` 输出。
- `date` 读出后是 `datetime.date`，接口层 `.isoformat()` 输出。
- SQLite 测试库可用 `Base.metadata.create_all(engine)`；MySQL 生产库只用 Alembic，不用 `create_all`。

---

## 5. 连接层与 Alembic

### 5.1 `server/db.py`

```python
import os

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker


def _database_url() -> str:
    url = os.getenv("DATABASE_URL", "").strip()
    if url:
        return url
    path = os.getenv("DATABASE_PATH", "server/account.db")
    return f"sqlite:///{path}"


DATABASE_URL = _database_url()

_engine_kwargs = {
    "pool_pre_ping": True,
    "future": True,
}

# SQLite 不适合连接池参数；MySQL 使用连接池
if not DATABASE_URL.startswith("sqlite"):
    _engine_kwargs.update(
        pool_size=int(os.getenv("DB_POOL_SIZE", "10")),
        max_overflow=int(os.getenv("DB_MAX_OVERFLOW", "20")),
        pool_recycle=int(os.getenv("DB_POOL_RECYCLE", "3600")),
    )

engine = create_engine(DATABASE_URL, **_engine_kwargs)

if DATABASE_URL.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def _sqlite_pragma(dbapi_connection, _connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA busy_timeout=5000")
        cursor.close()

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    expire_on_commit=False,
    future=True,
)


def get_session():
    with SessionLocal() as session:
        yield session
```

### 5.2 Alembic 初始化

```bash
cd server
python3 -m pip install -r requirements.txt
alembic init alembic
```

修改 `server/alembic/env.py` 的关键部分：

```python
import os
import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import Base  # noqa: E402

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

url = os.getenv("DATABASE_URL", "").strip()
if url:
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))

target_metadata = Base.metadata
```

`server/alembic.ini` 保留默认的 `script_location = alembic` 即可。

### 5.3 生成初始迁移

> **注意：** 初始迁移必须在 MySQL 连接下生成，或在 SQLite 下生成后手动把 `INTEGER` 改成 `BIGINT`。否则 `with_variant` 会把主键渲染成 SQLite 的 `INTEGER`，应用到 MySQL 后主键就不是 `BIGINT`。

```bash
cd server
export DATABASE_URL='mysql+pymysql://account:密码@127.0.0.1:3306/account?charset=utf8mb4'

alembic revision --autogenerate -m "init mysql schema"
# 检查 alembic/versions/ 下生成的文件：
# 1. 主键是 BIGINT
# 2. CHECK 约束、索引、唯一约束齐全
# 3. 字符串长度、DECIMAL(12,2) 正确
alembic upgrade head
```

如果自动生成的结果不理想，直接用第 3 节的 DDL 写成第一个 revision 的 `upgrade()`，`downgrade()` 按反向顺序 `DROP TABLE`。

---

## 6. SQLite 专有 SQL 改写对照

| SQLite 写法 | MySQL / SQLAlchemy 写法 |
|-------------|-------------------------|
| `conn.execute("... ?", (...))` | `session.execute(select(...))` |
| `cursor.lastrowid` | `session.flush()` 后取 `obj.id` |
| `INSERT ... ON CONFLICT DO UPDATE` | 先 `session.get()` 再更新/插入；或 MySQL 方言 `on_duplicate_key_update` |
| `PRAGMA journal_mode=WAL` | 删除，改为 MySQL 服务端配置 |
| `PRAGMA foreign_keys=ON` | InnoDB 默认启用外键 |
| `PRAGMA busy_timeout` | 删除，改用连接池与超时 |
| `COLLATE NOCASE` | 列/表使用 `utf8mb4_0900_ai_ci` |
| 部分唯一索引 `WHERE ...` | 普通联合唯一索引，利用 MySQL 多 NULL 特性 |
| `date LIKE '2026-10%'` | `date >= '2026-10-01' AND date <= '2026-10-31'` |
| `substr(t.date, 1, 10)` | 直接使用 `DATE` 列 |
| `strftime('%Y-%m', date)` | Python 计算 `period_key`，或 `DATE_FORMAT(date, '%Y-%m')` |
| `printf('%04d-%02d', year, month)` | Python f-string 生成 `YYYY-MM` |
| `CAST(ROUND(amount * 100) AS INTEGER)` | Python `int(round(amount * 100))` / `Decimal` 量化 |
| `LIKE ? ESCAPE '\'` | `column.contains(q, autoescape=True)` |
| `sqlite3.Row["field"]` | ORM 属性 `obj.field` |
| `executescript()` | 删除；DDL 交给 Alembic |
| `CURRENT_TIMESTAMP` 文本 | `datetime.now()` 或 `func.now()` |
| `applied` 存 0/1 | `Boolean` 映射 `TINYINT(1)`，Python 用 `bool` |

### 6.1 查询改写示例

**登录查询**

```python
# 旧
row = conn.execute(
    "SELECT * FROM users WHERE username = ? COLLATE NOCASE",
    (username,),
).fetchone()

# 新（MySQL 列排序规则本身大小写不敏感）
user = session.scalar(select(User).where(User.username == username))
```

**账单列表**

```python
stmt = (
    select(Transaction, Category)
    .join(Category, Transaction.category_id == Category.id)
    .where(Transaction.user_id == user_id)
    .where(Transaction.date >= start)
    .where(Transaction.date <= end)
    .order_by(Transaction.date.desc(), Transaction.id.desc())
)

if q:
    stmt = stmt.where(
        or_(
            Transaction.title.contains(q, autoescape=True),
            Category.name.contains(q, autoescape=True),
        )
    )
if category_id:
    stmt = stmt.where(Transaction.category_id == category_id)
if tx_type:
    stmt = stmt.where(Transaction.type == tx_type)
```

**月度汇总**

```python
rows = session.execute(
    select(Transaction.type, func.coalesce(func.sum(Transaction.amount_cents), 0))
    .where(Transaction.user_id == user_id)
    .where(Transaction.date >= start)
    .where(Transaction.date <= end)
    .group_by(Transaction.type)
).all()

income_cents = sum(cents for t, cents in rows if t == "income")
expense_cents = sum(cents for t, cents in rows if t == "expense")
```

**分类报告**

```python
stmt = (
    select(
        Category,
        func.coalesce(func.sum(Transaction.amount_cents), 0).label("total_cents"),
        func.count(Transaction.id).label("tx_count"),
    )
    .join(Transaction, Transaction.category_id == Category.id)
    .where(Category.user_id == user_id)
    .where(Transaction.date >= start)
    .where(Transaction.date <= end)
    .group_by(Category.id)
)
```

**预算 upsert（保持双后端可移植）**

```python
budget = session.get(
    Budget,
    {"category_id": category_id, "scope": scope, "period_key": period_key},
)
if budget is None:
    session.add(Budget(
        category_id=category_id,
        scope=scope,
        period_key=period_key,
        amount_cents=amount_cents,
    ))
else:
    budget.amount_cents = amount_cents
```

并发极高时再换成 MySQL 方言的 `INSERT ... ON DUPLICATE KEY UPDATE`，并用唯一约束兜底。

**账号删除**

```python
# 顺序必须与外键策略一致
session.execute(delete(AuthSession).where(AuthSession.user_id == user_id))
session.execute(delete(ChatMessage).where(ChatMessage.user_id == user_id))
session.execute(
    delete(TransactionTag).where(
        TransactionTag.transaction_id.in_(
            select(Transaction.id).where(Transaction.user_id == user_id)
        )
    )
)
session.execute(
    delete(Budget).where(
        Budget.category_id.in_(
            select(Category.id).where(Category.user_id == user_id)
        )
    )
)
session.execute(delete(Transaction).where(Transaction.user_id == user_id))
session.execute(delete(Tag).where(
    Tag.category_id.in_(select(Category.id).where(Category.user_id == user_id))
))
session.execute(delete(Category).where(Category.user_id == user_id))
session.execute(delete(User).where(User.id == user_id))
```

---

## 7. SQLite → MySQL 数据迁移脚本

新建 `server/scripts/migrate_sqlite_to_mysql.py`。脚本只读 SQLite，写入 MySQL，并在写入后做数量和金额校验。

```python
#!/usr/bin/env python3
"""把 SQLite 账本数据迁移到 MySQL。

用法：
    python3 scripts/migrate_sqlite_to_mysql.py \
        --sqlite account.db \
        --mysql-url 'mysql+pymysql://account:密码@127.0.0.1:3306/account?charset=utf8mb4' \
        --truncate

安全策略：
    - SQLite 以只读模式打开
    - 必须显式提供 mysql:// 连接串，不会默认使用 DATABASE_URL
    - 目标库非空时必须加 --truncate
"""

import argparse
import os
import sqlite3
import sys
from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

from sqlalchemy import create_engine, delete, func, insert, select
from sqlalchemy.orm import Session

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import (  # noqa: E402
    AuthSession,
    Budget,
    Category,
    ChatMessage,
    Tag,
    Transaction,
    TransactionTag,
    User,
)

# 插入顺序：父表在前
INSERT_ORDER = [
    ("users", User),
    ("sessions", AuthSession),
    ("categories", Category),
    ("transactions", Transaction),
    ("tags", Tag),
    ("transaction_tags", TransactionTag),
    ("budgets", Budget),
    ("chat_messages", ChatMessage),
]

# 清空顺序：子表在前
DELETE_ORDER = [
    ChatMessage,
    Budget,
    TransactionTag,
    Tag,
    Transaction,
    Category,
    AuthSession,
    User,
]


def parse_dt(raw) -> datetime | None:
    if raw is None or raw == "":
        return None
    if isinstance(raw, datetime):
        return raw.replace(tzinfo=None)
    return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(tzinfo=None)


def parse_date(raw) -> date:
    if isinstance(raw, datetime):
        return raw.date()
    if isinstance(raw, date):
        return raw
    return date.fromisoformat(str(raw)[:10])


def parse_amount(raw) -> Decimal:
    return Decimal(str(raw)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def fetch_rows(conn: sqlite3.Connection, table: str) -> list[dict]:
    try:
        cur = conn.execute(f"SELECT * FROM {table}")
    except sqlite3.OperationalError:
        return []
    return [dict(row) for row in cur.fetchall()]


def load_source(db_path: str) -> dict[str, list[dict]]:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        raw = {name: fetch_rows(conn, name) for name, _ in INSERT_ORDER}
    finally:
        conn.close()

    users = [
        {
            "id": int(r["id"]),
            "username": r["username"],
            "password_hash": r["password_hash"],
            "display_name": r.get("display_name") or r["username"],
            "created_at": parse_dt(r.get("created_at")) or datetime.now(),
        }
        for r in raw["users"]
    ]

    sessions = [
        {
            "token": r["token"],
            "user_id": int(r["user_id"]),
            "created_at": parse_dt(r.get("created_at")) or datetime.now(),
            "expires_at": parse_dt(r.get("expires_at")),
        }
        for r in raw["sessions"]
    ]

    categories = [
        {
            "id": int(r["id"]),
            "user_id": int(r["user_id"]) if r.get("user_id") is not None else None,
            "name": r["name"],
            "icon": r["icon"],
            "color": r["color"],
            "type": r["type"],
        }
        for r in raw["categories"]
    ]

    transactions = []
    for r in raw["transactions"]:
        amount = parse_amount(r["amount"])
        amount_cents = (
            int(r["amount_cents"])
            if r.get("amount_cents") is not None
            else int(amount * 100)
        )
        transactions.append(
            {
                "id": int(r["id"]),
                "user_id": int(r["user_id"]) if r.get("user_id") is not None else None,
                "title": r["title"],
                "category_id": int(r["category_id"]),
                "amount": amount,
                "amount_cents": amount_cents,
                "type": r["type"],
                "date": parse_date(r["date"]),
                "source": r.get("source"),
                "external_id": r.get("external_id"),
            }
        )

    tags = [
        {
            "id": int(r["id"]),
            "category_id": int(r["category_id"]),
            "name": r["name"],
            "sort_order": int(r.get("sort_order") or 0),
        }
        for r in raw["tags"]
    ]

    transaction_tags = [
        {
            "transaction_id": int(r["transaction_id"]),
            "tag_id": int(r["tag_id"]),
        }
        for r in raw["transaction_tags"]
    ]

    budgets = [
        {
            "category_id": int(r["category_id"]),
            "scope": r["scope"],
            "period_key": r["period_key"],
            "amount_cents": int(r["amount_cents"]),
        }
        for r in raw["budgets"]
    ]

    chat_messages = [
        {
            "id": int(r["id"]),
            "user_id": int(r["user_id"]) if r.get("user_id") is not None else None,
            "role": r["role"],
            "content": r["content"],
            "proposal": r.get("proposal"),
            "applied": bool(int(r.get("applied") or 0)),
            "created_at": parse_dt(r.get("created_at")) or datetime.now(),
        }
        for r in raw["chat_messages"]
    ]

    return {
        "users": users,
        "sessions": sessions,
        "categories": categories,
        "transactions": transactions,
        "tags": tags,
        "transaction_tags": transaction_tags,
        "budgets": budgets,
        "chat_messages": chat_messages,
    }


def check_duplicates(payload: dict[str, list[dict]]) -> list[tuple]:
    seen = {}
    for tx in payload["transactions"]:
        if tx["external_id"] is None or tx["source"] is None:
            continue
        key = (tx["user_id"], tx["source"], tx["external_id"])
        seen[key] = seen.get(key, 0) + 1
    return [key for key, count in seen.items() if count > 1]


def validate_target(session: Session, payload: dict[str, list[dict]]) -> None:
    problems = []

    for name, model in INSERT_ORDER:
        source_count = len(payload[name])
        target_count = session.scalar(select(func.count()).select_from(model))
        if source_count != target_count:
            problems.append(f"{name}: 源 {source_count} 条，目标 {target_count} 条")

    source_cents = sum(tx["amount_cents"] for tx in payload["transactions"])
    target_cents = session.scalar(
        select(func.coalesce(func.sum(Transaction.amount_cents), 0))
    )
    if source_cents != target_cents:
        problems.append(f"金额合计不一致：源 {source_cents} 分，目标 {target_cents} 分")

    orphan_category = session.scalar(
        select(func.count()).select_from(Transaction).where(
            ~Transaction.category_id.in_(select(Category.id))
        )
    )
    if orphan_category:
        problems.append(f"有 {orphan_category} 条账单的分类不存在")

    orphan_user = session.scalar(
        select(func.count()).select_from(Transaction).where(
            Transaction.user_id.isnot(None),
            ~Transaction.user_id.in_(select(User.id)),
        )
    )
    if orphan_user:
        problems.append(f"有 {orphan_user} 条账单的账号不存在")

    if problems:
        raise SystemExit("迁移校验失败：\n- " + "\n- ".join(problems))

    print("迁移校验通过：表数量、金额合计、外键归属均一致。")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sqlite", default="account.db")
    parser.add_argument("--mysql-url", default=os.getenv("MYSQL_URL", ""))
    parser.add_argument("--truncate", action="store_true", help="清空目标表后写入")
    parser.add_argument("--dry-run", action="store_true", help="只读取和统计，不写 MySQL")
    parser.add_argument("--batch", type=int, default=500)
    args = parser.parse_args()

    if not Path(args.sqlite).exists():
        raise SystemExit(f"SQLite 文件不存在：{args.sqlite}")

    payload = load_source(args.sqlite)
    print("源数据统计：")
    for name, _ in INSERT_ORDER:
        print(f"  {name:18s} {len(payload[name])}")

    duplicates = check_duplicates(payload)
    if duplicates:
        raise SystemExit(
            "源库存在重复导入键，先清理再迁移：\n"
            + "\n".join(map(str, duplicates[:20]))
        )

    if args.dry_run:
        print("dry-run 完成，未写入 MySQL。")
        return

    if not args.mysql_url.startswith("mysql"):
        raise SystemExit("必须提供 --mysql-url 或 MYSQL_URL，且协议为 mysql+pymysql://")

    engine = create_engine(args.mysql_url, pool_pre_ping=True, future=True)
    with Session(engine) as session:
        with session.begin():
            target_counts = {
                name: session.scalar(select(func.count()).select_from(model))
                for name, model in INSERT_ORDER
            }
            if any(target_counts.values()) and not args.truncate:
                raise SystemExit(
                    "目标库非空。确认要覆盖请加 --truncate：\n" + str(target_counts)
                )

            if args.truncate:
                for model in DELETE_ORDER:
                    session.execute(delete(model))

            for name, model in INSERT_ORDER:
                rows = payload[name]
                for start in range(0, len(rows), args.batch):
                    session.execute(insert(model), rows[start:start + args.batch])
                print(f"写入 {name}: {len(rows)} 条")

            session.flush()
            validate_target(session, payload)

    print("迁移完成。建议立即执行一次 readonly 抽查和 mysqldump 备份。")


if __name__ == "__main__":
    main()
```

### 7.1 迁移前检查

```bash
cd server

# 0. 目标库先执行 Alembic 建表，不要用脚本建表
export DATABASE_URL='mysql+pymysql://account:密码@127.0.0.1:3306/account?charset=utf8mb4'
alembic upgrade head

# 1. 备份 SQLite（服务运行中也安全）
sqlite3 account.db ".backup 'account.db.bak'"

# 2. 先干跑，确认源数据统计
python3 scripts/migrate_sqlite_to_mysql.py \
  --sqlite account.db \
  --dry-run

# 3. 正式迁移
python3 scripts/migrate_sqlite_to_mysql.py \
  --sqlite account.db \
  --mysql-url 'mysql+pymysql://account:密码@127.0.0.1:3306/account?charset=utf8mb4' \
  --truncate

# 4. 抽查
mysql -u account -p account -e "
SELECT COUNT(*) AS users FROM users;
SELECT COUNT(*) AS tx, SUM(amount_cents) AS cents FROM transactions;
SELECT user_id, COUNT(*) FROM transactions GROUP BY user_id;
"
```

### 7.2 迁移后必须核对

| 核对项 | 方法 |
|--------|------|
| 用户数 | `SELECT COUNT(*) FROM users` 与源库一致 |
| 账单数 | `SELECT COUNT(*) FROM transactions` 一致 |
| 金额合计 | `SUM(amount_cents)` 一致 |
| 账号归属 | 不存在 `user_id` 指向已删除用户的账单 |
| 分类归属 | 不存在 `category_id` 指向已删除分类的账单 |
| 导入去重 | `(user_id, source, external_id)` 无重复 |
| 标签关联 | `transaction_tags` 数量一致 |
| 预算 | 周/月/年 `period_key` 与原来一致 |
| 对话 | `chat_messages` 数量、`applied` 状态一致 |

---

## 8. 代码改造清单

| 文件 | 改造内容 |
|------|----------|
| `server/requirements.txt` | 增加 SQLAlchemy、Alembic、PyMySQL、cryptography |
| `server/models.py` | 新增，第 4 节模型 |
| `server/db.py` | 新增，Engine、SessionLocal、`get_session` |
| `server/database.py` | 删除手写连接、`PRAGMA`、建表与旧库迁移逻辑；保留 `init_db` 的兼容入口或删除 |
| `server/auth.py` | 改用 `Session`；注册、登录、会话校验、账号列表、账号删除全部改为 ORM |
| `server/main.py` | 所有 `get_connection()` 调用改为依赖注入 `session`；分类、标签、账单、汇总、报告、预算、导入、对话、导出逐段改写 |
| `server/bill_import.py` | 解析逻辑不变；提交导入时用 ORM 批量写入，并捕获唯一键冲突 |
| `server/init_db.py` | 本地 SQLite 初始化保留；MySQL 初始化改为 `alembic upgrade head` + 默认分类 seed |
| `server/test_ledger.py` | 测试前设置 `DATABASE_URL=sqlite:///临时文件`，用 `Base.metadata.create_all()` 建表 |
| `scripts/start_dev.sh` | 不变，继续使用 SQLite |
| `docs/backend-deploy.md` | 部署步骤增加 MySQL 创建、Alembic 升级、备份与连接数配置 |
| `server/scripts/migrate_sqlite_to_mysql.py` | 新增，第 7 节脚本 |

### 8.1 推荐改造顺序

1. **冻结 SQLite 结构**
   - 先备份 `account.db`，确认当前所有旧库迁移已经执行完。
   - 记录当前表数量、账单数量、金额合计，作为迁移基线。

2. **引入模型与连接层**
   - 新建 `models.py`、`db.py`。
   - 用 SQLite 跑 `Base.metadata.create_all()`，确认模型能建出与现有表兼容的结构。
   - 此时旧代码仍可运行，不切流量。

3. **先改认证模块**
   - `auth.py` 的注册、登录、`require_user`、账号列表、账号删除。
   - 改完跑登录、过期令牌、多账号隔离测试。

4. **再改交易与报表**
   - 按页面顺序：分类/标签 → 账单列表/增删改 → 汇总 → 报告 → 预算 → 导入 → 对话历史 → 导出。
   - 每改完一个模块，就用 SQLite 跑一遍现有接口，避免一次性大爆炸式改动。

5. **补 Alembic**
   - 在 MySQL 连接下生成初始迁移并执行。
   - 以后所有表结构变更都走 `alembic revision`，不再在启动时手写 `ALTER TABLE`。

6. **数据迁移与切换**
   - 按第 7 节迁移。
   - 切换 `DATABASE_URL`，重启服务，做冒烟测试。

7. **保留回滚窗口**
   - 旧 SQLite 文件和旧版本代码至少保留 7–30 天。

### 8.2 导出备份接口的处理

当前 `/api/exports/backup.db` 会生成一个临时 SQLite 文件。迁移后有两种做法：

| 方案 | 说明 |
|------|------|
| 保留 SQLite 备份格式 | 从 MySQL 读数据，再写入临时 SQLite 文件；客户端无需改 |
| 改成 JSON / ZIP | 更适合跨库备份，但客户端下载逻辑要改 |

建议先保留 SQLite 备份格式，减少客户端改动；后续再评估 JSON 导出。

---

## 9. 验收清单

### 9.1 功能验收

| 模块 | 必测项 |
|------|--------|
| 注册/登录 | 新账号、重复用户名、大小写不同的用户名、密码错误、过期令牌 |
| 账号 | 列表、新增、删除他人、禁止删除自己、删除后数据不可见 |
| 分类 | 收入/支出同名分类、同账号同类型重名冲突、有账单时禁止删除 |
| 标签 | 分类下重名冲突、最多 8 个标签、删除分类级联删除标签 |
| 账单 | 新增、编辑、删除、跨月查询、日期范围查询、关键词搜索、分类/类型/标签筛选 |
| 金额 | `0.1 + 0.2` 类场景、两位小数、汇总与明细一致、导入金额一致 |
| 报告 | 周/月/年边界、跨年、空数据、预算超支、趋势对比 |
| 导入 | CSV/XLSX、支付宝/微信/银行卡、重复单号、跳过失败交易、3000 条上限 |
| AI | 状态、对话、上下文、模型切换、历史、清空、草稿标记已入账 |
| 导出 | CSV 编码与列顺序、备份文件可打开、只含当前账号数据 |
| 多账号 | A 账号看不到 B 账号的分类、标签、账单、预算、对话 |

### 9.2 数据验收

```sql
-- 每个账号的账单数量
SELECT user_id, COUNT(*) FROM transactions GROUP BY user_id;

-- 金额合计（分）
SELECT SUM(amount_cents) FROM transactions;

-- 导入键唯一性
SELECT user_id, source, external_id, COUNT(*)
FROM transactions
WHERE external_id IS NOT NULL
GROUP BY user_id, source, external_id
HAVING COUNT(*) > 1;

-- 外键完整性
SELECT COUNT(*) FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
WHERE c.id IS NULL;
```

### 9.3 性能与稳定性验收

- 50–100 并发请求下，登录、账单列表、汇总接口无 5xx
- 连续导入 3000 条账单时，无不一致、无重复
- MySQL 连接池使用率不持续打满
- 慢查询日志中没有跨月账单列表、报表聚合的明显慢查询
- `SHOW PROCESSLIST` 无大量长时间空闲事务

---

## 10. 回滚方案

### 10.1 切换前回滚（推荐窗口内）

1. 停止新版本服务
2. 把 `DATABASE_URL` 改回 SQLite 或删除该变量
3. 用旧版本代码启动
4. 确认 `account.db` 未被新版本写入（切换前应保持只读或停写）

### 10.2 切换后回滚

如果 MySQL 已经产生新数据，不能直接切回旧 SQLite，需要：

1. 停写，进入维护模式
2. 从 MySQL 反向导出新增数据
3. 合并回 SQLite
4. 或者直接以 MySQL 为准，修复新版本问题，不回滚数据库

因此建议：

- 首次切换放在低峰期
- 切换前保留最终 SQLite 备份
- 切换后先只开放小范围账号验证
- 确认稳定后再扩大范围

---

## 11. 风险点与规避

| 风险 | 说明 | 规避 |
|------|------|------|
| SQLite 主键不自增 | `BIGINT` 在 SQLite 中不是 `INTEGER PRIMARY KEY` | 使用 `with_variant(Integer, "sqlite")` |
| Alembic 初始迁移类型错误 | 在 SQLite 下生成迁移，主键变 `INTEGER` | 在 MySQL 连接下生成，或手写 DDL revision |
| 大小写用户名冲突 | MySQL 排序规则可能把更多字符视为相同 | 迁移前检查用户名唯一性；必要时统一小写 |
| 日期语义变化 | `TEXT` 变 `DATE`，带时间的旧值会被截断 | 迁移脚本取前 10 位；业务上账单只保留日期 |
| 金额精度 | `FLOAT`/`DOUBLE` 会引入误差 | 继续以 `amount_cents` 为准，`DECIMAL(12,2)` 仅展示 |
| 导入批量过大 | `max_allowed_packet` 或连接池被打满 | 迁移脚本按 500 条分批；导入接口也分批提交 |
| 外键级联顺序 | 多级级联删除可能因 `RESTRICT` 失败 | 账号删除显式按顺序删除，不用数据库级联删账本 |
| `ON CONFLICT` 不存在 | SQLite 语法在 MySQL 不兼容 | 改为先查后写，或用 MySQL 方言 upsert |
| 测试误连生产库 | 测试读取 `DATABASE_URL` | 测试启动前强制覆盖为临时 SQLite |
| 备份接口失效 | `backup.db` 原本依赖 SQLite 读法 | 改为从 MySQL 查询后写入临时 SQLite |
| 时区不一致 | MySQL `DATETIME` 无时区 | 服务端、MySQL、容器统一 `Asia/Shanghai`，或统一 UTC |
| 连接数不足 | 每个请求一个 Session，AI/导入并发高 | 设置 `pool_size`、`max_overflow`，限制 worker 数量 |

### 11.1 MySQL 服务端建议

```ini
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci
default-time-zone = '+08:00'
max_connections = 200
max_allowed_packet = 16M
innodb_buffer_pool_size = 1G
slow_query_log = 1
long_query_time = 1
```

- MySQL 只监听内网，不直接暴露 3306
- 使用独立账号，只授予 `account` 库权限
- 开启自动备份，保留至少 7 天
- 上线前用 `mysqldump --single-transaction` 做一次全量备份

---

## 12. 最小落地版本

如果不想一次性重写全部代码，可以先做**最小可用迁移**：

1. 只引入 `models.py` + `db.py` + Alembic
2. 只把 `auth.py` 和 `transactions` 相关接口切到 SQLAlchemy
3. 报表、导入、对话暂时保留原 SQL，但通过同一个 `Session` 执行
4. 等核心链路稳定后，再逐个替换剩余 SQLite 专有 SQL

但要注意：**同一个进程里不要同时维护两套连接方式**。要么全部走 SQLAlchemy Engine，要么全部走旧 `sqlite3` 连接；混用会让事务、连接池和测试环境变得不可控。




