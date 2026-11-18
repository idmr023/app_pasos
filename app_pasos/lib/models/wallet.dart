import 'route_card_template.dart';

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Artículo de la tienda de pasos (catálogo definido en el servidor).
class WalletItem {
  final String id;
  final String type; // skin | trail | cover | stickers
  final String? slot; // skin | trail (equipables)
  final String name;
  final String description;
  final int price;
  final bool owned;
  final bool equipped;

  const WalletItem({
    required this.id,
    required this.type,
    this.slot,
    required this.name,
    required this.description,
    required this.price,
    this.owned = false,
    this.equipped = false,
  });

  factory WalletItem.fromJson(Map<String, dynamic> json) => WalletItem(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        slot: json['slot'] as String?,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: _int(json['price']),
        owned: json['owned'] == true,
        equipped: json['equipped'] == true,
      );

  WalletItem copyWith({bool? owned, bool? equipped}) => WalletItem(
        id: id,
        type: type,
        slot: slot,
        name: name,
        description: description,
        price: price,
        owned: owned ?? this.owned,
        equipped: equipped ?? this.equipped,
      );
}

/// Movimiento del libro de pasos.
class WalletTransaction {
  final String type; // purchase | wager_stake | wager_win | wager_refund
  final int amount;
  final String label;
  final String ref;
  final DateTime date;

  const WalletTransaction({
    required this.type,
    required this.amount,
    required this.label,
    required this.ref,
    required this.date,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        type: json['type'] as String? ?? '',
        amount: _int(json['amount']),
        label: json['label'] as String? ?? '',
        ref: json['ref'] as String? ?? '',
        date: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// Portadas premium: id del artículo de la tienda por plantilla.
/// Las demás portadas (Revista, Minimal, Polaroid) y los moldes clásicos son gratis.
const Map<TemplateType, String> premiumCoverItems = {
  TemplateType.neonNocturno: 'cover_neon_nocturno',
  TemplateType.atardecer: 'cover_atardecer',
  TemplateType.podio: 'cover_podio',
  TemplateType.dorsal: 'cover_dorsal',
  TemplateType.fotoMapa: 'cover_foto_mapa',
};

/// Precios por defecto (por si el catálogo aún no cargó). El servidor manda.
const Map<String, int> fallbackPrices = {
  'cover_neon_nocturno': 8000,
  'cover_atardecer': 8000,
  'cover_podio': 10000,
  'cover_dorsal': 10000,
  'cover_foto_mapa': 12000,
  'stickers_running': 4000,
  'stickers_fiesta': 4000,
  'stickers_pro': 6000,
};

/// Contenido de los packs de stickers premium del editor de portadas.
class StickerPack {
  final String itemId;
  final String name;
  final List<String> emojis;
  final List<String> badges;

  const StickerPack({required this.itemId, required this.name, this.emojis = const [], this.badges = const []});
}

const List<StickerPack> premiumStickerPacks = [
  StickerPack(
    itemId: 'stickers_running',
    name: 'Pack Running',
    emojis: ['🏃‍♀️', '🏅', '⏱️', '🗺️', '🌧️', '🏔️', '💨', '🦵'],
  ),
  StickerPack(
    itemId: 'stickers_fiesta',
    name: 'Pack Fiesta',
    emojis: ['🥳', '🎊', '🍾', '🤩', '👑', '💥', '🌈', '✨'],
  ),
  StickerPack(
    itemId: 'stickers_pro',
    name: 'Pack Pro',
    badges: ['SUB 20', 'SUB 45', 'MARATONISTA', 'ULTRA', 'CERO EXCUSAS', 'KM 42'],
  ),
];
