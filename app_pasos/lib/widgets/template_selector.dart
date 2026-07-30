import 'package:flutter/material.dart';
import '../models/route_card_template.dart';

class TemplateSelector extends StatelessWidget {
  final List<RouteCardTemplate> templates;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const TemplateSelector({
    super.key,
    required this.templates,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final t = templates[index];
          final isSelected = t.id == selectedId;
          return GestureDetector(
            onTap: () => onChanged(t.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected ? t.routeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: isSelected ? t.routeColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t.icon, color: isSelected ? t.routeColor : Colors.white38, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    t.name.split(' ')[0],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? t.routeColor : Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
