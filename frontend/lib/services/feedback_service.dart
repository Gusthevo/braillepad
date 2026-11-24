import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'preferencias_service.dart';

/// Tipos de retorno sensorial dados à criança durante a atividade.
enum TipoFeedback {
  /// Letra certa no meio de uma sílaba/palavra.
  letra,

  /// Alvo (vogal, sílaba ou palavra) completado.
  acerto,

  /// Ficha incorreta: som suave e encorajador, nunca punitivo.
  erro,

  /// Fase ou atividade concluída: celebração.
  faseConcluida,
}

/// Retorno sensorial (som + vibração) para a criança, que não depende da tela.
///
/// Respeita as preferências do professor `som_ativo`, `vibracao_ativa` e
/// `volume_som`. Os sons tocam misturados à voz (TTS), sem interrompê-la.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const _arquivos = {
    TipoFeedback.letra: 'sounds/letra.wav',
    TipoFeedback.acerto: 'sounds/acerto.wav',
    TipoFeedback.erro: 'sounds/erro.wav',
    TipoFeedback.faseConcluida: 'sounds/fase_concluida.wav',
  };

  // Duração aproximada de cada som, para a fala começar logo depois dele.
  static const _duracoes = {
    TipoFeedback.letra: Duration(milliseconds: 140),
    TipoFeedback.acerto: Duration(milliseconds: 400),
    TipoFeedback.erro: Duration(milliseconds: 420),
    TipoFeedback.faseConcluida: Duration(milliseconds: 1150),
  };

  final Map<TipoFeedback, AudioPlayer> _players = {};
  bool _contextoConfigurado = false;

  Preferencias get _prefs => PreferenciasService.atual.value;

  Future<void> _configurarContexto() async {
    if (_contextoConfigurado) return;
    _contextoConfigurado = true;
    try {
      // Mistura com a voz em vez de tomar o foco de áudio do TTS.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('[FEEDBACK] Não foi possível configurar o contexto de áudio: $e');
    }
  }

  /// Toca o som e a vibração do [tipo]. O Future termina quando o som acaba,
  /// para que a fala seguinte não se sobreponha a ele.
  Future<void> tocar(TipoFeedback tipo) async {
    if (kIsWeb) return;
    _vibrar(tipo);

    final volume = (_prefs.volumeSom / 100).clamp(0.0, 1.0);
    if (!_prefs.somAtivo || volume <= 0) return;
    try {
      await _configurarContexto();
      final player = _players.putIfAbsent(tipo, AudioPlayer.new);
      await player.stop();
      await player.play(
        AssetSource(_arquivos[tipo]!),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
      await Future.delayed(_duracoes[tipo]!);
    } catch (e) {
      debugPrint('[FEEDBACK] Falha ao tocar som $tipo: $e');
    }
  }

  bool? _temVibrador;
  bool _temAmplitude = false;

  /// Vibra pelo motor do aparelho (não pela "vibração ao toque" do Android,
  /// que muitos aparelhos deixam desligada).
  Future<void> _vibrar(TipoFeedback tipo) async {
    if (!_prefs.vibracaoAtiva) return;
    try {
      if (_temVibrador == null) {
        _temVibrador = await Vibration.hasVibrator();
        _temAmplitude = await Vibration.hasAmplitudeControl();
      }
      if (_temVibrador != true) return;

      // pattern: [espera, vibra, espera, vibra...] em ms;
      // intensities: força (1–255) de cada trecho, 0 nas esperas.
      final (List<int> padrao, List<int> forcas) = switch (tipo) {
        TipoFeedback.letra => ([0, 35], [0, 120]),
        TipoFeedback.acerto => ([0, 70, 60, 70], [0, 200, 0, 200]),
        TipoFeedback.erro => ([0, 220], [0, 90]),
        TipoFeedback.faseConcluida => ([0, 120, 80, 120, 80, 300], [0, 255, 0, 255, 0, 255]),
      };
      await Vibration.vibrate(pattern: padrao, intensities: _temAmplitude ? forcas : const []);
    } catch (e) {
      debugPrint('[FEEDBACK] Falha ao vibrar: $e');
    }
  }

  /// Usado pelo botão "Testar" nas Configurações.
  Future<void> testar() => tocar(TipoFeedback.acerto);

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
