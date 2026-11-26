import 'package:flutter/material.dart';

/// Pantalla negra de "modo bolsillo" durante el tracking: evita toques
/// accidentales (chat, detener) y en pantallas OLED gasta mucha menos batería
/// que la UI normal mientras el wakelock mantiene la pantalla encendida.
/// Se desbloquea manteniendo presionado el candado 2 segundos.
class PocketLockOverlay extends StatefulWidget {
  final String elapsed;
  final double distanceKm;
  final double? remainingKm;
  final bool gpsStale;
  final bool offline;
  final VoidCallback onUnlock;

  const PocketLockOverlay({
    super.key,
    required this.elapsed,
    required this.distanceKm,
    required this.onUnlock,
    this.remainingKm,
    this.gpsStale = false,
    this.offline = false,
  });

  @override
  State<PocketLockOverlay> createState() => _PocketLockOverlayState();
}

class _PocketLockOverlayState extends State<PocketLockOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onUnlock();
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dim = Color(0xFF5A5A5A);
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(widget.elapsed, style: const TextStyle(color: dim, fontSize: 52, fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            Text('${widget.distanceKm.toStringAsFixed(2)} km', style: const TextStyle(color: dim, fontSize: 32)),
            if (widget.remainingKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Faltan ${widget.remainingKm!.toStringAsFixed(1)} km', style: const TextStyle(color: dim, fontSize: 18)),
              ),
            const SizedBox(height: 16),
            if (widget.gpsStale) const Text('Sin señal GPS', style: TextStyle(color: Color(0xFF8A6A00), fontSize: 14)),
            if (widget.offline) const Text('Sin internet · guardando puntos', style: TextStyle(color: Color(0xFF8A4A20), fontSize: 14)),
            const Spacer(flex: 3),
            GestureDetector(
              onTapDown: (_) => _hold.forward(from: 0),
              onTapUp: (_) => _hold.reverse(),
              onTapCancel: () => _hold.reverse(),
              child: SizedBox(
                width: 84,
                height: 84,
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 3,
                        color: const Color(0xFF808080),
                        backgroundColor: const Color(0xFF1A1A1A),
                      ),
                      const Icon(Icons.lock, color: dim, size: 32),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Mantén presionado 2 s para desbloquear', style: TextStyle(color: Color(0xFF444444), fontSize: 12)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
