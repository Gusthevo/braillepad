import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static String? _token;
  static Map<String, dynamic>? _currentProfessor;

  static String? get token => _token;
  static Map<String, dynamic>? get currentProfessor => _currentProfessor;
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  // 1. Cadastrar Novo Professor (RF-001)
  static Future<Map<String, dynamic>> register({
    required String nome,
    required String sobrenome,
    required String email,
    required String senha,
    String? instituicao,
    String? especialidade,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': nome,
              'sobrenome': sobrenome,
              'email': email,
              'senha': senha,
              'instituicao': instituicao,
              'especialidade': especialidade,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        _token = data['access_token'];
        _currentProfessor = data['professor'];
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Erro no cadastro.'};
      }
    } catch (e) {
      debugPrint('Register error: $e');
      return {'success': false, 'message': 'Não foi possível conectar ao servidor.'};
    }
  }

  // 2. Autenticar Login (RF-002)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'senha': senha,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        _token = data['access_token'];
        _currentProfessor = data['professor'];
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'E-mail ou senha incorretos.'};
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return {'success': false, 'message': 'Não foi possível conectar ao servidor.'};
    }
  }

  // 3. Obter Perfil do Professor Logado (RF-003)
  static Future<Map<String, dynamic>?> fetchProfile() async {
    if (!isLoggedIn) return null;
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _currentProfessor = jsonDecode(response.body) as Map<String, dynamic>;
        return _currentProfessor;
      }
      return null;
    } catch (e) {
      debugPrint('Fetch profile error: $e');
      return null;
    }
  }

  // 4. Atualizar Perfil / Foto de Perfil (RF-003)
  static Future<bool> updateProfile({
    String? nome,
    String? sobrenome,
    String? fotoUrl,
    String? instituicao,
    String? especialidade,
  }) async {
    if (!isLoggedIn) return false;
    try {
      final response = await http
          .patch(
            Uri.parse('${ApiService.baseUrl}/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              if (nome != null) 'nome': nome,
              if (sobrenome != null) 'sobrenome': sobrenome,
              if (fotoUrl != null) 'foto_url': fotoUrl,
              if (instituicao != null) 'instituicao': instituicao,
              if (especialidade != null) 'especialidade': especialidade,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        _currentProfessor = jsonDecode(response.body) as Map<String, dynamic>;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  // 5. Logout
  static void logout() {
    _token = null;
    _currentProfessor = null;
  }
}
