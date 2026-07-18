import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatService? _service;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;

  void setToken(String token) {
    _service = ChatService(token);
  }

  Future<void> loadHistory() async {
    if (_service == null) return;
    try {
      _messages = await _service!.getHistory();
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (_service == null || text.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: text.trim());
    _messages.add(userMsg);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _service!.sendMessage(text.trim());
      final reply = ChatMessage(
        role: 'assistant',
        content: data['reply'] as String,
      );
      _messages.add(reply);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearConversation() async {
    if (_service == null) return;
    try {
      await _service!.clearHistory();
      _messages = [];
      _error = null;
      notifyListeners();
    } catch (_) {}
  }
}
