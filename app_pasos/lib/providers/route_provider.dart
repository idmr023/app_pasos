import 'package:flutter/foundation.dart';
import '../models/route.dart';
import '../services/route_service.dart';

class RouteProvider with ChangeNotifier {
  String? _token;
  List<UserRoute> _routes = [];
  bool _isLoading = false;
  String? _error;

  List<UserRoute> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String token) {
    _token = token;
    loadRoutes();
  }

  Future<void> loadRoutes() async {
    if (_token == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = RouteService(_token!);
      _routes = await service.getRoutes();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRoute(Map<String, dynamic> body) async {
    if (_token == null) return false;
    try {
      final service = RouteService(_token!);
      final newRoute = await service.createRoute(body);
      _routes.insert(0, newRoute);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRouteDesign(String id, RouteDesign design) async {
    if (_token == null) return false;
    try {
      final service = RouteService(_token!);
      final updated = await service.updateRoute(id, {'design': design.toJson()});
      final index = _routes.indexWhere((r) => r.id == id);
      if (index != -1) {
        _routes[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRoute(String id) async {
    if (_token == null) return false;
    try {
      final service = RouteService(_token!);
      await service.deleteRoute(id);
      _routes.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> initStravaConnection() async {
    if (_token == null) return null;
    try {
      final service = RouteService(_token!);
      return await service.initStravaConnection();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> checkStravaStatus(String state) async {
    if (_token == null) return false;
    try {
      final service = RouteService(_token!);
      final result = await service.checkStravaStatus(state);
      return result['connected'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<int> syncStrava() async {
    if (_token == null) return 0;
    try {
      final service = RouteService(_token!);
      final count = await service.syncStravaActivities();
      await loadRoutes();
      return count;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return 0;
    }
  }

  Future<bool> disconnectStrava() async {
    if (_token == null) return false;
    try {
      final service = RouteService(_token!);
      await service.disconnectStrava();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
