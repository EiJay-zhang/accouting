-- 把旧的 categories（仅 name 唯一、没有收支类型）重建为带 type 的表。
-- 由 database.py 在检测到缺少 type 列时，放在同一个事务里执行。
-- 已有 id 会保留。混合收支的分类会在脚本之后按账单拆成两条。

CREATE TABLE categories_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('income', 'expense')),
    UNIQUE (name, type)
);

INSERT INTO categories_new (id, name, icon, color, type)
SELECT id, name, icon, color, 'expense'
FROM categories;

DROP TABLE categories;

ALTER TABLE categories_new RENAME TO categories;
