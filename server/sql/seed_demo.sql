-- 本地开发用的示例账单。只在交易表为空时由 init_db.py --demo 执行。
-- 分类按名称和收支类型关联，不依赖自增 id。

INSERT INTO transactions (title, category_id, amount, type, date)
SELECT '午餐·外卖', id, 68.50, 'expense', '2026-08-07' FROM categories WHERE name = '餐饮' AND type = 'expense' AND user_id IS NULL
UNION ALL
SELECT '地铁通勤', id, 12.00, 'expense', '2026-08-07' FROM categories WHERE name = '交通' AND type = 'expense' AND user_id IS NULL
UNION ALL
SELECT '8月薪资', id, 18500.00, 'income', '2026-08-05' FROM categories WHERE name = '工资' AND type = 'income' AND user_id IS NULL
UNION ALL
SELECT 'UNIQLO T恤×3', id, 299.00, 'expense', '2026-08-04' FROM categories WHERE name = '购物' AND type = 'expense' AND user_id IS NULL
UNION ALL
SELECT '电影票×2', id, 88.00, 'expense', '2026-08-03' FROM categories WHERE name = '娱乐' AND type = 'expense' AND user_id IS NULL
UNION ALL
SELECT '超市采购', id, 245.00, 'expense', '2026-08-02' FROM categories WHERE name = '购物' AND type = 'expense' AND user_id IS NULL
UNION ALL
SELECT '兼职收入', id, 3200.00, 'income', '2026-08-01' FROM categories WHERE name = '工资' AND type = 'income' AND user_id IS NULL
UNION ALL
SELECT '早餐', id, 15.00, 'expense', '2026-08-01' FROM categories WHERE name = '餐饮' AND type = 'expense' AND user_id IS NULL;
