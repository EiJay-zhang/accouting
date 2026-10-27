-- 默认分类。同一名称可以分别存在于收入和支出，按 (name, type) 去重。
-- 用 WHERE NOT EXISTS，避免 INSERT OR IGNORE 在冲突时仍消耗自增 id。

INSERT INTO categories (name, icon, color, type)
SELECT '餐饮', '🍜', '#FF9800', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '餐饮' AND type = 'expense')
UNION ALL
SELECT '交通', '🚇', '#2196F3', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '交通' AND type = 'expense')
UNION ALL
SELECT '购物', '🛍️', '#E91E63', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '购物' AND type = 'expense')
UNION ALL
SELECT '工资', '💰', '#4CAF50', 'income'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '工资' AND type = 'income')
UNION ALL
SELECT '娱乐', '🎬', '#9C27B0', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '娱乐' AND type = 'expense')
UNION ALL
SELECT '医疗', '💊', '#F44336', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '医疗' AND type = 'expense')
UNION ALL
SELECT '教育', '📚', '#3F51B5', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '教育' AND type = 'expense')
UNION ALL
SELECT '住房', '🏠', '#009688', 'expense'
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '住房' AND type = 'expense');
