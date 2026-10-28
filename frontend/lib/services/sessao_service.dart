import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class SessaoService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  // 1. Iniciar Nova Sessão Pedagógica (RF-020, RN-09)
  static Future<Map<String, dynamic>?> iniciarSessao({
    required String alunoId,
    required String atividadeId,
    required String turmaId,
    String modoEntrada = 'MANUAL',
    bool encerrarAnterior = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/sessoes'),
            headers: _headers,
            body: jsonEncode({
              'aluno_id': alunoId,
              'atividade_id': atividadeId,
              'turma_id': turmaId,
              'modo_entrada': modoEntrada,
              'encerrar_anterior': encerrarAnterior,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201 || response.statusCode == 200) {
        return data;
      } else {
        debugPrint('Error starting session: ${data['detail']}');
        return null;
      }
    } catch (e) {
      debugPrint('Error starting session: $e');
      return null;
    }
  }

  // 2. Obter Sessão Ativa (EM_ANDAMENTO)
  static Future<Map<String, dynamic>?> getSessaoAtiva() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/sessoes/ativa'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != 'null') {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching active session: $e');
      return null;
    }
  }

  // 3. Encerrar Sessão Ativa Anterior como PARCIAL
  static Future<bool> encerrarSessaoAtivaParcial() async {
    try {
      final response = await http
          .post(Uri.parse('${ApiService.baseUrl}/api/sessoes/encerrar-ativa-parcial'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error ending active session: $e');
      return false;
    }
  }

  // 4. Registrar Leitura / Toque de Ficha (RF-023, RN-12)
  static Future<Map<String, dynamic>?> registrarLeituraFicha(
    String sessaoId, {
    required String alvoId,
    required int posicao,
    required String fichaCodigo,
    required bool correta,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/sessoes/$sessaoId/leituras'),
            headers: _headers,
            body: jsonEncode({
              'alvo_id': alvoId,
              'posicao': posicao,
              'ficha_codigo': fichaCodigo,
              'correta': correta,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error recording card reading: $e');
      return null;
    }
  }

  // 5. Finalizar Sessão e Calcular Nota DTAE (RF-024)
  static Future<Map<String, dynamic>?> finalizarSessao(
    String sessaoId, {
    String nivelAjuda = 'NENHUMA',
    String? compreensao = 'TOTAL',
    String? comentario,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/sessoes/$sessaoId/finalizar'),
            headers: _headers,
            body: jsonEncode({
              'nivel_ajuda': nivelAjuda,
              'compreensao': compreensao,
              'comentario': comentario,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error finalizing session: $e');
      return null;
    }
  }
}
