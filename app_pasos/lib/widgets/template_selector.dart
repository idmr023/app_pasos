import 'package:flutter/material.dart';
import '../models/route_card_template.dart';

/// Tira horizontal de miniaturas (icono + nombre) para elegir plantilla.
/// Se usa debajo del carrusel del editor de portadas y hace auto-scroll
/// hasta la plantilla seleccionada.
class TemplateSelector extends StatefulWidget {
  final List<TemplateType> templates;
  final TemplateType selected;
  final ValueChanged<TemplateType> onChanged;

  /// Plantillas premium aún no compradas (muestran un candado).
  final Set<TemplateType> locked;

  const TemplateSelector({
    super.key,
    required this.templates,
    required this.selected,
    required this.onChanged,
    this.locked = const {},
  });

  @override
  State<TemplateSelector> createState() => _TemplateSelectorState();
}

class _TemplateSelectorState extends State<TemplateSelector> {
  static const double _itemWidth = 76;
  static const double _gap = 10;
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(TemplateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && _controller.hasClients) {
      final index = widget.templates.indexOf(widget.selected);
      final viewport = _controller.position.viewportDimension;
      final target = (16 + index * (_itemWidth + _gap) - (viewport - _itemWidth) / 2)
          .clamp(0.0, _controller.position.maxScrollExtent);
      _controller.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final t = widget.templates[index];
          final isSelected = t == widget.selected;
          final color = t.accent.computeLuminance() < 0.05 ? Colors.white : t.accent;
          return GestureDetector(
            onTap: () => widget.onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _itemWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: isSelected ? color.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.15 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(widget.locked.contains(t) ? Icons.lock_rounded : t.icon,
                        color: widget.locked.contains(t)
                            ? const Color(0xFFFFD166)
                            : (isSelected ? color : Colors.white38),
                        size: 22),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      t.displayName,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? color : Colors.white54,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
