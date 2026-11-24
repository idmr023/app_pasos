import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import 'sprint_play_screen.dart' show formatGameNumber;

/// Ranking global del Sprint: mejor puntuación de cada usuario (top 20).
class GameLeaderboardScreen extends StatefulWidget {
  const GameLeaderboardScreen({super.key});

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<GameProvider>().loadLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final entries = game.leaderboard;
    final meInTop = entries.any((e) => e.isMe);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking Sprint'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: game.loadLeaderboard,
        child: entries.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  if (game.isLoadingLeaderboard)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(children: [
                      const Icon(Icons.emoji_events_outlined, size: 56, color: AppTheme.darkGrey),
                      const SizedBox(height: 12),
                      Text('Aún no hay carreras registradas', style: AppTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('¡Sé el primero en el ranking!',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                    ]),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: entries.length + (meInTop || game.myRank == null ? 0 : 1),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == entries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tu posición: #${game.myRank} · ${formatGameNumber(game.bestScore)} pts',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleMedium.copyWith(color: AppTheme.primary),
                      ),
                    );
                  }
                  return GameLeaderboardTile(entry: entries[i]);
                },
              ),
      ),
    );
  }
}

/// Fila del ranking reutilizada por el hub.
class GameLeaderboardTile extends StatelessWidget {
  final GameLeaderboardEntry entry;

  const GameLeaderboardTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    const medals = [AppTheme.gold, Color(0xFFCBD5E1), Color(0xFFD97706)];
    final medal = entry.rank <= 3 ? medals[entry.rank - 1] : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isMe ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: entry.isMe ? AppTheme.primary : AppTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 24)
                : Text('#${entry.rank}',
                    style: const TextStyle(color: AppTheme.grey, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '${entry.username} (tú)' : entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Nivel ${entry.level}${entry.distance > 0 ? ' · ${formatGameNumber(entry.distance)} m' : ''}',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatGameNumber(entry.score),
            style: AppTheme.titleLarge.copyWith(color: medal ?? AppTheme.white),
          ),
        ],
      ),
    );
  }
}
