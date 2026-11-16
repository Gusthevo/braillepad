import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static String? _token;
  static Map<String, dynamic>? _currentProfessor;

  static String? get token => _token;
  static Map<String, dynamic>? get currentProfessor => _currentProfessor;
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  // 0. Inicializar e carregar token salvo do disco (RF-002)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('dtae_jwt_token');
      final profJson = prefs.getString('dtae_professor_data');
      if (profJson != null && profJson.isNotEmpty) {
        _currentProfessor = jsonDecode(profJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error initializing AuthService: $e');
    }
  }

  static Future<void> _saveSession(String token, Map<String, dynamic> professor) async {
    _token = token;
    _currentProfessor = professor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dtae_jwt_token', token);
      await prefs.setString('dtae_professor_data', jsonEncode(professor));
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

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
        await _saveSession(data['access_token'], data['professor']);
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
        await _saveSession(data['access_token'], data['professor']);
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dtae_professor_data', jsonEncode(_currentProfessor));
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dtae_professor_data', jsonEncode(_currentProfessor));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  // 5. Logout
  static Future<void> logout() async {
    _token = null;
    _currentProfessor = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dtae_jwt_token');
      await prefs.remove('dtae_professor_data');
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }
}
