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
import 'menu_screen.dart';
import 'home_screen.dart';
import 'gym/gym_screen.dart';
import 'chat/chat_screen.dart';
import 'tracking/live_hub_screen.dart';

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

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Fundido corto al cambiar de tab. Se anima el IndexedStack completo con
  // FadeTransition (no reconstruye hijos) para conservar el estado de cada tab.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _fade.forward(from: 0.35);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    GymScreen(),
    LiveHubScreen(),
    ChatScreen(),
    MenuScreen(),
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
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
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
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: AppTheme.surface.withValues(alpha: 0.97),
              indicatorColor: AppTheme.primary.withValues(alpha: 0.22),
              height: 66,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 11,
                  fontWeight:
                      states.contains(WidgetState.selected)
                          ? FontWeight.w800
                          : FontWeight.w500,
                  color:
                      states.contains(WidgetState.selected)
                          ? AppTheme.primary
                          : AppTheme.darkGrey,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color:
                      states.contains(WidgetState.selected)
                          ? AppTheme.primary
                          : AppTheme.darkGrey,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _goToTab,
              animationDuration: const Duration(milliseconds: 400),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.directions_run_outlined),
                  selectedIcon: Icon(Icons.directions_run),
                  label: 'Pasos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: 'Gimnasio',
                ),
                NavigationDestination(
                  key: ValueKey('bottomNavTracking'),
                  icon: Icon(Icons.live_tv_outlined),
                  selectedIcon: Icon(Icons.live_tv),
                  label: 'Tracking',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Coach',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Explorar',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}