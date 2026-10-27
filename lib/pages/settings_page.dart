import 'package:flutter/material.dart';

import '../api/chat_api.dart';
import '../config/api_config.dart';
import '../config/chat_model_config.dart';
import '../config/theme_config.dart';
import '../constants/app_colors.dart';
import 'ai_chat_page.dart';
import 'bill_import_page.dart';
import 'category_manage_page.dart';
import 'tag_manage_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onApiConfigChanged;
  final VoidCallback? onDataChanged;

  const SettingsPage({super.key, this.onApiConfigChanged, this.onDataChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiUrlController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: ApiConfig.baseUrl);
    _loadChatProviders();
  }

  Future<void> _loadChatProviders() async {
    try {
      final status = await ChatApi().fetchStatus();
      ChatModelConfig.applyProviders(status.providers);
    } catch (_) {}
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveApiUrl() async {
    setState(() => _saving = true);
    try {
      await ApiConfig.saveBaseUrl(_apiUrlController.text);
      widget.onApiConfigChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API 地址已保存')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _resetApiUrl() async {
    await ApiConfig.resetBaseUrl();
    _apiUrlController.text = ApiConfig.baseUrl;
    widget.onApiConfigChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已恢复默认 API 地址')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text(
              '设置',
              style: TextStyle(
                color: AppColors.of(context).textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            Text(
              '外观',
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeConfig.mode,
              builder: (context, themeMode, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.of(context).bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _ThemeChoice(
                        label: '跟随系统',
                        selected: themeMode == ThemeMode.system,
                        onTap: () => ThemeConfig.save(ThemeMode.system),
                      ),
                      _ThemeChoice(
                        label: '浅色',
                        selected: themeMode == ThemeMode.light,
                        onTap: () => ThemeConfig.save(ThemeMode.light),
                      ),
                      _ThemeChoice(
                        label: '深色',
                        selected: themeMode == ThemeMode.dark,
                        onTap: () => ThemeConfig.save(ThemeMode.dark),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 8),
            Text(
              '跟随系统时，使用设备当前的浅色或深色外观。',
              style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
            ),
            SizedBox(height: 32),
            Text(
              'API 配置',
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.of(context).bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _apiUrlController,
                enabled: !_saving,
                style: TextStyle(color: AppColors.of(context).textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:8000',
                  hintStyle: TextStyle(color: AppColors.of(context).textTertiary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '修改后所有页面都会使用新的后端地址。Android 模拟器默认 http://10.0.2.2:8000，其他平台默认 http://127.0.0.1:8000。',
              style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _resetApiUrl,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.of(context).textSecondary,
                      side: BorderSide(
                        color: AppColors.of(context).divider.withValues(alpha: 0.8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('恢复默认'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveApiUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).addBtnBg,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('保存'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            Text(
              '记账',
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Material(
              color: AppColors.of(context).bgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.category_outlined, color: AppColors.of(context).addBtnBg),
                title: Text(
                  '分类管理',
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                ),
                subtitle: Text(
                  '分别管理收入和支出分类',
                  style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.of(context).textTertiary),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CategoryManagePage()),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            Material(
              color: AppColors.of(context).bgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.label_outline, color: AppColors.of(context).addBtnBg),
                title: Text(
                  '标签设置',
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                ),
                subtitle: Text(
                  '按分类设置常用标签，记一笔时点选填入备注',
                  style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.of(context).textTertiary),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TagManagePage()),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            Material(
              color: AppColors.of(context).bgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.file_upload_outlined, color: AppColors.of(context).addBtnBg),
                title: Text(
                  '导入账单',
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                ),
                subtitle: Text(
                  '导入支付宝、微信或银行卡导出的账单',
                  style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.of(context).textTertiary),
                onTap: () async {
                  final imported = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const BillImportPage()),
                  );
                  if (imported == true) {
                    widget.onDataChanged?.call();
                  }
                },
              ),
            ),
            SizedBox(height: 32),
            Text(
              'AI 助手',
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            AnimatedBuilder(
              animation: Listenable.merge([
                ChatModelConfig.selection,
                ChatModelConfig.providers,
              ]),
              builder: (context, _) {
                final colors = AppColors.of(context);
                final selected = ChatModelConfig.selection.value;
                final children = <Widget>[];
                for (final provider in ChatModelConfig.providers.value) {
                  if (children.isNotEmpty) {
                    children.add(Divider(height: 1, color: colors.divider));
                  }
                  children.add(
                    _ProviderHeading(
                      name: provider.name,
                      hint: provider.configured ? '' : provider.hint,
                    ),
                  );
                  if (!provider.available || provider.models.isEmpty) {
                    children.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            provider.hint.isEmpty ? '暂无可选模型' : provider.hint,
                            style: TextStyle(color: colors.textTertiary, fontSize: 13),
                          ),
                        ),
                      ),
                    );
                    continue;
                  }
                  for (var index = 0; index < provider.models.length; index++) {
                    if (index > 0) {
                      children.add(Divider(height: 1, color: colors.divider));
                    }
                    final option = provider.models[index];
                    children.add(
                      _ModelChoice(
                        option: option,
                        selected: selected.providerId == provider.id &&
                            selected.modelId == option.id,
                        onTap: () => ChatModelConfig.save(provider.id, option.id),
                      ),
                    );
                  }
                }
                return Material(
                  color: colors.bgSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                );
              },
            ),
            SizedBox(height: 8),
            Text(
              '选择后，下一轮 AI 对话会使用这个模型。各厂商的密钥写在 server/.env。',
              style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
            ),
            SizedBox(height: 12),
            Material(
              color: AppColors.of(context).bgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.auto_awesome, color: AppColors.of(context).addBtnBg),
                title: Text(
                  'AI 记账助手',
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                ),
                subtitle: Text(
                  '分析收支与消费建议',
                  style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.of(context).textTertiary),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AiChatPage()),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
            Text(
              'DeepSeek 使用 DEEPSEEK_API_KEY，Kimi 使用 KIMI_API_KEY，都写在后端 server/.env。',
              style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
            ),
            SizedBox(height: 32),
            Text(
              '关于',
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.of(context).bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '记账 App',
                    style: TextStyle(
                      color: AppColors.of(context).textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '客户端通过 REST API 连接本地 FastAPI 后端，数据存储在 SQLite 数据库中。',
                    style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderHeading extends StatelessWidget {
  final String name;
  final String hint;

  const _ProviderHeading({required this.name, this.hint = ''});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            name,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              hint,
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelChoice extends StatelessWidget {
  final ChatModelOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ModelChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.addBtnBg : colors.textTertiary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(color: colors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.addBtnBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
