import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL configuration for Android Emulator vs Desktop/Web
  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000'; // Special loopback IP for Android Emulator
    }
    return 'http://localhost:8000';
  }

  // 1. Check API Health
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'api': 'error', 'status': response.statusCode};
    } catch (e) {
      return {'api': 'offline', 'error': e.toString()};
    }
  }

  // 2. Check BraillePad Hardware Health
  static Future<Map<String, dynamic>> checkPadHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/pad/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'integrado': false, 'estado': 'ERRO'};
    } catch (e) {
      return {'integrado': false, 'estado': 'OFFLINE'};
    }
  }

  // 3. Calculate DTAE Performance Score
  static Future<double?> calculateScore({
    required List<int> tentativasPorAlvo,
    String nivelAjuda = 'NENHUMA',
    String? compreensao = 'TOTAL',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/scoring'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tentativas_por_alvo': tentativasPorAlvo,
              'nivel_ajuda': nivelAjuda,
              'compreensao': compreensao,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['nota'] as num).toDouble();
      }
      return null;
    } catch (e) {
      debugPrint('Error calculating score: $e');
      return null;
    }
  }
}
