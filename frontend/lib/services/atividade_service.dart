import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class AtividadeService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  // 1. Listar Módulos (RF-012)
  static Future<List<Map<String, dynamic>>> getModulos() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/modulos'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching modulos: $e');
      return [];
    }
  }

  // 2. Listar Atividades por Módulo (RF-013)
  static Future<List<Map<String, dynamic>>> getAtividadesPorModulo(int moduloId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/modulos/$moduloId/atividades'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching atividades for modulo $moduloId: $e');
      return [];
    }
  }

  // 3. Obter Detalhes da Atividade (RF-014)
  static Future<Map<String, dynamic>?> getAtividadeDetail(String atividadeId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/atividades/$atividadeId'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching atividade detail: $e');
      return null;
    }
  }
}
