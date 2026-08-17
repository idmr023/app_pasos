import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'routes/routes_screen.dart';
import 'profile_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _menuOption(
              icon: Icons.map_outlined,
              label: 'Rutas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoutesScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _menuOption(
              icon: Icons.person_outlined,
              label: 'Mi Perfil',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _menuOption(
              icon: Icons.emoji_events_outlined,
              label: 'Retos Finalizados',
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _menuOption(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppTheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}