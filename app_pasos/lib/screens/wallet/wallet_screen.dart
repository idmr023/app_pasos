import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../games/sprint/sprint_cosmetics.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/wallet_widgets.dart';

/// Monedero de pasos: saldo, tienda, inventario (equipar) e historial.
///
/// Los pasos registrados en los retos son la moneda de la app: se gastan en
/// la tienda o se apuestan en retos. Ver docs/WALLET.md.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _sections = [
    ('skin', 'Equipaciones del Sprint', Icons.checkroom_rounded),
    ('trail', 'Estelas del Sprint', Icons.auto_awesome_rounded),
    ('cover', 'Portadas premium', Icons.auto_awesome_mosaic_rounded),
    ('stickers', 'Packs de stickers', Icons.emoji_emotions_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ensureWalletLoaded(context, force: true));
  }

  Future<void> _reload() => ensureWalletLoaded(context, force: true);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : AppTheme.secondary),
    );
  }

  Future<void> _onItemTap(WalletItem item) async {
    final wallet = context.read<WalletProvider>();
    if (!item.owned) {
      final bought = await showWalletPurchaseSheet(
        context,
        itemId: item.id,
        title: item.name,
        subtitle: item.description,
        icon: _iconFor(item.type),
      );
      if (bought && mounted) _snack('¡${item.name} desbloqueado!');
      return;
    }
    if (item.slot == null) {
      _snack(item.type == 'cover'
          ? 'Ya puedes usar esta portada en Share Aura'
          : 'Ya puedes usar estos stickers en el editor de portadas');
      return;
    }
    // Equipar / quitar
    final String? target = item.equipped ? (item.slot == 'skin' ? 'skin_classic' : null) : item.id;
    if (item.equipped && item.id == 'skin_classic') return;
    final error = await wallet.equip(item.slot!, target);
    if (error != null) _snack(error, error: true);
  }

  IconData _iconFor(String type) {
    for (final s in _sections) {
      if (s.$1 == type) return s.$3;
    }
    return Icons.shopping_bag_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis pasos'),
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.grey,
            tabs: [
              Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Tienda'),
              Tab(icon: Icon(Icons.inventory_2_rounded, size: 20), text: 'Inventario'),
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 20), text: 'Historial'),
            ],
          ),
        ),
        body: Column(children: [
          _balanceHeader(wallet),
          if (wallet.error != null && !wallet.hasLoaded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(wallet.error!, style: AppTheme.bodySmall)),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ]),
            ),
          Expanded(
            child: TabBarView(children: [
              _shopTab(wallet),
              _inventoryTab(wallet),
              _historyTab(wallet),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _balanceHeader(WalletProvider wallet) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppTheme.gold.withValues(alpha: 0.22), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.directions_walk_rounded, color: AppTheme.gold),
          const SizedBox(width: 6),
          Text('SALDO DE PASOS', style: AppTheme.labelLarge.copyWith(color: AppTheme.gold, letterSpacing: 2)),
          const Spacer(),
          if (wallet.isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 8),
        AnimatedCounter(
          value: wallet.balance,
          style: AppTheme.counterLarge.copyWith(color: AppTheme.white),
          suffix: ' pasos',
        ),
        Text('${formatPasos(wallet.balance)} exactos', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
        const SizedBox(height: 10),
        Row(children: [
          _miniStat('Ganados', formatPasos(wallet.earned), AppTheme.tertiary),
          const SizedBox(width: 16),
          _miniStat('Gastados', formatPasos(wallet.spent), AppTheme.error),
        ]),
        const SizedBox(height: 8),
        Text('Cada paso registrado en tus retos suma (los mismos pasos en varios retos cuentan una vez).',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey)),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
      Text(value, style: AppTheme.titleMedium.copyWith(color: color)),
    ]);
  }

  Widget _shopTab(WalletProvider wallet) {
    if (!wallet.hasLoaded && wallet.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          for (final s in _sections) ...[
            _sectionTitle(s.$2, s.$3),
            _itemGrid(wallet.itemsOfType(s.$1).where((i) => i.price > 0 || i.slot != null).toList()),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _inventoryTab(WalletProvider wallet) {
    final owned = wallet.catalog.where((i) => i.owned).toList();
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text('Toca una equipación o estela para equiparla en el Sprint.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
          for (final s in _sections)
            if (owned.any((i) => i.type == s.$1)) ...[
              _sectionTitle(s.$2, s.$3),
              _itemGrid(owned.where((i) => i.type == s.$1).toList()),
            ],
          if (owned.length <= 1)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text('Aún no has comprado nada. ¡Mira la tienda!',
                  textAlign: TextAlign.center, style: AppTheme.bodyMedium),
            ),
        ],
      ),
    );
  }

  Widget _historyTab(WalletProvider wallet) {
    final txs = wallet.transactions;
    return RefreshIndicator(
      onRefresh: _reload,
      child: txs.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text('Sin movimientos todavía', textAlign: TextAlign.center, style: AppTheme.bodyMedium),
              ),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, i) {
                final t = txs[i];
                final positive = t.amount >= 0;
                final color = positive ? AppTheme.tertiary : AppTheme.error;
                final icon = switch (t.type) {
                  'purchase' => Icons.shopping_bag_rounded,
                  'wager_stake' => Icons.casino_rounded,
                  'wager_win' => Icons.emoji_events_rounded,
                  _ => Icons.undo_rounded,
                };
                final d = t.date;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
                  title: Text(t.label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
                  subtitle: Text(
                    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
                    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  ),
                  trailing: Text('${positive ? '+' : ''}${formatPasos(t.amount)}',
                      style: AppTheme.titleMedium.copyWith(color: color)),
                );
              },
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(title, style: AppTheme.titleMedium.copyWith(color: AppTheme.white)),
      ]),
    );
  }

  Widget _itemGrid(List<WalletItem> items) {
    if (items.isEmpty) {
      return Text('Cargando artículos...', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey));
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [for (final i in items) _itemTile(i)],
    );
  }

  Widget _itemTile(WalletItem item) {
    final wallet = context.watch<WalletProvider>();
    final busy = wallet.purchasingId == item.id;
    final borderColor = item.equipped
        ? AppTheme.tertiary
        : item.owned
            ? AppTheme.primary.withValues(alpha: 0.5)
            : AppTheme.border;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : () => _onItemTap(item),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: item.equipped ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _preview(item),
              const Spacer(),
              if (busy)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (item.equipped)
                const Icon(Icons.check_circle_rounded, color: AppTheme.tertiary, size: 20)
              else if (!item.owned)
                LockedPriceBadge(price: item.price),
            ]),
            const Spacer(),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.w700)),
            Text(
              item.equipped
                  ? 'Equipado'
                  : item.owned
                      ? (item.slot != null ? 'Tuyo · toca para equipar' : 'Desbloqueado')
                      : item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(color: item.owned ? AppTheme.tertiary : AppTheme.grey),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _preview(WalletItem item) {
    if (item.type == 'skin') {
      final skin = SprintSkin.byId(item.id);
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: skin.jersey,
          border: Border.all(color: skin.shoeAccent, width: 3),
        ),
        child: Icon(Icons.directions_run_rounded, size: 18, color: skin.shorts),
      );
    }
    if (item.type == 'trail') {
      final trail = SprintTrail.byId(item.id);
      final colors = trail?.colors ?? const [Colors.white, Colors.white];
      return Container(
        width: 44,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(colors: colors.length > 1 ? colors : [colors.first, colors.first]),
        ),
      );
    }
    return Icon(_iconFor(item.type), color: AppTheme.gold, size: 28);
  }
}
