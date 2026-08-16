import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/challenge_provider.dart';
import 'providers/step_provider.dart';
import 'providers/xp_provider.dart';
import 'providers/gym_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/route_provider.dart';
import 'providers/tracking_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/challenge_create_screen.dart';
import 'screens/challenge_join_screen.dart';
import 'screens/challenge_room_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/main_shell.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/tracking/live_hub_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const AppPasosApp());
}

class AppPasosApp extends StatelessWidget {
  const AppPasosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChallengeProvider()),
        ChangeNotifierProvider(create: (_) => StepProvider()),
        ChangeNotifierProvider(create: (_) => XpProvider()),
        ChangeNotifierProvider(create: (_) => GymProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
      ],
      child: MaterialApp(
        title: 'App Pasos',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/main': (context) => const MainShell(),
          '/challenge-create': (context) => const ChallengeCreateScreen(),
          '/challenge-join': (context) => const ChallengeJoinScreen(),
          '/challenge-room': (context) => const ChallengeRoomScreen(),
          '/analytics': (context) => const AnalyticsScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/tracker': (context) => const LiveHubScreen(),
        },
      ),
    );
  }
}
