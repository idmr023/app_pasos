import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/xp_provider.dart';
import '../providers/gym_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/player_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  String _selectedAvatar = 'runner';
  String _selectedGoal = 'general';
  bool _isSaving = false;

  final _goalOptions = {
    'general': 'General',
    'lose_weight': 'Bajar de peso',
    'gain_muscle': 'Ganar músculo',
    'maintain': 'Mantener',
    'endurance': 'Resistencia',
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _weightController = TextEditingController(
      text: user?.weight != null && user!.weight > 0 ? user.weight.toStringAsFixed(0) : '',
    );
    _heightController = TextEditingController(
      text: user?.height != null && user!.height > 0 ? user.height.toStringAsFixed(0) : '',
    );
    _selectedAvatar = user?.avatar ?? 'runner';
    _selectedGoal = user?.goal ?? 'general';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GymProvider>().loadWeightAchievements();
      context.read<GymProvider>().loadPersonalRecords();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
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

    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();
    final weight = weightText.isNotEmpty ? double.tryParse(weightText) : null;
    final height = heightText.isNotEmpty ? double.tryParse(heightText) : null;

    if (weightText.isNotEmpty && (weight == null || weight < 20 || weight > 500)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un peso válido (20-500 kg)'), backgroundColor: AppTheme.error),
      );
      return;
    }

    if (heightText.isNotEmpty && (height == null || height < 50 || height > 300)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una altura válida (50-300 cm)'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      displayName: name,
      avatar: _selectedAvatar,
      weight: weight,
      height: height,
      goal: _selectedGoal,
    );

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
            _buildUserDataSection(),
            const SizedBox(height: 24),
            _buildAvatarSelector(),
            const SizedBox(height: 24),
            _buildRewardsSection(xpProv),
            const SizedBox(height: 24),
            _buildWeightAchievementsSection(),
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

  Widget _buildWeightAchievementsSection() {
    final gym = context.watch<GymProvider>();
    final achievements = gym.weightAchievements;
    if (achievements.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOGROS DE PESO', style: AppTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Máximo levantado: ${gym.maxKg.toInt()} kg',
            style: TextStyle(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...achievements.map((a) {
            final unlocked = a['unlocked'] as bool? ?? false;
            final title = a['title'] as String? ?? '';
            final description = a['description'] as String? ?? '';
            final minKg = a['minKg'] as int? ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: unlocked
                    ? AppTheme.gold.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unlocked
                      ? AppTheme.gold.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    unlocked ? Icons.emoji_events : Icons.lock,
                    color: unlocked ? AppTheme.gold : AppTheme.darkGrey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$minKg kg: $title', style: TextStyle(
                          color: unlocked ? Colors.white : AppTheme.darkGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                        Text(description, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (unlocked)
                    const Icon(Icons.check_circle, color: AppTheme.gold, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUserDataSection() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(
                radius: 36,
                avatarType: _selectedAvatar,
                displayName: _nameController.text.isNotEmpty ? _nameController.text : 'Tú',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  style: AppTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Tu nombre',
                    prefixIcon: const Icon(Icons.person, color: AppTheme.primary, size: 20),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('DATOS FÍSICOS', style: AppTheme.labelLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peso (kg)', style: AppTheme.bodySmall),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      style: AppTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: '75',
                        suffixText: 'kg',
                        prefixIcon: const Icon(Icons.monitor_weight, color: AppTheme.primary, size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Altura (cm)', style: AppTheme.bodySmall),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      style: AppTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: '175',
                        suffixText: 'cm',
                        prefixIcon: const Icon(Icons.height, color: AppTheme.primary, size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Meta fitness', style: AppTheme.bodySmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGoal,
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                icon: const Icon(Icons.expand_more, color: AppTheme.primary),
                style: AppTheme.bodyLarge,
                items: _goalOptions.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: AppTheme.bodyLarge),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedGoal = v);
                },
              ),
            ),
          ),
        ],
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