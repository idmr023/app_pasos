import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../config/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _question;
  bool _showQuestion = false;
  bool _showReset = false;
  bool _isLoading = false;
  String? _error;
  String? _token;

  @override
  void dispose() {
    _usernameController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _getQuestion() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Ingresa tu nombre de usuario');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/security-question/$username'),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        setState(() { _error = data['error'] ?? 'Usuario no encontrado'; _isLoading = false; });
        return;
      }

      setState(() {
        _question = data['question'];
        _showQuestion = true;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() { _error = 'Error al conectar con el servidor'; _isLoading = false; });
    }
  }

  Future<void> _verifyAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _error = 'Responde la pregunta de seguridad');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/verify-security'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'answer': answer,
        }),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        setState(() { _error = data['error'] ?? 'Respuesta incorrecta'; _isLoading = false; });
        return;
      }

      setState(() {
        _token = data['resetToken'];
        _showReset = true;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() { _error = 'Error al conectar con el servidor'; _isLoading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (newPass.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resetToken': _token,
          'newPassword': newPass,
        }),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        setState(() { _error = data['error'] ?? 'Error al restablecer'; _isLoading = false; });
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña restablecida correctamente'), backgroundColor: AppTheme.tertiary),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Error al conectar con el servidor'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF0A0A1A), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
                Text('RECUPERAR CONTRASEÑA', style: AppTheme.titleLarge.copyWith(letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('Responde tu pregunta de seguridad para restablecer tu contraseña',
                  style: AppTheme.bodyMedium),
                const SizedBox(height: 32),

                if (!_showQuestion) ...[
                  _buildField('Nombre de usuario', _usernameController, false),
                  const SizedBox(height: 16),
                  if (_error != null) _buildError(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _getQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('OBTENER PREGUNTA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                ],

                if (_showQuestion && !_showReset) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Text(_question ?? '', style: AppTheme.bodyLarge),
                  ),
                  const SizedBox(height: 16),
                  _buildField('Tu respuesta', _answerController, false),
                  const SizedBox(height: 16),
                  if (_error != null) _buildError(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('VERIFICAR', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                ],

                if (_showReset) ...[
                  _buildField('Nueva contraseña', _newPasswordController, true),
                  const SizedBox(height: 16),
                  _buildField('Confirmar contraseña', _confirmPasswordController, true),
                  const SizedBox(height: 16),
                  if (_error != null) _buildError(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('RESTABLECER', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool obscure) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.darkGrey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 14)),
    );
  }
}
