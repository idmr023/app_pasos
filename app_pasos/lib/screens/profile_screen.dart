import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/xp_provider.dart';
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
    {'type': 'walker', 'icon': Icons.directions_walk, 'label': 'Caminante'},
    {'type': 'marathon', 'icon': Icons.terrain, 'label': 'Maratón'},
    {'type': 'ultra', 'icon': Icons.flash_on, 'label': 'Ultra'},
    {'type': 'legend', 'icon': Icons.auto_awesome, 'label': 'Leyenda'},
    {'type': 'titan', 'icon': Icons.star_border, 'label': 'Titán'},
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Error al guardar'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _claimReward(String rewardKey) async {
    final xpProv = context.read<XpProvider>();
    final authProv = context.read<AuthProvider>();
    final ok = await xpProv.claimReward(rewardKey);
    if (ok) {
      await authProv.refreshXp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensa reclamada'), backgroundColor: AppTheme.secondary),
      );
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final xpProv = context.watch<XpProvider>();
    final user = auth.user;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTopBar(),
            const SizedBox(height: 24),
            _buildLevelSection(user, xpProv),
            const SizedBox(height: 24),
            _buildRewardsSection(xpProv),
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
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('PERFIL', style: AppTheme.titleLarge.copyWith(letterSpacing: 2)),
        IconButton(
          icon: const Icon(Icons.logout, color: AppTheme.darkGrey),
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildLevelSection(user, XpProvider xpProv) {
    if (xpProv.error != null) {
      return GlassCard(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Error al cargar nivel', style: AppTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(xpProv.error!, style: AppTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<XpProvider>().loadXp(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('REINTENTAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = xpProv.progress;
    final earned = (progress['earned'] as num?)?.toDouble() ?? 0;
    final needed = (progress['needed'] as num?)?.toDouble() ?? 1000;

    return GlassCard(
      width: double.infinity,
      onTap: () => _showXpInfo(),
      child: Column(
        children: [
          Row(
            children: [
              PlayerAvatar(
                radius: 28,
                avatarType: user?.avatar ?? 'runner',
                displayName: null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'Usuario', style: AppTheme.titleMedium),
                    if (xpProv.title.isNotEmpty)
                      Text(xpProv.title, style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('NIVEL ${xpProv.level}', style: AppTheme.titleLarge.copyWith(color: AppTheme.primary)),
                  Text('${xpProv.xp} XP', style: AppTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: needed > 0 ? (earned / needed).clamp(0.0, 1.0) : 1.0,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${earned.toInt()} XP', style: AppTheme.bodySmall),
              Text('${needed.toInt()} XP', style: AppTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  void _showXpInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sistema de Experiencia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _xpInfoRow(Icons.directions_walk, 'Cada 10 pasos registrados = 1 XP'),
            const SizedBox(height: 12),
            _xpInfoRow(Icons.trending_up, 'Sube de nivel acumulando XP'),
            const SizedBox(height: 12),
            _xpInfoRow(Icons.emoji_events, 'Cada 10 niveles desbloqueas un título y avatar'),
            const SizedBox(height: 12),
            _xpInfoRow(Icons.fitness_center, 'Entrenar en el gimnasio también suma XP'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _xpInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildRewardsSection(XpProvider xpProv) {
    final rewards = xpProv.rewards;
    if (rewards.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECOMPENSAS', style: AppTheme.labelLarge),
          const SizedBox(height: 16),
          ...rewards.map((r) {
            final unlocked = r['unlocked'] as bool? ?? false;
            final claimed = r['claimed'] as bool? ?? false;
            final title = r['title'] as String? ?? '';
            final level = r['level'] as int? ?? 0;
            final avatar = r['avatar'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (unlocked && !claimed)
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (unlocked && !claimed)
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    unlocked ? (claimed ? Icons.check_circle : Icons.lock_open) : Icons.lock,
                    color: unlocked ? (claimed ? AppTheme.secondary : AppTheme.primary) : AppTheme.darkGrey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nivel $level: $title', style: TextStyle(
                          color: unlocked ? Colors.white : AppTheme.darkGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                        Text('Avatar: $avatar', style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (unlocked && !claimed)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _claimReward('reward_$level'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('RECLAMAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (claimed)
                    const Icon(Icons.check, color: AppTheme.secondary, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                      Icon(a['icon'] as IconData, size: 28, color: isSelected ? AppTheme.primary : AppTheme.darkGrey),
                      const SizedBox(height: 4),
                      Text(a['label'] as String, style: TextStyle(fontSize: 9, color: isSelected ? AppTheme.primary : AppTheme.darkGrey, fontWeight: FontWeight.w600)),
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