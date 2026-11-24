import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/league_provider.dart';
import '../../widgets/league_division_badge.dart';

/// Ligas semanales: división, cuenta regresiva, clasificación con zonas y celebración de resultado.
/// Reglas en docs/LEAGUES.md.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final token = context.read<AuthProvider>().token;
    final league = context.read<LeagueProvider>();
    if (token != null) league.setToken(token);
    await league.loadCurrent();
    if (!mounted) return;
    final pending = league.pendingResult;
    if (pending != null && !_showingResult) {
      _showingResult = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResultDialog(result: pending),
      );
      _showingResult = false;
      await league.ackPendingResult();
    }
  }

  void _openHistory() {
    final league = context.read<LeagueProvider>();
    league.loadHistory();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _HistorySheet(),
    );
  }

  void _openBreakdown(LeagueStanding s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BreakdownSheet(standing: s, rules: context.read<LeagueProvider>().pointsRules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Ligas semanales'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history_rounded),
            onPressed: league.hasLoaded ? _openHistory : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: !league.hasLoaded
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: league.error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(league.error!, textAlign: TextAlign.center, style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                              ],
                            ),
                          )
                        : const CircularProgressIndicator(),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _header(league),
                  const SizedBox(height: 12),
                  _ladder(league),
                  const SizedBox(height: 12),
                  if (league.me != null) _myPointsButton(league.me!),
                  const SizedBox(height: 16),
                  ..._standingRows(league),
                ],
              ),
      ),
    );
  }

  Widget _header(LeagueProvider league) {
    final d = league.division;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [d.color.withValues(alpha: 0.35), AppTheme.surface],
        ),
        border: Border.all(color: d.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          LeagueDivisionBadge(division: d, size: 76, animated: true),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Liga ${d.name}', style: AppTheme.headlineMedium.copyWith(color: AppTheme.white)),
                const SizedBox(height: 4),
                Text(
                  _zoneSummary(league),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppTheme.gold),
                    const SizedBox(width: 6),
                    _Countdown(endsAt: league.weekEndsAt, onFinished: _load),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _zoneSummary(LeagueProvider league) {
    final parts = <String>[];
    if (league.promoteCount > 0) parts.add('Top ${league.promoteCount} suben');
    if (league.demoteCount > 0) parts.add('últimos ${league.demoteCount} bajan');
    if (parts.isEmpty) parts.add('¡Defiende tu lugar en la cima!');
    return '${parts.join(' · ')} · ${league.standings.length}/${league.maxGroupSize} jugadores';
  }

  Widget _ladder(LeagueProvider league) {
    if (league.divisions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 62,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: league.divisions.map((d) {
          final current = d.index == league.division.index;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LeagueDivisionBadge(division: d, size: current ? 36 : 28, dimmed: d.index > league.division.index),
              const SizedBox(height: 4),
              Text(
                d.name,
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 10,
                  color: current ? d.color : AppTheme.darkGrey,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _myPointsButton(LeagueStanding me) {
    return OutlinedButton.icon(
      onPressed: () => _openBreakdown(me),
      icon: const Icon(Icons.insights_rounded),
      label: Text('Mis puntos: ${me.points} · ver desglose'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.white,
        side: const BorderSide(color: AppTheme.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<Widget> _standingRows(LeagueProvider league) {
    final rows = <Widget>[];
    final n = league.standings.length;
    final demoteStart = n - league.demoteCount; // rank > demoteStart ⇒ descenso por posición
    for (final s in league.standings) {
      if (s.rank == 1 && league.promoteCount > 0) rows.add(_zoneDivider('ZONA DE ASCENSO', AppTheme.tertiary, Icons.arrow_upward_rounded));
      if (s.rank == league.promoteCount + 1 && league.promoteCount > 0) rows.add(_zoneDivider('ZONA SEGURA', AppTheme.grey, Icons.remove_rounded));
      if (league.demoteCount > 0 && s.rank == demoteStart + 1) rows.add(_zoneDivider('ZONA DE DESCENSO', AppTheme.error, Icons.arrow_downward_rounded));
      rows.add(_row(s));
    }
    if (league.standings.any((s) => s.points == 0) && league.division.index > 0) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('Con 0 puntos al cierre de la semana se baja de división.',
            textAlign: TextAlign.center, style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey)),
      ));
    }
    return rows;
  }

  Widget _zoneDivider(String label, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withValues(alpha: 0.4), height: 1)),
        ],
      ),
    );
  }

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'promote':
        return AppTheme.tertiary;
      case 'demote':
        return AppTheme.error;
      default:
        return AppTheme.grey;
    }
  }

  Widget _row(LeagueStanding s) {
    final zc = _zoneColor(s.zone);
    final initial = s.displayName.isNotEmpty ? s.displayName.characters.first.toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: s.isMe ? AppTheme.primary.withValues(alpha: 0.16) : zc.withValues(alpha: s.zone == 'stay' ? 0.05 : 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openBreakdown(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: s.isMe ? AppTheme.primary : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text('${s.rank}',
                      style: AppTheme.titleMedium.copyWith(color: zc == AppTheme.grey ? AppTheme.white : zc, fontWeight: FontWeight.w800)),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.surfaceAlt,
                  child: Text(initial, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.isMe ? '${s.displayName} (Tú)' : s.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyLarge.copyWith(color: AppTheme.white, fontWeight: s.isMe ? FontWeight.w700 : FontWeight.w500),
                      ),
                      Text('@${s.username} · Nv ${s.level}', style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey)),
                    ],
                  ),
                ),
                Text('${s.points}', style: AppTheme.titleLarge.copyWith(color: AppTheme.white, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Text('pts', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuenta regresiva hasta el cierre de la semana (se redibuja sola cada segundo).
class _Countdown extends StatefulWidget {
  final DateTime? endsAt;
  final VoidCallback onFinished;

  const _Countdown({required this.endsAt, required this.onFinished});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final end = widget.endsAt;
      if (!_fired && end != null && DateTime.now().isAfter(end)) {
        _fired = true;
        widget.onFinished(); // nueva semana: el servidor cierra la anterior al recargar
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _fired = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = widget.endsAt;
    var d = end == null ? Duration.zero : end.difference(DateTime.now());
    if (d.isNegative) d = Duration.zero;
    String two(int v) => v.toString().padLeft(2, '0');
    final text = d.inDays > 0
        ? '${d.inDays}d ${two(d.inHours % 24)}h ${two(d.inMinutes % 60)}m ${two(d.inSeconds % 60)}s'
        : '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return Text('Termina en $text',
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

class _BreakdownSheet extends StatelessWidget {
  final LeagueStanding standing;
  final Map<String, dynamic> rules;

  const _BreakdownSheet({required this.standing, required this.rules});

  @override
  Widget build(BuildContext context) {
    final b = standing.breakdown;
    String r(String k, String fallback) => rules[k]?.toString() ?? fallback;
    Widget line(IconData icon, Color color, String title, String detail, int pts) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.18), child: Icon(icon, color: color)),
        title: Text(title, style: AppTheme.bodyLarge.copyWith(color: AppTheme.white)),
        subtitle: Text(detail, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
        trailing: Text('$pts pts', style: AppTheme.titleMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.w700)),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Text(standing.isMe ? 'Tus puntos de la semana' : 'Puntos de ${standing.displayName}',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.white)),
            const SizedBox(height: 8),
            line(Icons.directions_walk_rounded, AppTheme.primary, 'Pasos', '${b.steps} pasos · 1 pt cada ${r('stepsPerPoint', '100')} (máx. ${r('maxDailySteps', '30000')}/día)', b.stepsPoints),
            line(Icons.fitness_center_rounded, AppTheme.secondary, 'Gimnasio', '${b.workouts} entrenos · ${r('perWorkout', '50')} pts c/u (máx. ${r('maxWorkoutsPerDay', '2')}/día)', b.workoutsPoints),
            line(Icons.sports_esports_rounded, AppTheme.gold, 'Sprint', '${b.games} partidas · ${r('perGame', '10')} pts c/u (máx. ${r('maxGamesPerDay', '5')}/día)', b.gamesPoints),
            line(Icons.route_rounded, AppTheme.tertiary, 'Carreras en vivo', '${b.runKm.toStringAsFixed(2)} km · ${r('perKm', '20')} pts por km', b.runsPoints),
            const Divider(color: AppTheme.border),
            Row(
              children: [
                Text('Total', style: AppTheme.titleMedium.copyWith(color: AppTheme.grey)),
                const Spacer(),
                Text('${b.total} pts', style: AppTheme.headlineMedium.copyWith(color: AppTheme.white)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Los pasos del mismo día registrados en varios retos cuentan una sola vez.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey)),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>();
    String label(LeagueWeekResult h) {
      if (h.current || h.result == null) return 'En curso';
      switch (h.result) {
        case 'promoted':
          return 'Subiste a ${h.newDivision?.name ?? ''}';
        case 'demoted':
          return 'Bajaste a ${h.newDivision?.name ?? ''}';
        default:
          return 'Te mantuviste';
      }
    }

    IconData icon(String? result) => result == 'promoted'
        ? Icons.arrow_upward_rounded
        : result == 'demoted'
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;
    Color color(String? result) => result == 'promoted'
        ? AppTheme.tertiary
        : result == 'demoted'
            ? AppTheme.error
            : AppTheme.grey;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Historial de ligas', style: AppTheme.titleLarge.copyWith(color: AppTheme.white)),
              const SizedBox(height: 8),
              if (league.isLoadingHistory && league.history.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (league.history.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Aún no hay semanas registradas.', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: league.history.map((h) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: LeagueDivisionBadge(division: h.division, size: 34),
                        title: Text('${h.division.name} · ${h.week}', style: AppTheme.bodyLarge.copyWith(color: AppTheme.white)),
                        subtitle: Text(
                          h.finalRank != null
                              ? '#${h.finalRank} de ${h.groupSize} · ${h.finalPoints ?? 0} pts'
                              : '${h.groupSize} jugadores',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon(h.result), size: 16, color: color(h.result)),
                            const SizedBox(width: 4),
                            Text(label(h), style: AppTheme.bodySmall.copyWith(color: color(h.result))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo de resultado de la semana anterior. Ascenso = confeti (CustomPainter, sin dependencias).
class _ResultDialog extends StatefulWidget {
  final LeagueWeekResult result;

  const _ResultDialog({required this.result});

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final List<_ConfettiPiece> _pieces = _ConfettiPiece.generate(70);

  bool get _promoted => widget.result.result == 'promoted';

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final newDiv = r.newDivision ?? r.division;
    final String title;
    final String message;
    switch (r.result) {
      case 'promoted':
        title = '¡Subiste a ${newDiv.name}!';
        message = 'Terminaste #${r.finalRank ?? '-'} con ${r.finalPoints ?? 0} pts en ${r.division.name}.';
        break;
      case 'demoted':
        title = 'Bajaste a ${newDiv.name}';
        message = 'Terminaste #${r.finalRank ?? '-'} con ${r.finalPoints ?? 0} pts. ¡Esta semana es tu revancha!';
        break;
      default:
        title = 'Te mantienes en ${newDiv.name}';
        message = 'Terminaste #${r.finalRank ?? '-'} con ${r.finalPoints ?? 0} pts. ¡A por el ascenso!';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: newDiv.color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3, curve: Curves.elasticOut)),
                  child: LeagueDivisionBadge(division: newDiv, size: 96, animated: _promoted),
                ),
                const SizedBox(height: 18),
                Text(title, textAlign: TextAlign.center, style: AppTheme.headlineMedium.copyWith(color: AppTheme.white)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: newDiv.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_promoted ? '¡Genial!' : 'Vamos'),
                  ),
                ),
              ],
            ),
          ),
          if (_promoted)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_pieces, _controller.value)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfettiPiece {
  final double x; // 0..1 posición horizontal inicial
  final double drift; // desplazamiento lateral
  final double speed; // 0.7..1.3
  final double delay; // 0..0.3
  final double size;
  final double spin;
  final Color color;

  const _ConfettiPiece(this.x, this.drift, this.speed, this.delay, this.size, this.spin, this.color);

  static const _colors = [
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFFA855F7),
    Color(0xFFF8FAFC),
  ];

  static List<_ConfettiPiece> generate(int n) {
    final rnd = math.Random();
    return List.generate(n, (_) {
      return _ConfettiPiece(
        rnd.nextDouble(),
        (rnd.nextDouble() - 0.5) * 0.4,
        0.7 + rnd.nextDouble() * 0.6,
        rnd.nextDouble() * 0.3,
        4 + rnd.nextDouble() * 5,
        (rnd.nextDouble() - 0.5) * 20,
        _colors[rnd.nextInt(_colors.length)],
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;

  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final progress = local * p.speed;
      final y = -40 + progress * (size.height + 80);
      final x = (p.x + p.drift * progress + 0.03 * math.sin(progress * 12 + p.x * 10)) * size.width;
      final opacity = local > 0.85 ? (1 - local) / 0.15 : 1.0;
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * progress);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
