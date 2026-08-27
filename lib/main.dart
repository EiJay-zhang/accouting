import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'pages/home_page.dart';
import 'pages/add_transaction_page.dart';
import 'pages/placeholder_pages.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.addBtnBg,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.bgPrimary,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();

  late final List<Widget> _pages = [
    HomePage(key: _homePageKey),
    const BillsPage(),
    const SizedBox.shrink(),
    const ReportPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBar,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, '记账', Icons.book),
          _buildNavItem(1, '账单', Icons.receipt_long),
          const SizedBox(width: 56),
          _buildNavItem(3, '报告', Icons.bar_chart),
          _buildNavItem(4, '设置', Icons.settings),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppColors.navActive : AppColors.navItem;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () async {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const AddTransactionPage(),
          ),
        );
        if (saved == true && mounted) {
          _homePageKey.currentState?.refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已保存')),
          );
        }
      },
      backgroundColor: AppColors.addBtnBg,
      child: const Icon(
        Icons.add_rounded,
        color: AppColors.addBtnIcon,
        size: 32,
      ),
    );
  }
}
