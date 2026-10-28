import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../config/auth_config.dart';
import '../constants/app_colors.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _api = AuthApi();
  bool _registering = false;
  bool _submitting = false;
  bool _hasUsers = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final hasUsers = await _api.hasUsers();
      if (!mounted) return;
      setState(() {
        _hasUsers = hasUsers;
        if (!hasUsers) _registering = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final session = _registering
          ? await _api.register(
              username: _usernameController.text,
              password: _passwordController.text,
              displayName: _displayNameController.text,
            )
          : await _api.login(
              username: _usernameController.text,
              password: _passwordController.text,
            );
      await AuthConfig.save(session);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '登录失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/brand/app_icon_512.png', width: 84, height: 84),
              ),
            ),
            SizedBox(height: 18),
            Center(
              child: Text(
                '记账',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
            ),
            SizedBox(height: 28),
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.bgSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _AuthTab(
                    label: '登录',
                    selected: !_registering,
                    onTap: () => setState(() => _registering = false),
                  ),
                  _AuthTab(
                    label: '注册',
                    selected: _registering,
                    onTap: () => setState(() => _registering = true),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _AuthField(controller: _usernameController, hint: '用户名'),
            SizedBox(height: 12),
            if (_registering) ...[
              _AuthField(controller: _displayNameController, hint: '昵称，可不填'),
              SizedBox(height: 12),
            ],
            _AuthField(
              controller: _passwordController,
              hint: '密码',
              obscure: true,
            ),
            SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.addBtnBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_registering ? '注册并进入' : '登录'),
              ),
            ),
            SizedBox(height: 14),
            Text(
              !_hasUsers
                  ? '还没有账号。注册后，这台设备上已有的账单会归到这个账号。'
                  : '每个账号的账单、分类和对话是分开的。',
              style: TextStyle(color: colors.textTertiary, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AuthTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.addBtnBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  const _AuthField({
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
