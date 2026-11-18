import 'package:flutter/material.dart';
import '../models/route_card_template.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Economía de pasos: saldo, movimientos, tienda, inventario y equipado.
///
/// Como main_shell no lo inicializa, cada pantalla que lo usa llama a
/// [setToken] + [loadAll] en un post-frame callback (igual que GameHubScreen).
class WalletProvider extends ChangeNotifier {
  WalletService? _service;
  String? _token;

  int _balance = 0;
  int _earned = 0;
  int _spent = 0;
  List<WalletTransaction> _transactions = [];
  List<WalletItem> _catalog = [];
  Set<String> _owned = {'skin_classic'};
  String _equippedSkin = 'skin_classic';
  String? _equippedTrail;

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _purchasingId;
  String? _error;

  int get balance => _balance;
  int get earned => _earned;
  int get spent => _spent;
  List<WalletTransaction> get transactions => _transactions;
  List<WalletItem> get catalog => _catalog;
  String get equippedSkin => _equippedSkin;
  String? get equippedTrail => _equippedTrail;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get hasService => _service != null;
  String? get purchasingId => _purchasingId;
  String? get error => _error;

  List<WalletItem> itemsOfType(String type) => _catalog.where((i) => i.type == type).toList();

  bool owns(String itemId) => _owned.contains(itemId);

  WalletItem? item(String itemId) {
    for (final i in _catalog) {
      if (i.id == itemId) return i;
    }
    return null;
  }

  int priceOf(String itemId) => item(itemId)?.price ?? fallbackPrices[itemId] ?? 0;

  /// Portadas: las gratis siempre; las premium solo si se compraron.
  bool isTemplateUnlocked(TemplateType t) {
    final id = premiumCoverItems[t];
    return id == null || owns(id);
  }

  Set<TemplateType> get lockedTemplates =>
      premiumCoverItems.entries.where((e) => !owns(e.value)).map((e) => e.key).toSet();

  void setToken(String token) {
    if (_token == token && _service != null) return;
    if (_token != null) {
      // Otra sesión: no mostrar datos del usuario anterior.
      _balance = _earned = _spent = 0;
      _transactions = [];
      _owned = {'skin_classic'};
      _equippedSkin = 'skin_classic';
      _equippedTrail = null;
      _hasLoaded = false;
    }
    _token = token;
    _service = WalletService(token);
  }

  Future<void> loadAll() async {
    if (_service == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_service!.getWallet(), _service!.getCatalog()]);
      _applyWallet(results[0]);
      _applyCatalog(results[1]);
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Solo saldo y movimientos (más ligero que [loadAll]).
  Future<void> refreshBalance() async {
    if (_service == null) return;
    try {
      _applyWallet(await _service!.getWallet());
      _hasLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  void _applyWallet(Map<String, dynamic> data) {
    _balance = _int(data['balance']);
    _earned = _int(data['earned']);
    _spent = _int(data['spent']);
    _transactions = (data['transactions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalletTransaction.fromJson)
        .toList();
    final inv = data['inventory'];
    if (inv is List) _owned = {'skin_classic', ...inv.whereType<String>()};
    _applyEquipped(data['equipped']);
  }

  void _applyCatalog(Map<String, dynamic> data) {
    _catalog = (data['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalletItem.fromJson)
        .toList();
    for (final i in _catalog) {
      if (i.owned) _owned.add(i.id);
    }
    _applyEquipped(data['equipped']);
  }

  void _applyEquipped(dynamic eq) {
    if (eq is! Map) return;
    _equippedSkin = eq['skin'] as String? ?? 'skin_classic';
    _equippedTrail = eq['trail'] as String?;
    _catalog = [
      for (final i in _catalog)
        i.copyWith(
          owned: _owned.contains(i.id),
          equipped: i.slot == 'skin' ? i.id == _equippedSkin : (i.slot == 'trail' ? i.id == _equippedTrail : false),
        ),
    ];
  }

  /// Compra un artículo. Devuelve null si fue bien o el mensaje de error.
  Future<String?> purchase(String itemId) async {
    if (_service == null) return 'Inicia sesión para usar tus pasos';
    if (_purchasingId != null) return 'Espera a que termine la compra anterior';
    _purchasingId = itemId;
    notifyListeners();
    String? error;
    try {
      final data = await _service!.purchase(itemId);
      _balance = _int(data['balance']);
      _owned.add(itemId);
      _applyEquipped({'skin': _equippedSkin, 'trail': _equippedTrail});
      refreshBalance(); // historial actualizado en segundo plano
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    _purchasingId = null;
    notifyListeners();
    return error;
  }

  /// Equipa [itemId] en [slot] (`skin` | `trail`); null quita la estela.
  Future<String?> equip(String slot, String? itemId) async {
    if (_service == null) return 'Inicia sesión para equipar';
    try {
      final data = await _service!.equip(slot, itemId);
      _applyEquipped(data['equipped']);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Ajuste local del saldo tras una apuesta (el servidor devuelve el saldo nuevo).
  void setBalance(int balance) {
    _balance = balance;
    notifyListeners();
  }
}
