import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/step_provider.dart';
import '../providers/xp_provider.dart';
import '../providers/gym_provider.dart';
import '../providers/chat_provider.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'gym/gym_screen.dart';
import 'chat/chat_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    GymScreen(),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.darkGrey,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Pasos'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Gimnasio'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}