import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'constants/app_colors.dart';
import 'pages/home_page.dart';
import 'pages/add_transaction_page.dart';
import 'pages/bills_page.dart';
import 'pages/report_page.dart';
import 'pages/settings_page.dart';
import 'pages/ai_chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
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
  final GlobalKey<BillsPageState> _billsPageKey = GlobalKey<BillsPageState>();
  final GlobalKey<ReportPageState> _reportPageKey = GlobalKey<ReportPageState>();

  late final List<Widget> _pages = [
    HomePage(key: _homePageKey),
    BillsPage(key: _billsPageKey),
    const AiChatPage(),
    ReportPage(key: _reportPageKey),
    SettingsPage(onApiConfigChanged: _refreshAllPages),
  ];

  void _refreshAllPages() {
    _homePageKey.currentState?.refresh();
    _billsPageKey.currentState?.refresh();
    _reportPageKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _shouldShowFab ? _buildFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  bool get _shouldShowFab => _currentIndex != 2 && _currentIndex != 4;

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.navBar,
        indicatorColor: AppColors.addBtnBg.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? AppColors.navActive : AppColors.navItem,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.navActive : AppColors.navItem,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '记账',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '报告',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
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
          _refreshAllPages();
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
