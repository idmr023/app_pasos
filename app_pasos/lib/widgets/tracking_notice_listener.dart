import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/tracking_provider.dart';

/// Muestra los avisos transitorios del [TrackingProvider] (mensaje
/// rechazado, GPS, reconexión) como SnackBar sin reemplazar el mapa ni el
/// chat, y pinta un banner mientras el socket está reconectando.
class TrackingNoticeListener extends StatefulWidget {
  final TrackingProvider provider;
  final Widget child;

  const TrackingNoticeListener({
    super.key,
    required this.provider,
    required this.child,
  });

  @override
  State<TrackingNoticeListener> createState() => _TrackingNoticeListenerState();
}

class _TrackingNoticeListenerState extends State<TrackingNoticeListener> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
  }

  @override
  void didUpdateWidget(covariant TrackingNoticeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_onProviderChanged);
      widget.provider.addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (widget.provider.notice == null) return;
    final message = widget.provider.takeNotice();
    if (message == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final showReconnecting =
        !widget.provider.isConnected && !widget.provider.trackingStopped;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child:
              showReconnecting
                  ? Container(
                    width: double.infinity,
                    color: AppTheme.error.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Reconectando con la sala…',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox(width: double.infinity),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
