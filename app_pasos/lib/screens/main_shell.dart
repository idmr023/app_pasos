import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/step_provider.dart';
import '../providers/xp_provider.dart';
import '../providers/gym_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/route_provider.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'gym/gym_screen.dart';
import 'chat/chat_screen.dart';
import 'tracking/live_hub_screen.dart';

import 'routes/routes_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class MainShellScope extends InheritedWidget {
  final void Function(int) goToTab;

  const MainShellScope({
    super.key,
    required this.goToTab,
    required super.child,
  });

  static MainShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellScope>();

  @override
  bool updateShouldNotify(MainShellScope oldWidget) =>
      goToTab != oldWidget.goToTab;
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    GymScreen(),
    LiveHubScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initProviders());
  }

  void _initProviders() {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    final token = auth.token!;
    context.read<ChallengeProvider>().setToken(token);
    context.read<ChallengeProvider>().loadChallenges();
    context.read<StepProvider>().setToken(token);
    context.read<StepProvider>().loadTodaySteps();
    context.read<XpProvider>().setToken(token);
    context.read<XpProvider>().loadXp();
    context.read<GymProvider>().setToken(token);
    context.read<ChatProvider>().setToken(token);
    context.read<ChatProvider>().loadHistory();
    context.read<RouteProvider>().setToken(token);
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      goToTab: _goToTab,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.background,
                Color(0xFF0A0A1A),
                AppTheme.background,
              ],
            ),
          ),
          child: SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _goToTab,
            backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.darkGrey,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Pasos'),
              BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Gimnasio'),
              BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Tracking'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}