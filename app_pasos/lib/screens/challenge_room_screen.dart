import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/step_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/step_ring.dart';
import '../widgets/player_avatar.dart';
import '../widgets/animated_counter.dart';
import '../widgets/step_input_dialog.dart';


class ChallengeRoomScreen extends StatefulWidget {
  const ChallengeRoomScreen({super.key});

  @override
  State<ChallengeRoomScreen> createState() => _ChallengeRoomScreenState();
}

class _ChallengeRoomScreenState extends State<ChallengeRoomScreen> {
  late String _challengeId;
  DateTime _selectedMonth = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _challengeId = ModalRoute.of(context)!.settings.arguments as String;
    _loadData();
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (auth.token != null) {
      context.read<StepProvider>().setToken(auth.token!);
      context.read<ChallengeProvider>().setToken(auth.token!);
      context.read<ChallengeProvider>().loadChallengeDetail(_challengeId);
      context.read<StepProvider>().loadCalendar(
        _challengeId,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );
    }
  }

  void _prevMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
    _loadCalendar();
  }

  void _nextMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
    _loadCalendar();
  }

  void _loadCalendar() {
    context.read<StepProvider>().loadCalendar(
      _challengeId,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );
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
          child: Consumer2<ChallengeProvider, StepProvider>(
            builder: (context, challengeProv, stepProv, _) {
              if (challengeProv.isLoading && challengeProv.challengeDetail == null) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              final detail = challengeProv.challengeDetail;
              final challenge = detail?['challenge'];
              final creator = challenge?['creator'];
              final opponent = challenge?['opponent'];

              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTopBar(challengeProv, challenge, creator, opponent),
                      const SizedBox(height: 16),
                      _buildHeader(challenge, creator, opponent),
                      const SizedBox(height: 16),
                      _buildScoreboard(stepProv, creator, opponent),
                      const SizedBox(height: 16),
                      _buildCalendar(stepProv, challengeProv),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmAction(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF00101A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(title.contains('Eliminar') ? 'Eliminar' : 'Salir', style: const TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildTopBar(ChallengeProvider challengeProv, challenge, creator, opponent) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id;
    final isCreator = creator != null && (creator['id'] == currentUserId || creator['_id'] == currentUserId);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/analytics', arguments: _challengeId),
              icon: const Icon(Icons.bar_chart, size: 18, color: AppTheme.secondary),
              label: const Text('ESTADÍSTICAS', style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isCreator ? Icons.delete_outline : Icons.logout,
                color: isCreator ? const Color(0xFFFF4D00) : AppTheme.darkGrey,
              ),
              tooltip: isCreator ? 'Eliminar reto' : 'Salir del reto',
              onPressed: () async {
                final confirmed = await _confirmAction(
                  isCreator ? 'Eliminar reto' : 'Salir del reto',
                  isCreator
                      ? '¿Estás seguro? Se eliminarán todos los datos del reto.'
                      : '¿Estás seguro de que quieres salir del reto?',
                );
                if (!confirmed || !mounted) return;

                final success = isCreator
                    ? await challengeProv.deleteChallenge(_challengeId)
                    : await challengeProv.leaveChallenge(_challengeId);

                if (mounted) {
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(challengeProv.error ?? 'Error'),
                        backgroundColor: const Color(0xFFFF4D00),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(challenge, creator, opponent) {
    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          Text(challenge?['code'] ?? '', style: AppTheme.labelLarge.copyWith(letterSpacing: 6)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              PlayerAvatar(
                radius: 36,
                avatarType: creator?['avatar'] ?? 'runner',
                displayName: creator?['displayName'],
                isLeading: true,
                glowColor: AppTheme.primary,
              ),
              Column(
                children: [
                  Text('VS', style: AppTheme.headlineLarge.copyWith(fontSize: 24, color: AppTheme.primary)),
                  Text('en duelo', style: AppTheme.bodySmall),
                ],
              ),
              PlayerAvatar(
                radius: 36,
                avatarType: opponent?['avatar'] ?? 'runner',
                displayName: opponent?['displayName'],
                glowColor: AppTheme.tertiary,
              ),
            ],
          ),
          if (opponent == null) ...[
            const SizedBox(height: 12),
            Text('Esperando oponente...', style: AppTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreboard(StepProvider stepProv, creator, opponent) {
    if (creator == null || opponent == null) return const SizedBox.shrink();

    int creatorTotal = 0;
    int opponentTotal = 0;
    for (final day in stepProv.calendar) {
      for (final entry in day.entries) {
        if (entry.userId == creator['id'] || entry.userId == creator['_id']) {
          creatorTotal += entry.steps;
        } else {
          opponentTotal += entry.steps;
        }
      }
    }

    final maxSteps = (creatorTotal + opponentTotal) > 0 ? (creatorTotal + opponentTotal).toDouble() : 1.0;

    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          Text('TOTAL DEL MES', style: AppTheme.labelLarge),
          const SizedBox(height: 16),
          DualStepRing(
            size: 200,
            userProgress: creatorTotal / maxSteps,
            opponentProgress: opponentTotal / maxSteps,
            userSteps: creatorTotal.toDouble(),
            opponentSteps: opponentTotal.toDouble(),
            userName: creator['displayName'] ?? '',
            opponentName: opponent['displayName'] ?? '',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPlayerTotal(creator['displayName'] ?? '', creatorTotal, opponentTotal >= creatorTotal, AppTheme.primary)),
              Container(height: 40, width: 1, color: Colors.white.withValues(alpha: 0.06)),
              Expanded(child: _buildPlayerTotal(opponent['displayName'] ?? '', opponentTotal, creatorTotal >= opponentTotal, AppTheme.tertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTotal(String name, int total, bool isBehind, Color color) {
    return Column(
      children: [
        AnimatedCounter(
          value: total,
          style: AppTheme.counterMedium.copyWith(color: isBehind ? AppTheme.darkGrey : color),
        ),
        const SizedBox(height: 4),
        Text(name, style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _buildCalendar(StepProvider stepProv, ChallengeProvider challengeProv) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;

    final detail = challengeProv.challengeDetail;
    final challenge = detail?['challenge'];
    final creator = challenge?['creator'];
    final opponent = challenge?['opponent'];

    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: _prevMonth,
              ),
              Text(_getMonthName(_selectedMonth.month), style: AppTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((d) => SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(d, style: TextStyle(color: AppTheme.darkGrey, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(((firstWeekday - 1) + daysInMonth + 6) ~/ 7, (rowIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (colIndex) {
                final dayNum = rowIndex * 7 + colIndex - (firstWeekday - 2);
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 36, height: 64);
                }

                final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                final calendarDay = stepProv.calendar.where((d) => d.date == dateStr).firstOrNull;

                int creatorSteps = 0;
                int opponentSteps = 0;
                if (calendarDay != null) {
                  for (final entry in calendarDay.entries) {
                    if (creator != null && (entry.userId == creator['id'] || entry.userId == creator['_id'])) {
                      creatorSteps = entry.steps;
                    } else if (opponent != null) {
                      opponentSteps = entry.steps;
                    }
                  }
                }

                final isToday = DateTime.now().day == dayNum &&
                    DateTime.now().month == _selectedMonth.month &&
                    DateTime.now().year == _selectedMonth.year;

                final maxDaySteps = (creatorSteps + opponentSteps) > 0 ? (creatorSteps + opponentSteps).toDouble() : 1.0;
                final creatorRatio = creatorSteps / maxDaySteps;
                final opponentRatio = opponentSteps / maxDaySteps;

                return GestureDetector(
                  onTap: () => _showStepInput(dayNum),
                  child: Container(
                    width: 36,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.primary.withValues(alpha: 0.08) : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday ? Border.all(color: AppTheme.primary.withValues(alpha: 0.2)) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: isToday ? AppTheme.primary : Colors.white70,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (creatorSteps > 0 || opponentSteps > 0)
                          SizedBox(
                            width: 24,
                            height: 20,
                            child: CustomPaint(
                              painter: _MiniBarPainter(
                                creatorRatio: creatorRatio,
                                opponentRatio: opponentRatio,
                                creatorColor: AppTheme.primary,
                                opponentColor: AppTheme.tertiary,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 20),
                        if (creatorSteps > 0 || opponentSteps > 0)
                          Text(
                            _compactSteps(creatorSteps + opponentSteps),
                            style: TextStyle(color: AppTheme.darkGrey, fontSize: 7, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showStepInput(int day) async {
    final stepProv = context.read<StepProvider>();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StepInputDialog(
        date: DateTime(_selectedMonth.year, _selectedMonth.month, day),
      ),
    );

    if (result != null && mounted) {
      await stepProv.saveSteps(
        _challengeId,
        DateTime(_selectedMonth.year, _selectedMonth.month, day),
        result,
      );
    }
  }

  String _getMonthName(int month) {
    const months = ['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
                     'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    return months[month - 1];
  }

  String _compactSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(0)}K';
    return steps.toString();
  }
}

class _MiniBarPainter extends CustomPainter {
  final double creatorRatio;
  final double opponentRatio;
  final Color creatorColor;
  final Color opponentColor;

  _MiniBarPainter({
    required this.creatorRatio,
    required this.opponentRatio,
    required this.creatorColor,
    required this.opponentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width;
    final barHeight = size.height * 0.7;
    final yPos = size.height - barHeight;

    if (creatorRatio > 0) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, yPos, barWidth * creatorRatio, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = creatorColor.withValues(alpha: 0.8));
    }

    if (opponentRatio > 0) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, yPos, barWidth * opponentRatio, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = opponentColor.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(_MiniBarPainter oldDelegate) =>
      oldDelegate.creatorRatio != creatorRatio || oldDelegate.opponentRatio != opponentRatio;
}
