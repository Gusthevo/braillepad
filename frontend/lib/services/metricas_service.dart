import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class MetricasService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  // 1. Obter Status Colorido e Alertas do Aluno (RF-031, RF-032)
  static Future<Map<String, dynamic>?> getMetricasAluno(String alunoId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/metricas/alunos/$alunoId'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching metricas aluno: $e');
      return null;
    }
  }

  // 2. Obter Relatório Coletivo da Turma (RF-033)
  static Future<Map<String, dynamic>?> getMetricasTurma(String turmaId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/metricas/turmas/$turmaId'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching metricas turma: $e');
      return null;
    }
  }
}
