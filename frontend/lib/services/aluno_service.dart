import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class AlunoService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  // 1. Listar Alunos com filtro por turma (RF-009)
  static Future<List<Map<String, dynamic>>> getAlunos({
    String? turmaId,
    bool incluirArquivados = false,
  }) async {
    try {
      var url = '${ApiService.baseUrl}/api/alunos?incluir_arquivados=$incluirArquivados';
      if (turmaId != null && turmaId.isNotEmpty) {
        url += '&turma_id=$turmaId';
      }

      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching alunos: $e');
      return [];
    }
  }

  // 2. Cadastrar Novo Aluno (RF-009)
  static Future<Map<String, dynamic>?> createAluno({
    required String turmaAtualId,
    required String nome,
    required String sobrenome,
    String? matricula,
    String? dataNascimento,
    String? nivelBraille = 'INICIANTE',
    String? preferenciasAcessibilidade,
    String? observacoesPedagogicas,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/alunos'),
            headers: _headers,
            body: jsonEncode({
              'turma_atual_id': turmaAtualId,
              'nome': nome,
              'sobrenome': sobrenome,
              'matricula': matricula,
              'data_nascimento': dataNascimento,
              'nivel_braille': nivelBraille,
              'preferencias_acessibilidade': preferenciasAcessibilidade,
              'observacoes_pedagogicas': observacoesPedagogicas,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating aluno: $e');
      return null;
    }
  }

  // 3. Obter Modal / Detalhes do Aluno (RF-010)
  static Future<Map<String, dynamic>?> getAlunoDetail(String alunoId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/alunos/$alunoId'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching aluno detail: $e');
      return null;
    }
  }

  // 4. Transferir Aluno de Turma (RF-011)
  static Future<Map<String, dynamic>?> transferirAluno(
    String alunoId, {
    required String turmaDestinoId,
    String? motivo,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/alunos/$alunoId/transferir'),
            headers: _headers,
            body: jsonEncode({
              'turma_destino_id': turmaDestinoId,
              'motivo': motivo,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error transferring aluno: $e');
      return null;
    }
  }

  // 5. Arquivar Aluno (RF-011)
  static Future<bool> arquivarAluno(String alunoId) async {
    try {
      final response = await http
          .post(Uri.parse('${ApiService.baseUrl}/api/alunos/$alunoId/arquivar'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error archiving aluno: $e');
      return false;
    }
  }
}
