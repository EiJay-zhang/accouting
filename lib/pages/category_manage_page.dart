import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

const _categoryIcons = [
  '🍜',
  '🚇',
  '🛍️',
  '💰',
  '🎬',
  '💊',
  '📚',
  '🏠',
  '☕',
  '🎮',
  '✈️',
  '🎁',
  '📈',
  '💵',
  '💡',
  '📱',
  '🚗',
  '🏋️',
  '🎵',
  '🛒',
  '🏥',
  '🧧',
  '💼',
  '🏷️',
];

const _categoryColors = [
  '#FF9800',
  '#2196F3',
  '#E91E63',
  '#4CAF50',
  '#9C27B0',
  '#F44336',
  '#3F51B5',
  '#009688',
  '#6366F1',
  '#F59E0B',
  '#14B8A6',
  '#EC4899',
  '#06B6D4',
  '#84CC16',
  '#EF4444',
];

class CategoryManagePage extends StatefulWidget {
  final TransactionType initialType;

  const CategoryManagePage({
    super.key,
    this.initialType = TransactionType.expense,
  });

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  final TransactionService _service = TransactionService();

  late TransactionType _selectedType;
  List<TransactionCategory> _categories = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _load();
  }

  List<TransactionCategory> get _visibleCategories =>
      _categories.where((category) => category.type == _selectedType).toList();

  Future<void> _load() async {
    try {
      final categories = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is ApiException ? error.message : '分类加载失败，请检查后端服务';
      });
    }
  }

  Future<void> _openForm({TransactionCategory? category}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoryFormPage(
          type: category?.type ?? _selectedType,
          category: category,
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete(TransactionCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).bgSecondary,
        title: Text(
          '删除分类',
          style: TextStyle(color: AppColors.of(context).textPrimary),
        ),
        content: Text(
          '确定删除「${category.name}」吗？已有账单的分类不能删除。',
          style: TextStyle(color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: AppColors.of(context).expenseRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteCategory(category.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除分类')));
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '删除失败，请稍后重试';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bgPrimary,
        elevation: 0,
        title: Text(
          '分类管理',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.of(context).textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _TypeSwitch(
                selected: _selectedType,
                onChanged: (type) => setState(() => _selectedType = type),
              ),
            ),
            Expanded(child: _buildBody()),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading || _loadError != null
                      ? null
                      : () => _openForm(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.of(context).addBtnBg,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.of(context).bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '新增分类',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.of(context).addBtnBg),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.of(context).addBtnBg,
                  foregroundColor: Colors.white,
                ),
                child: Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _visibleCategories;
    if (visible.isEmpty) {
      final label = _selectedType == TransactionType.expense ? '支出' : '收入';
      return Center(
        child: Text(
          '还没有$label分类',
          style: TextStyle(
            color: AppColors.of(context).textTertiary,
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: visible.length,
      separatorBuilder: (_, _) => SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = visible[index];
        return Material(
          color: AppColors.of(context).bgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: EdgeInsets.only(left: 16, right: 4),
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(category.icon, style: TextStyle(fontSize: 22)),
            ),
            title: Text(
              category.name,
              style: TextStyle(
                color: AppColors.of(context).textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => _openForm(category: category),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _confirmDelete(category),
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.of(context).expenseRed,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryFormPage extends StatefulWidget {
  final TransactionType type;
  final TransactionCategory? category;

  const CategoryFormPage({super.key, required this.type, this.category});

  bool get isEditing => category != null;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final TransactionService _service = TransactionService();
  final _nameController = TextEditingController();
  final _iconController = TextEditingController();

  late String _colorHex;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.category;
    if (existing != null) {
      _nameController.text = existing.name;
      _iconController.text = existing.icon;
      _colorHex = existing.colorHex;
    } else {
      _iconController.text = '🏷️';
      _colorHex = '#6366F1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final icon = _iconController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写分类名称');
      return;
    }
    if (icon.isEmpty) {
      _showMessage('请选择图标');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.isEditing) {
        await _service.updateCategory(
          id: widget.category!.id,
          name: name,
          icon: icon,
          colorHex: _colorHex,
        );
      } else {
        await _service.createCategory(
          name: name,
          icon: icon,
          colorHex: _colorHex,
          type: widget.type,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error is ApiException ? error.message : '保存失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.type == TransactionType.expense ? '支出' : '收入';
    final previewColor = TransactionCategory.colorFromHex(_colorHex);

    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bgPrimary,
        elevation: 0,
        title: Text(
          widget.isEditing ? '编辑分类' : '新增$typeLabel分类',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.of(context).textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  Text(
                    '$typeLabel分类',
                    style: TextStyle(
                      color: AppColors.of(context).textTertiary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: previewColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: _CategoryEmoji(
                        _iconController.text,
                        size: 40,
                        fallback: '🏷️',
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _FieldShell(
                    child: TextField(
                      controller: _nameController,
                      enabled: !_submitting,
                      maxLength: 20,
                      style: TextStyle(
                        color: AppColors.of(context).textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '分类名称',
                        hintStyle: TextStyle(
                          color: AppColors.of(context).textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '图标',
                    style: TextStyle(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _categoryIcons.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 56,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      final icon = _categoryIcons[index];
                      final selected = _iconController.text == icon;
                      return GestureDetector(
                        onTap: _submitting
                            ? null
                            : () => setState(() => _iconController.text = icon),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? previewColor.withValues(alpha: 0.25)
                                : AppColors.of(context).bgSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? previewColor
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: _CategoryEmoji(icon, size: 26),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  _FieldShell(
                    child: TextField(
                      controller: _iconController,
                      enabled: !_submitting,
                      maxLength: 8,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: AppColors.of(context).textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '或输入自己的 emoji',
                        hintStyle: TextStyle(
                          color: AppColors.of(context).textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '颜色',
                    style: TextStyle(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final hex in _categoryColors)
                        GestureDetector(
                          onTap: _submitting
                              ? null
                              : () => setState(() => _colorHex = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: TransactionCategory.colorFromHex(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _colorHex.toLowerCase() == hex.toLowerCase()
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.of(context).addBtnBg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEditing ? '保存修改' : '保存',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSwitch({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TypeSwitchItem(
            label: '支出',
            selected: selected == TransactionType.expense,
            activeColor: AppColors.of(context).expenseRed,
            onTap: () => onChanged(TransactionType.expense),
          ),
          _TypeSwitchItem(
            label: '收入',
            selected: selected == TransactionType.income,
            activeColor: AppColors.of(context).incomeGreen,
            onTap: () => onChanged(TransactionType.income),
          ),
        ],
      ),
    );
  }
}

class _TypeSwitchItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeSwitchItem({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? activeColor
                    : AppColors.of(context).textTertiary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  final Widget child;

  const _FieldShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _CategoryEmoji extends StatelessWidget {
  final String symbol;
  final double size;
  final String fallback;

  const _CategoryEmoji(this.symbol, {required this.size, this.fallback = ''});

  @override
  Widget build(BuildContext context) {
    final trimmed = symbol.trim();
    final glyph = trimmed.isEmpty ? fallback : trimmed.characters.first;
    return SizedBox(
      width: size + 10,
      height: size + 10,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          glyph,
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontSize: size,
            height: 1.25,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }
}
