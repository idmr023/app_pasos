import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/player_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  String _selectedAvatar = 'runner';
  bool _notificationsEnabled = false;
  bool _isSaving = false;
  int _reminderHour = 20;
  int _reminderMinute = 0;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _selectedAvatar = user?.avatar ?? 'runner';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  final _avatars = [
    {'type': 'runner', 'icon': Icons.directions_run, 'label': 'Corredor'},
    {'type': 'crown', 'icon': Icons.emoji_events, 'label': 'Campeón'},
    {'type': 'fire', 'icon': Icons.local_fire_department, 'label': 'Fuego'},
    {'type': 'star', 'icon': Icons.star, 'label': 'Estrella'},
  ];

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre debe tener al menos 2 caracteres'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      displayName: name,
      avatar: _selectedAvatar,
    );

    if (_notificationsEnabled) {
      await NotificationService.init();
      await NotificationService.scheduleDailyReminder(hour: _reminderHour, minute: _reminderMinute);
    } else {
      await NotificationService.cancelAll();
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado'), backgroundColor: AppTheme.secondary),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Error al guardar'), backgroundColor: AppTheme.error),
      );
    }
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
              Color(0xFF0A0A2A),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 24),
                _buildAvatarPreview(),
                const SizedBox(height: 24),
                _buildNameField(),
                const SizedBox(height: 24),
                _buildAvatarSelector(),
                const SizedBox(height: 24),
                _buildNotificationSettings(),
                const SizedBox(height: 32),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Text('EDITAR PERFIL', style: AppTheme.titleLarge.copyWith(letterSpacing: 2)),
      ],
    );
  }

  Widget _buildAvatarPreview() {
    return Column(
      children: [
        PlayerAvatar(
          radius: 48,
          avatarType: _selectedAvatar,
          displayName: _nameController.text.isNotEmpty ? _nameController.text : 'Tú',
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: TextFormField(
        controller: _nameController,
        style: AppTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: 'Tu nombre',
          prefixIcon: const Icon(Icons.person, color: AppTheme.primary),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSelector() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AVATAR', style: AppTheme.labelLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _avatars.map((a) {
              final isSelected = _selectedAvatar == a['type'];
              return GestureDetector(
                onTap: () => setState(() => _selectedAvatar = a['type'] as String),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? Border.all(color: AppTheme.primary, width: 2) : null,
                  ),
                  child: Column(
                    children: [
                      Icon(a['icon'] as IconData, size: 32, color: isSelected ? AppTheme.primary : AppTheme.darkGrey),
                      const SizedBox(height: 4),
                      Text(a['label'] as String, style: TextStyle(fontSize: 10, color: isSelected ? AppTheme.primary : AppTheme.darkGrey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECORDATORIO DIARIO', style: AppTheme.labelLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recordar registrar pasos', style: AppTheme.bodyMedium),
                    if (_notificationsEnabled)
                      Text('${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}', style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Switch(
                value: _notificationsEnabled,
                activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
                activeThumbColor: AppTheme.primary,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
            ],
          ),
          if (_notificationsEnabled) ...[
            const SizedBox(height: 12),
            Text('Hora del recordatorio', style: AppTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker('Hora', _reminderHour, (v) => _reminderHour = v, 0, 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePicker('Minuto', _reminderMinute, (v) => _reminderMinute = v, 0, 59, step: 15),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, int value, Function(int) onChanged, int min, int max, {int step = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: AppTheme.primary),
            onPressed: () {
              final newVal = value - step;
              if (newVal >= min) onChanged(newVal);
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
          Expanded(
            child: Text(
              value.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
              style: AppTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
            onPressed: () {
              final newVal = value + step;
              if (newVal <= max) onChanged(newVal);
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('GUARDAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
    );
  }
}
