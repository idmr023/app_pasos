import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../screens/wallet/wallet_screen.dart';

/// 12345 → "12.345"
String formatPasos(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Pone el token al [WalletProvider] y carga (o refresca) el monedero.
/// Llamar desde un post-frame callback, como hace GameHubScreen con su provider.
Future<void> ensureWalletLoaded(BuildContext context, {bool force = false}) async {
  final token = context.read<AuthProvider>().token;
  final wallet = context.read<WalletProvider>();
  if (token == null) return;
  wallet.setToken(token);
  if (force || !wallet.hasLoaded) {
    await wallet.loadAll();
  } else {
    await wallet.refreshBalance();
  }
}

/// Chip compacto con el saldo de pasos. Al tocarlo abre el monedero.
class WalletBalanceChip extends StatelessWidget {
  final VoidCallback? onTap;

  const WalletBalanceChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    return Material(
      color: AppTheme.gold.withValues(alpha: 0.14),
      shape: StadiumBorder(side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap ??
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_walk_rounded, size: 15, color: AppTheme.gold),
            const SizedBox(width: 4),
            Text(
              wallet.hasLoaded ? formatPasos(wallet.balance) : '—',
              style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Insignia "candado + precio" para artículos bloqueados.
class LockedPriceBadge extends StatelessWidget {
  final int price;
  final double fontSize;

  const LockedPriceBadge({super.key, required this.price, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: fontSize + 2, color: AppTheme.gold),
        const SizedBox(width: 4),
        Text(formatPasos(price),
            style: TextStyle(color: AppTheme.gold, fontSize: fontSize, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Hoja inferior para comprar un artículo con pasos. Devuelve true si se compró.
Future<bool> showWalletPurchaseSheet(
  BuildContext context, {
  required String itemId,
  required String title,
  String? subtitle,
  IconData icon = Icons.lock_open_rounded,
}) async {
  final bought = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PurchaseSheet(itemId: itemId, title: title, subtitle: subtitle, icon: icon),
  );
  return bought == true;
}

class _PurchaseSheet extends StatefulWidget {
  final String itemId;
  final String title;
  final String? subtitle;
  final IconData icon;

  const _PurchaseSheet({required this.itemId, required this.title, this.subtitle, required this.icon});

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  String? _error;

  Future<void> _buy() async {
    final wallet = context.read<WalletProvider>();
    final error = await wallet.purchase(widget.itemId);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final price = wallet.priceOf(widget.itemId);
    final owned = wallet.owns(widget.itemId);
    final enough = wallet.balance >= price;
    final busy = wallet.purchasingId == widget.itemId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(widget.icon, size: 40, color: AppTheme.gold),
          const SizedBox(height: 10),
          Text(widget.title, textAlign: TextAlign.center, style: AppTheme.titleLarge),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!, textAlign: TextAlign.center, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
          ],
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Precio: ', style: AppTheme.bodyMedium),
            Text('${formatPasos(price)} pasos',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text('Tu saldo: ${wallet.hasLoaded ? formatPasos(wallet.balance) : '—'} pasos',
              textAlign: TextAlign.center, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
          if (!enough && !owned && wallet.hasLoaded) ...[
            const SizedBox(height: 6),
            Text('Te faltan ${formatPasos(price - wallet.balance)} pasos. ¡Sal a caminar!',
                textAlign: TextAlign.center, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: owned
                ? () => Navigator.of(context).pop(true)
                : (busy || !enough || !wallet.hasService) ? null : _buy,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Icon(owned ? Icons.check_rounded : Icons.shopping_bag_rounded),
            label: Text(owned ? 'Ya es tuyo' : 'Desbloquear por ${formatPasos(price)} pasos'),
          ),
        ]),
      ),
    );
  }
}
