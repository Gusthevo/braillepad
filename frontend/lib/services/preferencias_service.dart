import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Modo de execução das atividades.
/// - [manual]: botões de toque na tela (as fichas do PAD também são aceitas).
/// - [pad]: somente as fichas lidas pelo BraillePad valem; os botões somem.
enum ModoExecucao {
  manual('MANUAL'),
  pad('PAD');

  final String codigo;
  const ModoExecucao(this.codigo);

  static ModoExecucao deCodigo(String? codigo) =>
      // 'SIMULACAO' é o nome antigo de 'PAD'.
      (codigo == 'PAD' || codigo == 'SIMULACAO') ? ModoExecucao.pad : ModoExecucao.manual;
}

/// Preferências do professor, aplicadas no app inteiro.
@immutable
class Preferencias {
  final bool altoContraste;
  final double escalaFonte;
  final bool somAtivo;
  final bool vibracaoAtiva;
  final int volumeSom;
  final ModoExecucao modoExecucao;
  final int volumeVoz;
  final double velocidadeFala;

  const Preferencias({
    this.altoContraste = false,
    this.escalaFonte = 1.0,
    this.somAtivo = true,
    this.vibracaoAtiva = true,
    this.volumeSom = 80,
    this.modoExecucao = ModoExecucao.manual,
    this.volumeVoz = 100,
    this.velocidadeFala = 0.5,
  });

  static const padrao = Preferencias();

  factory Preferencias.fromJson(Map<String, dynamic> j) => Preferencias(
        altoContraste: j['alto_contraste'] as bool? ?? false,
        escalaFonte: (j['escala_fonte'] as num?)?.toDouble() ?? 1.0,
        somAtivo: j['som_ativo'] as bool? ?? true,
        vibracaoAtiva: j['vibracao_ativa'] as bool? ?? true,
        volumeSom: (j['volume_som'] as num?)?.toInt() ?? 80,
        modoExecucao: ModoExecucao.deCodigo(j['modo_execucao_padrao'] as String?),
        volumeVoz: (j['volume_voz'] as num?)?.toInt() ?? 100,
        velocidadeFala: (j['velocidade_fala'] as num?)?.toDouble() ?? 0.5,
      );

  Map<String, dynamic> toJson() => {
        'alto_contraste': altoContraste,
        'escala_fonte': escalaFonte,
        'som_ativo': somAtivo,
        'vibracao_ativa': vibracaoAtiva,
        'volume_som': volumeSom,
        'modo_execucao_padrao': modoExecucao.codigo,
        'volume_voz': volumeVoz,
        'velocidade_fala': velocidadeFala,
      };

  Preferencias copyWith({
    bool? altoContraste,
    double? escalaFonte,
    bool? somAtivo,
    bool? vibracaoAtiva,
    int? volumeSom,
    ModoExecucao? modoExecucao,
    int? volumeVoz,
    double? velocidadeFala,
  }) =>
      Preferencias(
        altoContraste: altoContraste ?? this.altoContraste,
        escalaFonte: escalaFonte ?? this.escalaFonte,
        somAtivo: somAtivo ?? this.somAtivo,
        vibracaoAtiva: vibracaoAtiva ?? this.vibracaoAtiva,
        volumeSom: volumeSom ?? this.volumeSom,
        modoExecucao: modoExecucao ?? this.modoExecucao,
        volumeVoz: volumeVoz ?? this.volumeVoz,
        velocidadeFala: velocidadeFala ?? this.velocidadeFala,
      );

  @override
  bool operator ==(Object other) =>
      other is Preferencias && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Resultado de uma leitura/gravação no servidor.
class ResultadoPreferencias {
  final bool ok;
  final String? erro;
  const ResultadoPreferencias.sucesso() : ok = true, erro = null;
  const ResultadoPreferencias.falha(this.erro) : ok = false;
}

class PreferenciasService {
  static const _chaveCache = 'dtae_preferencias';

  /// Preferências em uso. O tema, a voz, os sons e a tela de atividade
  /// escutam este valor, então uma mudança vale na hora.
  static final ValueNotifier<Preferencias> atual = ValueNotifier(Preferencias.padrao);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  static Uri get _url => Uri.parse('${ApiService.baseUrl}/api/auth/preferencias');

  /// Última cópia salva no aparelho: aplica o alto contraste e a fonte já na
  /// abertura do app, antes (ou sem) resposta do servidor.
  static Future<void> carregarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_chaveCache);
      if (json != null) atual.value = Preferencias.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PREFERENCIAS] Cache inválido: $e');
    }
  }

  static Future<void> _salvarCache(Preferencias p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveCache, jsonEncode(p.toJson()));
    } catch (e) {
      debugPrint('[PREFERENCIAS] Falha ao salvar cache: $e');
    }
  }

  static String _mensagemErro(http.Response r) {
    try {
      final detalhe = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
      if (detalhe is String) return detalhe;
    } catch (_) {}
    return 'O servidor respondeu com erro ${r.statusCode}.';
  }

  /// Busca as preferências no servidor e passa a usá-las.
  static Future<ResultadoPreferencias> carregar() async {
    if (!AuthService.isLoggedIn) return const ResultadoPreferencias.falha('Sessão expirada. Entre novamente.');
    try {
      final r = await http.get(_url, headers: _headers).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return ResultadoPreferencias.falha(_mensagemErro(r));
      final p = Preferencias.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
      atual.value = p;
      await _salvarCache(p);
      return const ResultadoPreferencias.sucesso();
    } catch (e) {
      debugPrint('[PREFERENCIAS] Erro ao carregar: $e');
      return const ResultadoPreferencias.falha('Não foi possível conectar ao servidor.');
    }
  }

  /// Aplica [nova] imediatamente e grava no servidor. Se a gravação falhar,
  /// volta ao valor anterior para a tela não mostrar algo que não foi salvo.
  static Future<ResultadoPreferencias> salvar(Preferencias nova) async {
    final anterior = atual.value;
    final alteracoes = <String, dynamic>{};
    final a = anterior.toJson();
    nova.toJson().forEach((k, v) {
      if (a[k] != v) alteracoes[k] = v;
    });
    if (alteracoes.isEmpty) return const ResultadoPreferencias.sucesso();

    atual.value = nova;
    try {
      final r = await http
          .patch(_url, headers: _headers, body: jsonEncode(alteracoes))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) {
        atual.value = anterior;
        return ResultadoPreferencias.falha(_mensagemErro(r));
      }
      final gravada = Preferencias.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
      atual.value = gravada;
      await _salvarCache(gravada);
      return const ResultadoPreferencias.sucesso();
    } catch (e) {
      debugPrint('[PREFERENCIAS] Erro ao salvar: $e');
      atual.value = anterior;
      return const ResultadoPreferencias.falha('Não foi possível conectar ao servidor.');
    }
  }

  /// Ao sair da conta, volta aos padrões e apaga a cópia local.
  static Future<void> limpar() async {
    atual.value = Preferencias.padrao;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chaveCache);
    } catch (_) {}
  }
}
