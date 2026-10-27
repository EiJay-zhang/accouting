-- 标签表为空时写入的默认标签。按分类名称和收支类型找到分类。

INSERT INTO tags (category_id, name, sort_order)
SELECT id, '早餐', 1 FROM categories WHERE name = '餐饮' AND type = 'expense'
UNION ALL
SELECT id, '午餐', 2 FROM categories WHERE name = '餐饮' AND type = 'expense'
UNION ALL
SELECT id, '晚餐', 3 FROM categories WHERE name = '餐饮' AND type = 'expense'
UNION ALL
SELECT id, '外卖', 4 FROM categories WHERE name = '餐饮' AND type = 'expense'
UNION ALL
SELECT id, '咖啡', 5 FROM categories WHERE name = '餐饮' AND type = 'expense'
UNION ALL
SELECT id, '地铁', 1 FROM categories WHERE name = '交通' AND type = 'expense'
UNION ALL
SELECT id, '公交', 2 FROM categories WHERE name = '交通' AND type = 'expense'
UNION ALL
SELECT id, '打车', 3 FROM categories WHERE name = '交通' AND type = 'expense'
UNION ALL
SELECT id, '加油', 4 FROM categories WHERE name = '交通' AND type = 'expense'
UNION ALL
SELECT id, '日用品', 1 FROM categories WHERE name = '购物' AND type = 'expense'
UNION ALL
SELECT id, '服饰', 2 FROM categories WHERE name = '购物' AND type = 'expense'
UNION ALL
SELECT id, '数码', 3 FROM categories WHERE name = '购物' AND type = 'expense'
UNION ALL
SELECT id, '电影', 1 FROM categories WHERE name = '娱乐' AND type = 'expense'
UNION ALL
SELECT id, '游戏', 2 FROM categories WHERE name = '娱乐' AND type = 'expense'
UNION ALL
SELECT id, '聚会', 3 FROM categories WHERE name = '娱乐' AND type = 'expense'
UNION ALL
SELECT id, '买药', 1 FROM categories WHERE name = '医疗' AND type = 'expense'
UNION ALL
SELECT id, '挂号', 2 FROM categories WHERE name = '医疗' AND type = 'expense'
UNION ALL
SELECT id, '检查', 3 FROM categories WHERE name = '医疗' AND type = 'expense'
UNION ALL
SELECT id, '书籍', 1 FROM categories WHERE name = '教育' AND type = 'expense'
UNION ALL
SELECT id, '课程', 2 FROM categories WHERE name = '教育' AND type = 'expense'
UNION ALL
SELECT id, '学费', 3 FROM categories WHERE name = '教育' AND type = 'expense'
UNION ALL
SELECT id, '房租', 1 FROM categories WHERE name = '住房' AND type = 'expense'
UNION ALL
SELECT id, '水电', 2 FROM categories WHERE name = '住房' AND type = 'expense'
UNION ALL
SELECT id, '物业', 3 FROM categories WHERE name = '住房' AND type = 'expense'
UNION ALL
SELECT id, '月薪', 1 FROM categories WHERE name = '工资' AND type = 'income'
UNION ALL
SELECT id, '奖金', 2 FROM categories WHERE name = '工资' AND type = 'income'
UNION ALL
SELECT id, '补贴', 3 FROM categories WHERE name = '工资' AND type = 'income';
