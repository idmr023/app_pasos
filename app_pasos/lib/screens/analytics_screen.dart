import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/challenge_provider.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late String _challengeId;
  int _selectedPeriod = 0;
  final _periods = ['ESTA SEMANA', 'ESTE MES', 'MES PASADO'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _challengeId = ModalRoute.of(context)!.settings.arguments as String;
    _loadData();
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    final challengeProv = context.read<ChallengeProvider>();
    challengeProv.setToken(auth.token!);
    challengeProv.loadChallengeDetail(_challengeId);

    final now = DateTime.now();
    String? start, end;

    if (_selectedPeriod == 0) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      start = DateFormat('yyyy-MM-dd').format(weekStart);
      end = DateFormat('yyyy-MM-dd').format(weekEnd);
    } else if (_selectedPeriod == 1) {
      start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
    } else {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      start = DateFormat('yyyy-MM-dd').format(prevMonth);
      end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 0));
    }

    challengeProv.loadAnalytics(_challengeId, start: start, end: end);
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
          child: Consumer<ChallengeProvider>(
            builder: (context, challengeProv, _) {
              final detail = challengeProv.challengeDetail;
              final challenge = detail?['challenge'];
              final creator = challenge?['creator'];
              final opponent = challenge?['opponent'];
              final currentUser = context.read<AuthProvider>().user;
              final isCreator = creator != null && (creator['id'] == currentUser?.id || creator['_id'] == currentUser?.id);
              final userLabel = isCreator ? (creator?['displayName'] ?? 'Tú') : (opponent?['displayName'] ?? 'Tú');
              final opponentLabel = isCreator ? (opponent?['displayName'] ?? 'Oponente') : (creator?['displayName'] ?? 'Oponente');

              return Column(
                children: [
                  _buildTopBar(challenge),
                  const SizedBox(height: 8),
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: challengeProv.isAnalyticsLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : challengeProv.analytics.isEmpty
                            ? _buildEmptyState()
                            : _buildChart(challengeProv, userLabel, opponentLabel),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(challenge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              challenge?['code'] ?? 'Estadísticas',
              textAlign: TextAlign.center,
              style: AppTheme.titleLarge.copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: List.generate(_periods.length, (i) {
            final isSelected = _selectedPeriod == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedPeriod = i);
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _periods[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.darkGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 64, color: AppTheme.darkGrey),
          const SizedBox(height: 16),
          Text('Sin datos en este período', style: AppTheme.bodyMedium),
          const SizedBox(height: 8),
          Text('Registra pasos para ver estadísticas', style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildChart(ChallengeProvider challengeProv, String userLabel, String opponentLabel) {
    final entries = challengeProv.analytics;
    final Map<String, Map<String, int>> dailyData = {};

    for (final entry in entries) {
      final date = entry['date'] as String;
      final dateKey = date.substring(5, 10);
      final userId = entry['user'] is Map
          ? (entry['user'] as Map)['_id']?.toString() ?? ''
          : entry['user'].toString();
      final steps = entry['steps'] as int;

      dailyData.putIfAbsent(dateKey, () => {});
      dailyData[dateKey]![userId] = (dailyData[dateKey]![userId] ?? 0) + steps;
    }

    final sortedDates = dailyData.keys.toList()..sort();
    final currentUser = context.read<AuthProvider>().user;
    final detail = challengeProv.challengeDetail;
    final creator = detail?['challenge']?['creator'];
    final opponent = detail?['challenge']?['opponent'];
    final creatorId = creator?['id']?.toString() ?? creator?['_id']?.toString() ?? '';
    final opponentId = opponent?['id']?.toString() ?? opponent?['_id']?.toString() ?? '';

    final user1Id = currentUser?.id ?? '';
    final user2Id = user1Id == creatorId ? opponentId : creatorId;

    int maxSteps = 0;
    for (final day in dailyData.values) {
      final total = (day[user1Id] ?? 0) + (day[user2Id] ?? 0);
      if (total > maxSteps) maxSteps = total;
    }
    if (maxSteps == 0) maxSteps = 1000;
    maxSteps = ((maxSteps / 1000).ceil() * 1000);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassCard(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(AppTheme.primary, userLabel),
                  const SizedBox(width: 24),
                  _legendDot(AppTheme.tertiary, opponentLabel),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxSteps.toDouble(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final day = sortedDates[group.x.toInt()];
                          final label = rodIndex == 0 ? userLabel : opponentLabel;
                          return BarTooltipItem(
                            '$day\n$label: ${rod.toY.toInt()}',
                            TextStyle(color: rodIndex == 0 ? AppTheme.primary : AppTheme.tertiary, fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= sortedDates.length) return const SizedBox();
                            final day = sortedDates[idx];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                day.substring(3),
                                style: TextStyle(color: AppTheme.darkGrey, fontSize: 9, fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                '${(value / 1000).toInt()}K',
                                style: TextStyle(color: AppTheme.darkGrey, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: (maxSteps / 4).ceilToDouble(),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withValues(alpha: 0.04),
                        strokeWidth: 1,
                      ),
                      drawVerticalLine: false,
                    ),
                    barGroups: List.generate(sortedDates.length, (i) {
                      final day = sortedDates[i];
                      final data = dailyData[day]!;
                      final userSteps = (data[user1Id] ?? 0).toDouble();
                      final opponentSteps = (data[user2Id] ?? 0).toDouble();

                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: userSteps > 0 ? userSteps : 0.1,
                            color: AppTheme.primary,
                            width: sortedDates.length > 14 ? 6 : 10,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: opponentSteps > 0 ? opponentSteps : 0.1,
                            color: AppTheme.tertiary,
                            width: sortedDates.length > 14 ? 6 : 10,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
