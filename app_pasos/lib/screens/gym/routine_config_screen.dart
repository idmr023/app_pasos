import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/exercise.dart';
import '../../widgets/glass_card.dart';

class RoutineConfigResult {
  final String name;
  final int sets;
  final String reps;
  final int restTime;

  RoutineConfigResult({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restTime,
  });
}

class RoutineConfigScreen extends StatefulWidget {
  final List<Exercise> selectedExercises;

  const RoutineConfigScreen({super.key, required this.selectedExercises});

  @override
  State<RoutineConfigScreen> createState() => _RoutineConfigScreenState();
}

class _RoutineConfigScreenState extends State<RoutineConfigScreen> {
  late TextEditingController _nameController;
  int _sets = 3;
  String _reps = '12';
  int _restTime = 60;

  final _repsOptions = ['8', '10', '12', '15', '20', '30s', '45s', '60s', 'Al fallo'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF0A0A1A), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(2),
                      const SizedBox(height: 20),
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildGlobalConfig(),
                      const SizedBox(height: 16),
                      _buildExercisePreview(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current) {
    return Row(
      children: [
        _stepDot(1, 'Elegir', current > 1),
        _stepLine(current > 1),
        _stepDot(2, 'Configurar', current > 2),
        _stepLine(current > 2),
        _stepDot(3, 'Confirmar', false),
      ],
    );
  }

  Widget _stepDot(int number, String label, bool done) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppTheme.tertiary
                  : number == 2
                      ? AppTheme.primary
                      : AppTheme.darkGrey.withValues(alpha: 0.3),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: number == 2 ? AppTheme.primary : AppTheme.darkGrey,
              fontWeight: number == 2 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool done) {
    return Container(
      height: 2,
      width: 32,
      color: done ? AppTheme.tertiary : AppTheme.darkGrey.withValues(alpha: 0.3),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'CONFIGURAR RUTINA',
            style: AppTheme.titleLarge.copyWith(letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: _nameController,
        style: AppTheme.bodyLarge,
        maxLength: 30,
        decoration: const InputDecoration(
          labelText: 'Nombre de la rutina',
          hintText: 'Ej: Push Pull, Full Body...',
          prefixIcon: Icon(Icons.edit, color: AppTheme.primary, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildGlobalConfig() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONFIGURACIÓN GLOBAL', style: AppTheme.labelLarge),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth < 400
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildNumberInput('Series', _sets, (v) {
                              setState(() => _sets = v.clamp(1, 10));
                            })),
                            const SizedBox(width: 12),
                            Expanded(child: _buildRepsSelector()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildNumberInput('Descanso (s)', _restTime, (v) {
                              setState(() => _restTime = v.clamp(5, 300));
                            })),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildNumberInput('Series', _sets, (v) {
                          setState(() => _sets = v.clamp(1, 10));
                        })),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRepsSelector()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildNumberInput('Descanso (s)', _restTime, (v) {
                          setState(() => _restTime = v.clamp(5, 300));
                        })),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput(String label, int value, void Function(int) onChange) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.darkGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => onChange(value - 1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, size: 16, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onChange(value + 1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepsSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('Reps', style: TextStyle(fontSize: 10, color: AppTheme.darkGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _reps,
              isExpanded: true,
              isDense: true,
              dropdownColor: AppTheme.surface,
              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700),
              items: _repsOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _reps = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisePreview() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('EJERCICIOS SELECCIONADOS', style: AppTheme.labelLarge),
              const Spacer(),
              Text('${widget.selectedExercises.length}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.selectedExercises.map((ex) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ex.displayName,
                    style: AppTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un nombre para la rutina'), backgroundColor: AppTheme.error),
                );
                return;
              }
              Navigator.pop(context, RoutineConfigResult(
                name: name,
                sets: _sets,
                reps: _reps,
                restTime: _restTime,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
