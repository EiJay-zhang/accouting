import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'category_manage_page.dart';

class TagManagePage extends StatefulWidget {
  final TransactionType initialType;

  const TagManagePage({
    super.key,
    this.initialType = TransactionType.expense,
  });

  @override
  State<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends State<TagManagePage> {
  final TransactionService _service = TransactionService();

  late TransactionType _selectedType;
  List<TransactionCategory> _categories = [];
  List<CategoryTag> _tags = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _load();
  }

  List<TransactionCategory> get _visibleCategories => _categories
      .where((category) => category.type == _selectedType)
      .toList();

  List<CategoryTag> _tagsFor(int categoryId) {
    return _tags.where((tag) => tag.categoryId == categoryId).toList();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getCategories(),
        _service.getTags(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<TransactionCategory>;
        _tags = results[1] as List<CategoryTag>;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is ApiException ? error.message : '标签加载失败，请检查后端服务';
      });
    }
  }

  Future<void> _openCategory(TransactionCategory category) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoryTagsPage(category: category),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openCategoryManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryManagePage(initialType: _selectedType),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bgPrimary,
        elevation: 0,
        title: Text(
          '标签设置',
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: _TypeSwitch(
                selected: _selectedType,
                onChanged: (type) => setState(() => _selectedType = type),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '选择一个分类，为它添加常用标签。记一笔时点选标签即可填入备注。',
                style: TextStyle(
                  color: AppColors.of(context).textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: _buildBody()),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
              const SizedBox(height: 16),
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
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _visibleCategories;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _selectedType == TransactionType.expense
                    ? '还没有支出分类'
                    : '还没有收入分类',
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openCategoryManager,
                child: const Text('去分类管理'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = visible[index];
        final tags = _tagsFor(category.id);
        final summary = tags.isEmpty
            ? '还没有标签'
            : tags.map((tag) => tag.name).join('、');
        return Material(
          color: AppColors.of(context).bgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Text(category.icon, style: const TextStyle(fontSize: 24)),
            title: Text(
              category.name,
              style: TextStyle(
                color: AppColors.of(context).textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.of(context).textTertiary,
                fontSize: 12,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppColors.of(context).textTertiary,
            ),
            onTap: () => _openCategory(category),
          ),
        );
      },
    );
  }
}

class CategoryTagsPage extends StatefulWidget {
  final TransactionCategory category;

  const CategoryTagsPage({super.key, required this.category});

  @override
  State<CategoryTagsPage> createState() => _CategoryTagsPageState();
}

class _CategoryTagsPageState extends State<CategoryTagsPage> {
  final TransactionService _service = TransactionService();
  final TextEditingController _nameController = TextEditingController();

  List<CategoryTag> _tags = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tags = await _service.getTags(categoryId: widget.category.id);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is ApiException ? error.message : '标签加载失败，请检查后端服务';
      });
    }
  }

  Future<void> _addTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标签名称')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final created = await _service.createTag(
        categoryId: widget.category.id,
        name: name,
      );
      if (!mounted) return;
      setState(() {
        _tags = [..._tags, created];
        _changed = true;
      });
      _nameController.clear();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '添加失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(CategoryTag tag) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameTagDialog(initialName: tag.name),
    );
    if (name == null || name == tag.name || !mounted) return;

    try {
      final updated = await _service.updateTag(id: tag.id, name: name);
      if (!mounted) return;
      setState(() {
        _tags = [
          for (final item in _tags)
            if (item.id == tag.id) updated else item,
        ];
        _changed = true;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '修改失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _confirmDelete(CategoryTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).bgSecondary,
        title: Text('删除标签', style: TextStyle(color: AppColors.of(context).textPrimary)),
        content: Text(
          '确定删除「${tag.name}」吗？已记的账单不会受影响。',
          style: TextStyle(color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: AppColors.of(context).expenseRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteTag(tag.id);
      if (!mounted) return;
      setState(() {
        _tags = _tags.where((item) => item.id != tag.id).toList();
        _changed = true;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '删除失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.of(context).bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.of(context).bgPrimary,
          elevation: 0,
          title: Text(
            '${category.icon} ${category.name}',
            style: TextStyle(
              color: AppColors.of(context).textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.of(context).textPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildList()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _nameController,
                          enabled: !_saving && _loadError == null,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saving ? null : _addTag(),
                          style: TextStyle(
                            color: AppColors.of(context).textPrimary,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: '新标签，如早餐',
                            hintStyle: TextStyle(color: AppColors.of(context).textTertiary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving || _loadError != null ? null : _addTag,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.of(context).addBtnBg,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('添加'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.of(context).addBtnBg),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
              const SizedBox(height: 16),
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
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_tags.isEmpty) {
      return Center(
        child: Text(
          '还没有标签\n添加后，记一笔时可以点选填入备注',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.of(context).textTertiary,
            height: 1.6,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      itemCount: _tags.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tag = _tags[index];
        return Material(
          color: AppColors.of(context).bgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Text(
              tag.name,
              style: TextStyle(color: AppColors.of(context).textPrimary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '修改',
                  onPressed: () => _rename(tag),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppColors.of(context).textTertiary,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _confirmDelete(tag),
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.of(context).expenseRed,
                    size: 20,
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

class _RenameTagDialog extends StatefulWidget {
  final String initialName;

  const _RenameTagDialog({required this.initialName});

  @override
  State<_RenameTagDialog> createState() => _RenameTagDialogState();
}

class _RenameTagDialogState extends State<_RenameTagDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.of(context).bgSecondary,
      title: Text('修改标签', style: TextStyle(color: AppColors.of(context).textPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: TextStyle(color: AppColors.of(context).textPrimary),
        decoration: InputDecoration(
          hintText: '标签名称',
          hintStyle: TextStyle(color: AppColors.of(context).textTertiary),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSwitch({
    required this.selected,
    required this.onChanged,
  });

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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : AppColors.of(context).textTertiary,
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
