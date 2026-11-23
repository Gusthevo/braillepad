import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sessao_service.dart';
import '../services/braillepad_ble_service.dart';
import '../services/tts_service.dart';
import 'resumo_sessao_screen.dart';

enum EtapaAtividade { tutorial, fase01Ordenada, conclusaoFase01, fase02Randomizada }

class ExecucaoSessaoScreen extends StatefulWidget {
  final Map<String, dynamic> sessao;

  const ExecucaoSessaoScreen({
    super.key,
    required this.sessao,
  });

  @override
  State<ExecucaoSessaoScreen> createState() => _ExecucaoSessaoScreenState();
}

class _ExecucaoSessaoScreenState extends State<ExecucaoSessaoScreen> {
  EtapaAtividade _etapaAtual = EtapaAtividade.tutorial;

  late List<String> _alvosAtividade;
  late List<String> _alvosRandomizados;
  late String _tipoAlvoNome;

  int _alvoIndex = 0;
  int _tentativasNoAlvoAtual = 0;
  int _letraPosicaoNoAlvo = 0;
  final List<String> _letrasJaCompletadas = [];

  int _totalAcertosFase = 0;
  int _totalErrosFase = 0;

  int _badgesPositivas = 0;
  int _badgesNegativas = 0;

  int _segundosDecorridos = 0;
  Timer? _timer;
  StreamSubscription<String>? _rfidSubscription;

  @override
  void initState() {
    super.initState();

    final List? alvosDaApi = widget.sessao['alvos_esperados'] as List?;
    final String catApi = (widget.sessao['modulo_categoria'] ?? '').toString().toUpperCase();
    final atvId = (widget.sessao['atividade_id'] ?? '').toString().toLowerCase();

    // Separadores (ex: "MA-LA") não existem como ficha física no PAD; sem essa
    // limpeza o alvo nunca poderia ser completado. Mesma regra do backend.
    final separadores = RegExp(r'[\s\-–—_.]');
    final alvosNormalizados = (alvosDaApi ?? const [])
        .map((e) => e.toString().replaceAll(separadores, '').toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    if (alvosNormalizados.isNotEmpty) {
      _alvosAtividade = alvosNormalizados;
    } else if (catApi == 'SILABAS' || atvId.contains('mod2') || atvId.contains('silaba')) {
      _alvosAtividade = ['MA', 'ME', 'MI', 'MO', 'MU', 'LA', 'LE', 'LI', 'LO', 'LU'];
    } else if (catApi == 'PALAVRAS' || atvId.contains('mod3') || atvId.contains('palavra')) {
      _alvosAtividade = ['MALA', 'LAMA', 'LIMA', 'MULA', 'MOLA', 'LIMAO', 'LEAO'];
    } else {
      _alvosAtividade = ['A', 'E', 'I', 'O', 'U'];
    }

    if (catApi == 'SILABAS' || atvId.contains('mod2') || atvId.contains('silaba')) {
      _tipoAlvoNome = 'Sílaba';
    } else if (catApi == 'PALAVRAS' || atvId.contains('mod3') || atvId.contains('palavra')) {
      _tipoAlvoNome = 'Palavra';
    } else {
      _tipoAlvoNome = 'Vogal';
    }

    _alvosRandomizados = List.from(_alvosAtividade)..shuffle();

    // Inscrever na escuta de leituras RFID enviadas pelo BraillePad via BLE
    _rfidSubscription = BraillepadBleService.instance.rfidStream.listen((fichaLida) {
      if (mounted && _etapaAtual != EtapaAtividade.conclusaoFase01) {
        debugPrint('[BLE_RFID_LIDO] Ficha RFID aproximada do PAD: $fichaLida');
        _registrarResposta(fichaLida);
      }
    });

    // Anuncia por voz o primeiro alvo a ser apresentado
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _anunciarAlvoAtual();
    });
  }

  void _anunciarAlvoAtual() {
    if (_etapaAtual == EtapaAtividade.conclusaoFase01) return;
    List<String> listaAtual = (_etapaAtual == EtapaAtividade.fase02Randomizada)
        ? _alvosRandomizados
        : _alvosAtividade;
    if (_alvoIndex < listaAtual.length) {
      String alvo = listaAtual[_alvoIndex];
      TtsService.instance.falarComandoAlvo(
        alvo,
        posicaoAtual: _letraPosicaoNoAlvo,
        tamanhoTotal: alvo.length,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rfidSubscription?.cancel();
    TtsService.instance.parar();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _segundosDecorridos = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _segundosDecorridos++;
        });
      }
    });
  }

  Color _getCorDesempenhoCentral() {
    if (_totalErrosFase == 0) return Colors.green.shade600;
    if (_totalErrosFase < 3) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  // Fila que envia as leituras ao backend na ordem em que aconteceram,
  // sem bloquear a interação da criança enquanto a rede responde.
  Future<void> _filaEnvioLeituras = Future.value();

  void _enviarLeitura({
    required String alvoSolicitado,
    required int posicao,
    required String ficha,
    required bool correta,
  }) {
    final sessaoId = widget.sessao['id'];
    final tipoFase = switch (_etapaAtual) {
      EtapaAtividade.tutorial => 'EXPLORAR',
      EtapaAtividade.fase02Randomizada => 'EMBARALHADA',
      _ => 'ORDEM',
    };
    _filaEnvioLeituras = _filaEnvioLeituras.then((_) async {
      await SessaoService.registrarLeituraFicha(
        sessaoId,
        alvoId: 'alvo_${alvoSolicitado.toLowerCase()}',
        posicao: posicao,
        fichaCodigo: 'FICHA_$ficha',
        correta: correta,
        tipoFase: tipoFase,
      );
    }).catchError((Object e) {
      debugPrint('[LEITURA] Falha ao enviar leitura: $e');
    });
  }

  void _registrarResposta(String fichaTocada) {
    if (_etapaAtual == EtapaAtividade.conclusaoFase01) return;

    List<String> listaAtual = (_etapaAtual == EtapaAtividade.fase02Randomizada)
        ? _alvosRandomizados
        : _alvosAtividade;
    if (_alvoIndex >= listaAtual.length) return;

    String alvoSolicitado = listaAtual[_alvoIndex];
    String fichaLimpa = fichaTocada.trim().toUpperCase();
    String alvoLimpo = alvoSolicitado.trim().toUpperCase();
    final bool alvoComposto = alvoLimpo.length > 1;

    // Posição (1-based) da ficha esperada dentro do alvo, capturada ANTES de
    // qualquer mudança de estado. Assim acerto e erro na mesma letra sempre
    // são registrados na mesma posição (ex: 2ª letra de MALA = posição 2).
    final int indiceEsperado = alvoComposto
        ? _letraPosicaoNoAlvo.clamp(0, alvoLimpo.length - 1)
        : 0;
    final int posicaoEsperada = indiceEsperado + 1;
    final String letraEsperada = alvoComposto ? alvoLimpo[indiceEsperado] : alvoLimpo;

    bool isCorreta;
    bool alvoCompletado = false;
    bool letraParcialCorreta = false;

    if (_etapaAtual == EtapaAtividade.tutorial) {
      isCorreta = _alvosAtividade.contains(fichaLimpa) || alvoLimpo.contains(fichaLimpa);
      alvoCompletado = true;
    } else if (fichaLimpa == alvoLimpo) {
      // Leitura da palavra/sílaba completa
      isCorreta = true;
      alvoCompletado = true;
    } else if (fichaLimpa == letraEsperada) {
      // Leitura correta da ficha na posição sequencial da palavra/sílaba
      isCorreta = true;
      letraParcialCorreta = true;
      alvoCompletado = posicaoEsperada >= alvoLimpo.length;
    } else {
      isCorreta = false;
    }

    _enviarLeitura(
      alvoSolicitado: alvoSolicitado,
      posicao: posicaoEsperada,
      ficha: fichaLimpa,
      correta: isCorreta,
    );

    if (!mounted) return;

    setState(() {
      if (letraParcialCorreta) {
        _letrasJaCompletadas.add(fichaLimpa);
        _letraPosicaoNoAlvo = posicaoEsperada;
      }
      if (_etapaAtual == EtapaAtividade.tutorial) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCorreta
                ? 'Acerto no Tutorial! Ficha $fichaLimpa reconhecida no BraillePad.'
                : 'Ficha $fichaLimpa testada no tutorial.'),
            backgroundColor: isCorreta ? Colors.green : Colors.orange.shade800,
            duration: const Duration(milliseconds: 800),
          ),
        );
        TtsService.instance.falar(isCorreta ? "Ficha $fichaLimpa testada com sucesso." : "Ficha $fichaLimpa testada.");
        return;
      }

      if (isCorreta) {
        if (alvoCompletado) {
          _totalAcertosFase++;
          if (_totalAcertosFase % 3 == 0) _badgesPositivas++;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excelente! $alvoLimpo completada com sucesso! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 1000),
            ),
          );
          TtsService.instance.falar("Excelente! $alvoLimpo completada com sucesso!");
          _avancarParaProximoAlvoOuFase();
        } else {
          // Letra correta no meio da palavra (ex: 'M' de 'MALA')
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Letra "$fichaLimpa" reconhecida! Próxima letra esperada: "${alvoLimpo[_letraPosicaoNoAlvo]}"'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(milliseconds: 900),
            ),
          );
          TtsService.instance.falar("Letra $fichaLimpa reconhecida. Próxima letra: ${alvoLimpo[_letraPosicaoNoAlvo]}");
        }
      } else {
        _totalErrosFase++;
        _tentativasNoAlvoAtual++;
        if (_totalErrosFase % 3 == 0) _badgesNegativas++;

        String msgErro = (alvoLimpo.length > 1)
            ? 'Incorreto. Para a ${_letraPosicaoNoAlvo + 1}ª letra de $alvoLimpo, a ficha esperada é "$letraEsperada".'
            : 'Incorreto (Tentativa $_tentativasNoAlvoAtual/3). A ficha esperada era $alvoSolicitado.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msgErro),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(milliseconds: 1200),
          ),
        );
        TtsService.instance.falar("Incorreto. A letra esperada é $letraEsperada");

        if (_tentativasNoAlvoAtual >= 3) {
          _avancarParaProximoAlvoOuFase();
        }
      }
    });
  }

  void _avancarParaProximoAlvoOuFase() {
    List<String> listaAtual = (_etapaAtual == EtapaAtividade.fase02Randomizada)
        ? _alvosRandomizados
        : _alvosAtividade;

    setState(() {
      _tentativasNoAlvoAtual = 0;
      _letraPosicaoNoAlvo = 0;
      _letrasJaCompletadas.clear();

      if (_alvoIndex < listaAtual.length - 1) {
        _alvoIndex++;
        _anunciarAlvoAtual();
      } else {
        _concluirEtapa();
      }
    });
  }

  void _concluirEtapa() {
    setState(() {
      _alvoIndex = 0;
      _tentativasNoAlvoAtual = 0;

      if (_etapaAtual == EtapaAtividade.tutorial) {
        _etapaAtual = EtapaAtividade.fase01Ordenada;
        _totalAcertosFase = 0;
        _totalErrosFase = 0;
        _badgesPositivas = 0;
        _badgesNegativas = 0;
        _iniciarTimer();
      } else if (_etapaAtual == EtapaAtividade.fase01Ordenada) {
        _etapaAtual = EtapaAtividade.conclusaoFase01;
      } else if (_etapaAtual == EtapaAtividade.fase02Randomizada) {
        _concluirSessaoFinal();
      }
    });
  }

  void _iniciarFase02Randomizada() {
    setState(() {
      _alvoIndex = 0;
      _tentativasNoAlvoAtual = 0;
      _etapaAtual = EtapaAtividade.fase02Randomizada;
    });
  }

  void _concluirSessaoFinal() async {
    _timer?.cancel();

    final int totTentativas = _totalAcertosFase + _totalErrosFase;

    // Encerra a sessão. A nota é calculada pelo backend a partir das tentativas
    // gravadas; ajuda e compreensão são confirmadas em seguida pelo professor
    // na tela de avaliação, que recalcula a nota.
    final resumo = await SessaoService.finalizarSessao(
      widget.sessao['id'],
      duracaoSegundos: _segundosDecorridos,
      totalAcertos: _totalAcertosFase,
      totalTentativas: totTentativas,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResumoSessaoScreen(sessao: resumo ?? widget.sessao),
        ),
      );
    }
  }

  String _formatarTempo(int totalSegundos) {
    final m = totalSegundos ~/ 60;
    final s = totalSegundos % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_etapaAtual == EtapaAtividade.conclusaoFase01) {
      return Scaffold(
        backgroundColor: AppTheme.warmBackground,
        appBar: AppBar(
          title: const Text('Fase 01 Concluída!'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stars_rounded, color: Colors.green.shade700, size: 72),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Fase 01 (Sequência Ordenada) Concluída!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                ),
                const SizedBox(height: 12),
                Text(
                  'O aluno completou a identificação em sequência ordenada de $_tipoAlvoNome. Agora avance para testar o reconhecimento na sequência randomizada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _iniciarFase02Randomizada,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text(
                      'Avançar para a Fase 02 (Randomizada)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    List<String> listaAtual = (_etapaAtual == EtapaAtividade.fase02Randomizada)
        ? _alvosRandomizados
        : _alvosAtividade;

    String alvoSolicitado = (_etapaAtual == EtapaAtividade.tutorial)
        ? _tipoAlvoNome.toUpperCase()
        : listaAtual[_alvoIndex];

    String tituloEtapa;
    if (_etapaAtual == EtapaAtividade.tutorial) {
      tituloEtapa = 'Atividade 01 — Tela 1: Tutorial';
    } else if (_etapaAtual == EtapaAtividade.fase01Ordenada) {
      tituloEtapa = 'Atividade 01 — Tela 2: Fase 01 (Ordenada)';
    } else {
      tituloEtapa = 'Atividade 01 — Tela 3: Fase 02 (Randomizada)';
    }

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: Text(tituloEtapa),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outlined, color: Colors.green),
            onPressed: _concluirSessaoFinal,
            tooltip: 'Ir para Avaliação pelo Professor',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              if (_etapaAtual == EtapaAtividade.tutorial) ...[
                Card(
                  color: Colors.blue.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade400, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.school_rounded, color: Colors.blue.shade900, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🎓 TELA 1 — TUTORIAL DE TESTE DO APARELHO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'O aluno testa livremente as fichas no BraillePad. Os testes do tutorial não são computados na pontuação da Fase 01.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_etapaAtual != EtapaAtividade.tutorial) ...[
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 4),
                            Text('$_totalErrosFase', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            if (_badgesNegativas > 0) ...[
                              const SizedBox(width: 4),
                              Chip(
                                label: Text('-$_badgesNegativas ⚠️', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.red.shade700,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: AppTheme.primaryOrange, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                _formatarTempo(_segundosDecorridos),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange, fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 4),
                            Text('$_totalAcertosFase', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            if (_badgesPositivas > 0) ...[
                              const SizedBox(width: 4),
                              Chip(
                                label: Text('+$_badgesPositivas 🎉', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.green.shade700,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                        child: const Icon(Icons.person_rounded, color: AppTheme.primaryOrange),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.sessao['aluno_nome'] ?? 'Aluno DTAE',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              _etapaAtual == EtapaAtividade.tutorial
                                  ? 'Teste de Interação com o BraillePad (Livre)'
                                  : '$_tipoAlvoNome ${_alvoIndex + 1} de ${_alvosAtividade.length}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        _etapaAtual == EtapaAtividade.tutorial
                            ? 'Aproximação Livre no BraillePad:'
                            : '$_tipoAlvoNome Solicitada no PAD:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getCorDesempenhoCentral(),
                          boxShadow: [
                            BoxShadow(
                              color: _getCorDesempenhoCentral().withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: FittedBox(
                              child: Text(
                                alvoSolicitado,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: _etapaAtual == EtapaAtividade.tutorial ? 24 : 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _etapaAtual == EtapaAtividade.tutorial
                            ? 'Aproxime qualquer ficha no leitor RFID do PAD para ouvir a resposta do aparelho.'
                            : 'Apresente as fichas para formar "$alvoSolicitado" no leitor RFID do BraillePad:',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (_etapaAtual != EtapaAtividade.tutorial && alvoSolicitado.length > 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(alvoSolicitado.length, (index) {
                            final isDone = index < _letrasJaCompletadas.length;
                            final isCurrent = index == _letraPosicaoNoAlvo && !isDone;
                            final char = isDone
                                ? _letrasJaCompletadas[index]
                                : (isCurrent ? '?' : '_');

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 38,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green.shade600
                                    : (isCurrent ? AppTheme.primaryOrange : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent ? AppTheme.primaryOrange : Colors.grey.shade400,
                                  width: isCurrent ? 2.5 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  char,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: (isDone || isCurrent) ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Fichas de $_tipoAlvoNome Apresentadas no PAD:',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _alvosAtividade.map((a) {
                  return SizedBox(
                    width: a.length > 3 ? 84 : (a.length > 2 ? 68 : 54),
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryOrange,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppTheme.primaryOrange, width: 2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => _registrarResposta(a),
                      child: FittedBox(
                        child: Text(
                          a,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  if (_etapaAtual != EtapaAtividade.tutorial) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _avancarParaProximoAlvoOuFase,
                        icon: const Icon(Icons.skip_next_rounded, color: AppTheme.primaryOrange),
                        label: Text('Próxima $_tipoAlvoNome', style: const TextStyle(color: AppTheme.primaryOrange, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryOrange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _concluirEtapa,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _etapaAtual == EtapaAtividade.tutorial
                            ? 'Iniciar Fase 01 (Sequência Ordenada)'
                            : _etapaAtual == EtapaAtividade.fase01Ordenada
                                ? 'Concluir Fase 01'
                                : 'Concluir Atividade',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
