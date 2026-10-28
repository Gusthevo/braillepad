import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class TurmaService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  // 1. Listar Turmas do Professor (RF-007)
  static Future<List<Map<String, dynamic>>> getTurmas({bool incluirArquivadas = false}) async {
    try {
      final url = '${ApiService.baseUrl}/api/turmas?incluir_arquivadas=$incluirArquivadas';
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching turmas: $e');
      return [];
    }
  }

  // 2. Criar Nova Turma (RF-007)
  static Future<Map<String, dynamic>?> createTurma({
    required String nome,
    required String descricao,
    int? anoLetivo = 2026,
    String? anoEscolar = '1º Ano',
    String? turno = 'MANHA',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/turmas'),
            headers: _headers,
            body: jsonEncode({
              'nome': nome,
              'descricao': descricao,
              'ano_letivo': anoLetivo,
              'ano_escolar': anoEscolar,
              'turno': turno,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating turma: $e');
      return null;
    }
  }

  // 3. Obter Detalhes da Turma e Alunos (RF-008)
  static Future<Map<String, dynamic>?> getTurmaDetail(String turmaId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/turmas/$turmaId'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching turma detail: $e');
      return null;
    }
  }

  // 4. Arquivar Turma (RF-007)
  static Future<bool> arquivarTurma(String turmaId) async {
    try {
      final response = await http
          .post(Uri.parse('${ApiService.baseUrl}/api/turmas/$turmaId/arquivar'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error archiving turma: $e');
      return false;
    }
  }
}
