import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../config/auth_config.dart';
import '../constants/app_colors.dart';
import '../models/app_user.dart';

class UserManagePage extends StatefulWidget {
  const UserManagePage({super.key});

  @override
  State<UserManagePage> createState() => _UserManagePageState();
}

class _UserManagePageState extends State<UserManagePage> {
  final _api = AuthApi();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  List<AppUser> _users = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = AuthConfig.session.value?.user.displayName ?? '';
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _api.listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    try {
      final user = await _api.updateProfile(displayName: _nameController.text);
      await AuthConfig.updateUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('昵称已保存')));
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePassword() async {
    setState(() => _saving = true);
    try {
      final user = await _api.updateProfile(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      await AuthConfig.updateUser(user);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('密码已更新')));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createUser() async {
    final username = TextEditingController();
    final password = TextEditingController();
    final displayName = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        return Dialog(
          backgroundColor: colors.bgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '新建账号',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '新账号有自己的分类和账单。',
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 18),
                _ManageField(controller: username, hint: '用户名'),
                SizedBox(height: 12),
                _ManageField(controller: displayName, hint: '昵称，可不填'),
                SizedBox(height: 12),
                _ManageField(controller: password, hint: '密码', obscure: true),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: '取消',
                        filled: false,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: '创建',
                        filled: true,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (created != true) {
      username.dispose();
      password.dispose();
      displayName.dispose();
      return;
    }
    try {
      await _api.createUser(
        username: username.text,
        password: password.text,
        displayName: displayName.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('账号已创建')));
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      username.dispose();
      password.dispose();
      displayName.dispose();
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        return Dialog(
          backgroundColor: colors.bgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '删除 ${user.displayName}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '会删除这个账号下的分类、账单、预算和对话。',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: '取消',
                        filled: false,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: '删除',
                        filled: true,
                        danger: true,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await _api.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除')));
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await AuthConfig.clear();
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException ? error.message : '操作失败，请稍后重试';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentId = AuthConfig.session.value?.user.id;
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: Text(
          '用户管理',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: colors.bgPrimary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          ValueListenableBuilder(
            valueListenable: AuthConfig.session,
            builder: (context, session, _) {
              final user = session?.user;
              if (user == null) return SizedBox.shrink();
              return _ProfileHeader(user: user);
            },
          ),
          SizedBox(height: 28),
          _SectionLabel('昵称'),
          SizedBox(height: 12),
          _ManageField(controller: _nameController, hint: '显示名称'),
          SizedBox(height: 12),
          _PrimaryButton(label: '保存昵称', onPressed: _saving ? null : _saveName),
          SizedBox(height: 28),
          _SectionLabel('密码'),
          SizedBox(height: 12),
          _ManageField(
            controller: _currentPasswordController,
            hint: '当前密码',
            obscure: true,
          ),
          SizedBox(height: 12),
          _ManageField(
            controller: _newPasswordController,
            hint: '新密码',
            obscure: true,
          ),
          SizedBox(height: 8),
          Text(
            '至少 6 位。',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
          SizedBox(height: 12),
          _PrimaryButton(
            label: '更新密码',
            onPressed: _saving ? null : _savePassword,
          ),
          SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _SectionLabel('全部账号')),
              TextButton.icon(
                onPressed: _createUser,
                icon: Icon(Icons.add, size: 18),
                label: Text('新建'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.addBtnBg,
                  textStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(color: colors.addBtnBg),
              ),
            )
          else
            for (var i = 0; i < _users.length; i++) ...[
              if (i > 0) SizedBox(height: 10),
              _AccountTile(
                user: _users[i],
                current: _users[i].id == currentId,
                onDelete: _users[i].id == currentId
                    ? null
                    : () => _deleteUser(_users[i]),
              ),
            ],
          SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.expenseRed,
                backgroundColor: colors.bgSecondary,
                side: BorderSide(
                  color: colors.expenseRed.withValues(alpha: 0.28),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _Avatar(name: user.displayName, size: 56),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  user.username,
                  style: TextStyle(color: colors.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AppUser user;
  final bool current;
  final VoidCallback? onDelete;

  const _AccountTile({
    required this.user,
    required this.current,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Avatar(name: user.displayName, size: 42),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  user.username,
                  style: TextStyle(color: colors.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (current)
            Container(
              margin: EdgeInsets.only(right: 6),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.addBtnBg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '当前',
                style: TextStyle(
                  color: colors.navActive,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: colors.expenseRed),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;

  const _Avatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.addBtnBg,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        _initial(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.of(context).textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ManageField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  const _ManageField({
    required this.controller,
    required this.hint,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textTertiary),
        filled: true,
        fillColor: colors.bgSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.addBtnBg,
          disabledBackgroundColor: colors.addBtnBg.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool danger;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final background = danger ? colors.expenseRed : colors.addBtnBg;
    return SizedBox(
      height: 44,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: background,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textSecondary,
                side: BorderSide(color: colors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Text(label),
            ),
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
