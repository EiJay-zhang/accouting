import 'package:flutter/material.dart';

import 'api/report_api.dart';
import 'config/api_config.dart';
import 'config/auth_config.dart';
import 'config/chat_model_config.dart';
import 'config/theme_config.dart';
import 'constants/app_colors.dart';
import 'models/transaction.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/add_transaction_page.dart';
import 'pages/bills_page.dart';
import 'pages/report_page.dart';
import 'pages/settings_page.dart';
import 'pages/ai_chat_page.dart';
import 'widgets/app_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await AuthConfig.load();
  await ThemeConfig.load();
  await ChatModelConfig.load();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeConfig.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: '记账',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppColors.light, Brightness.light),
          darkTheme: buildAppTheme(AppColors.dark, Brightness.dark),
          themeMode: themeMode,
          home: const AppSplash(child: AuthGate()),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: AuthConfig.session,
      builder: (context, session, _) {
        if (session == null) return const AuthPage();
        return MainShell(key: ValueKey(session.user.id));
      },
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
  final GlobalKey<ReportPageState> _reportPageKey =
      GlobalKey<ReportPageState>();

  late final List<Widget> _pages = [
    HomePage(key: _homePageKey, onDataChanged: _refreshAllPages),
    BillsPage(key: _billsPageKey, onDataChanged: _refreshAllPages),
    AiChatPage(onDataChanged: _refreshAllPages),
    ReportPage(key: _reportPageKey, onOpenCategory: _openCategoryBills),
    SettingsPage(
      onApiConfigChanged: _refreshAllPages,
      onDataChanged: _refreshAllPages,
    ),
  ];

  void _openCategoryBills(
    ReportPeriod period,
    DateTime start,
    DateTime end,
    int categoryId,
    String categoryName,
    TransactionType type,
  ) {
    setState(() => _currentIndex = 1);
    _billsPageKey.currentState?.focusPeriod(
      span: _billsSpan(period),
      start: start,
      end: end,
      categoryId: categoryId,
      categoryName: categoryName,
      type: type,
    );
  }

  BillsSpan _billsSpan(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.week:
        return BillsSpan.week;
      case ReportPeriod.month:
        return BillsSpan.month;
      case ReportPeriod.year:
        return BillsSpan.year;
    }
  }

  void _refreshAllPages() {
    _homePageKey.currentState?.refresh();
    _billsPageKey.currentState?.refresh();
    _reportPageKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _shouldShowFab ? _buildFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  bool get _shouldShowFab => _currentIndex == 0 || _currentIndex == 1;

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.of(context).navBar,
        indicatorColor: AppColors.of(context).addBtnBg.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? AppColors.of(context).navActive
                : AppColors.of(context).navItem,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected
                ? AppColors.of(context).navActive
                : AppColors.of(context).navItem,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () async {
        final saved = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => AddTransactionPage()));
        if (saved == true && mounted) {
          _refreshAllPages();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已保存')));
        }
      },
      backgroundColor: AppColors.of(context).addBtnBg,
      child: Icon(
        Icons.add_rounded,
        color: AppColors.of(context).addBtnIcon,
        size: 32,
      ),
    );
  }
}
