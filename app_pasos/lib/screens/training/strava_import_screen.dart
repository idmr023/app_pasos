import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/training.dart';
import '../../providers/training_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_states.dart';
import 'training_widgets.dart';

/// Lista las actividades de Strava para que el atleta elija cuáles importar
/// al módulo Entrenamiento (máx. 15 por vez: cada una cuesta 1 petición de detalle).
class StravaImportScreen extends StatefulWidget {
  const StravaImportScreen({super.key});

  @override
  State<StravaImportScreen> createState() => _StravaImportScreenState();
}

class _StravaImportScreenState extends State<StravaImportScreen> {
  static const _maxSelection = 15;

  final List<StravaActivityItem> _items = [];
  final Set<int> _selected = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _importing = false;
  bool _onlyRuns = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    final svc = context.read<TrainingProvider>().service;
    if (svc == null || _loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await svc.getStravaActivities(_page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _items.addAll(r.items);
        _hasMore = r.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(StravaActivityItem a) {
    setState(() {
      if (_selected.contains(a.id)) {
        _selected.remove(a.id);
      } else if (_selected.length < _maxSelection) {
        _selected.add(a.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo $_maxSelection actividades por importación')),
        );
      }
    });
  }

  Future<void> _import() async {
    if (_selected.isEmpty) return;
    setState(() => _importing = true);
    final error = await context.read<TrainingProvider>().importFromStrava(_selected.toList());
    if (!mounted) return;
    setState(() => _importing = false);
    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(SnackBar(content: Text('${_selected.length} actividades importadas y analizadas')));
      Navigator.pop(context);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _onlyRuns ? _items.where((a) => a.sport == 'run' || a.sport == 'trail').toList() : _items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir de Strava'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => setState(() => _onlyRuns = !_onlyRuns),
            child: Text(_onlyRuns ? 'Solo carreras' : 'Todas', style: const TextStyle(color: stravaOrange)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _selected.isEmpty || _importing ? null : _import,
            style: ElevatedButton.styleFrom(
              backgroundColor: stravaOrange,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _importing
                ? const InlineSpinner()
                : Text(
                    _selected.isEmpty ? 'Selecciona actividades' : 'Importar y analizar (${_selected.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
      body: Builder(builder: (context) {
        if (_items.isEmpty && _loading) return const AppLoading();
        if (_items.isEmpty && _error != null) {
          return ErrorState(message: _error!, onRetry: _loadMore);
        }
        if (_items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: EmptyStateCard(icon: Icons.bolt, title: 'No hay actividades en Strava'),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _loadMore();
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: visible.length + 1,
            itemBuilder: (context, i) {
              if (i == visible.length) {
                if (_loading) return const Padding(padding: EdgeInsets.all(16), child: AppLoading(size: 24));
                if (_hasMore) {
                  return TextButton(onPressed: _loadMore, child: const Text('Cargar más'));
                }
                return const SizedBox(height: 16);
              }
              return _tile(visible[i]);
            },
          ),
        );
      }),
    );
  }

  Widget _tile(StravaActivityItem a) {
    final selected = _selected.contains(a.id);
    final pace = a.distance > 0 ? a.movingTime / (a.distance / 1000) : 0;
    return Card(
      color: selected ? stravaOrange.withValues(alpha: 0.12) : AppTheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? stravaOrange : AppTheme.border),
      ),
      child: CheckboxListTile(
        value: a.imported ? true : selected,
        onChanged: a.imported ? null : (_) => _toggle(a),
        activeColor: a.imported ? AppTheme.darkGrey : stravaOrange,
        secondary: Icon(sportIcon(a.sport), color: a.imported ? AppTheme.darkGrey : AppTheme.white),
        title: Text(a.name, style: AppTheme.titleMedium.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (a.startDate != null) formatShortDate(a.startDate!),
            if (a.distance > 0) '${(a.distance / 1000).toStringAsFixed(1)} km',
            formatDuration(a.movingTime),
            if (a.distance > 0) formatPace(pace),
            if (a.averageHeartRate > 0) '${a.averageHeartRate} ppm',
            if (a.imported) 'Ya importada',
          ].join(' · '),
          style: AppTheme.bodySmall.copyWith(color: a.imported ? AppTheme.tertiary : AppTheme.grey),
        ),
      ),
    );
  }
}
