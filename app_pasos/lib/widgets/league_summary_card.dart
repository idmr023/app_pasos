import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../screens/leagues/league_screen.dart';
import 'league_division_badge.dart';

/// Tarjeta compacta de la liga semanal (división, puesto, puntos). Al tocarla abre [LeagueScreen].
/// Se carga sola: toma el token de [AuthProvider] en un post-frame callback.
class LeagueSummaryCard extends StatefulWidget {
  const LeagueSummaryCard({super.key});

  @override
  State<LeagueSummaryCard> createState() => _LeagueSummaryCardState();
}

class _LeagueSummaryCardState extends State<LeagueSummaryCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final token = context.read<AuthProvider>().token;
    final league = context.read<LeagueProvider>();
    if (token == null) return;
    league.setToken(token);
    await league.loadIfStale();
  }

  String _zoneLabel(String zone) {
    switch (zone) {
      case 'promote':
        return 'Zona de ascenso';
      case 'demote':
        return 'Zona de descenso';
      default:
        return 'Zona segura';
    }
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

  String _remaining(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>();
    final me = league.me;

    Widget content;
    if (!league.hasLoaded) {
      content = Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              league.error != null ? 'No se pudo cargar la liga. Toca para reintentar.' : 'Cargando tu liga semanal…',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ),
          if (league.isLoading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    } else {
      final zone = me?.zone ?? 'stay';
      content = Row(
        children: [
          LeagueDivisionBadge(division: league.division, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Liga ${league.division.name}',
                    style: AppTheme.titleMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '#${me?.rank ?? '-'} de ${league.standings.length} · ${me?.points ?? 0} pts',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _zoneColor(zone), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_zoneLabel(zone)} · termina en ${_remaining(league.timeRemaining)}',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.grey),
        ],
      );
    }

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (!league.hasLoaded && !league.isLoading) {
            await _load();
            return;
          }
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeagueScreen()));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: league.hasLoaded ? league.division.color.withValues(alpha: 0.4) : AppTheme.border),
          ),
          child: content,
        ),
      ),
    );
  }
}
