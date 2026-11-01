import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../models/daily_checkin.dart';
import '../screens/student/tasks_screen.dart';
import '../screens/student/checkin_gacha_screen.dart';
import '../screens/student/handbook_screen.dart';
import '../screens/student/chat_screen.dart';
import '../core/onboarding/models/feature_keys.dart';
import '../core/onboarding/services/feature_onboarding_service.dart';
import '../core/onboarding/feature_tour_controller.dart';
import '../widgets/sync_status_banner.dart';

class StudentNav extends StatefulWidget {
  const StudentNav({super.key});

  static StudentNavState? of(BuildContext context) =>
      context.findAncestorStateOfType<StudentNavState>();

  static void switchToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<StudentNavState>()?.switchToTab(index);
  }

  static void setNavVisible(BuildContext context, bool visible) {
    context.findAncestorStateOfType<StudentNavState>()?.setNavVisible(visible);
  }

  @override
  State<StudentNav> createState() => StudentNavState();
}

class StudentNavState extends State<StudentNav> {
  int _currentIndex = 0;
  bool _isNavVisible = true;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  final GlobalKey<CheckinGachaScreenState> _checkinKey = GlobalKey<CheckinGachaScreenState>();
  final GlobalKey<HandbookScreenState> _handbookKey = GlobalKey<HandbookScreenState>();
  final GlobalKey<ChatScreenState> _chatKey = GlobalKey<ChatScreenState>();

  final Set<int> _autoStartedTabs = {};

  static const Map<int, String> _tabFeatureKeys = {
    1: FeatureKeys.tasks,
    2: FeatureKeys.checkin,
    3: FeatureKeys.handbook,
    4: FeatureKeys.chat,
  };

  void switchToTab(int index) {
    if (!mounted || index < 0 || index >= _screens.length) return;
    setState(() {
      _currentIndex = index;
      _isNavVisible = true;
    });
    _triggerTabTourIfNeeded(index);
  }

  void openCheckin(MoodLevel mood) {
    setState(() {
      _screens[2] = CheckinGachaScreen(key: _checkinKey, initialMood: mood);
      _currentIndex = 2;
      _isNavVisible = true;
    });
    _triggerTabTourIfNeeded(2);
  }

  void _triggerTabTourIfNeeded(int tabIndex) {
    final featureKey = _tabFeatureKeys[tabIndex];
    if (featureKey == null) return;

    final service = FeatureOnboardingService.instance;
    if (service.hasCompleted(featureKey) || _autoStartedTabs.contains(tabIndex)) {
      return;
    }
    _autoStartedTabs.add(tabIndex);

    // Chờ sau khi animation chuyển tab hoàn tất (delay ngắn + post-frame callback)
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Không khởi chạy 2 tour cùng một lúc
        if (FeatureTour.isShowing) return;
        // Không khởi chạy tour cho tab mà người dùng không đang xem
        if (_currentIndex != tabIndex) return;

        switch (tabIndex) {
          case 1:
            _tasksKey.currentState?.startTour(force: false);
            break;
          case 2:
            _checkinKey.currentState?.startTour(force: false);
            break;
          case 3:
            _handbookKey.currentState?.startTour(force: false);
            break;
          case 4:
            _chatKey.currentState?.startTour(force: false);
            break;
        }
      });
    });
  }

  void setNavVisible(bool visible) {
    if (mounted && _isNavVisible != visible) {
      setState(() => _isNavVisible = visible);
    }
  }

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    TasksScreen(key: _tasksKey),
    CheckinGachaScreen(key: _checkinKey),
    HandbookScreen(key: _handbookKey),
    ChatScreen(key: _chatKey),
  ];

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: SyncStatusBanner()),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                for (int i = 0; i < _screens.length; i++)
                  TickerMode(enabled: _currentIndex == i, child: _screens[i]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isNavVisible && !isKeyboardOpen
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: switchToTab,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check_rounded),
                  label: 'Nhiệm vụ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: 'Điểm danh',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: 'Cẩm nang',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Trò chuyện',
                ),
              ],
            )
          : null,
    );
  }
}
