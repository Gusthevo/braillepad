import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'preferencias_service.dart';

/// Serviço de Síntese de Voz (Text-to-Speech / Voz Falada Acessível)
/// Lê em voz alta em português (pt-BR) a instrução pedagógica para o aluno sem cortar o áudio.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  String? _lastSpokenText;
  double? _volumeAplicado;
  double? _velocidadeAplicada;

  /// Aplica o volume da voz e a velocidade da fala escolhidos nas Configurações.
  Future<void> _aplicarPreferencias() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final p = PreferenciasService.atual.value;
    final volume = (p.volumeVoz / 100).clamp(0.0, 1.0);
    if (volume != _volumeAplicado) {
      await _flutterTts.setVolume(volume);
      _volumeAplicado = volume;
    }
    if (p.velocidadeFala != _velocidadeAplicada) {
      await _flutterTts.setSpeechRate(p.velocidadeFala);
      _velocidadeAplicada = p.velocidadeFala;
    }
  }
  DateTime? _lastSpokenTime;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _flutterTts.setLanguage("pt-BR");
        await _flutterTts.setPitch(1.0);
        await _flutterTts.awaitSpeakCompletion(true); // Aguarda conclusão da fala sem cortar a letra/palavra final
      }
      _initialized = true;
    } catch (e) {
      debugPrint("Erro ao inicializar o serviço TTS: $e");
    }
  }

  /// Fala qualquer texto em português garantindo pontuação e finalização completa do áudio
  Future<void> falar(String texto) async {
    if (kIsWeb) return;
    final textoFormatado = texto.endsWith('.') || texto.endsWith('!') ? texto : '$texto.';

    // Evita repetir exatamente a mesma frase dentro de 800ms
    final agora = DateTime.now();
    if (_lastSpokenText == textoFormatado &&
        _lastSpokenTime != null &&
        agora.difference(_lastSpokenTime!).inMilliseconds < 800) {
      return;
    }

    try {
      await _init();
      await _aplicarPreferencias();
      _lastSpokenText = textoFormatado;
      _lastSpokenTime = agora;

      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 60));
      await _flutterTts.speak(textoFormatado);
    } catch (e) {
      debugPrint("Erro ao falar via TTS: $e");
    }
  }

  /// Anuncia qual letra ou palavra deve ser apresentada
  Future<void> falarComandoAlvo(String alvo, {int? posicaoAtual, int? tamanhoTotal}) async {
    final clean = alvo.trim().toUpperCase();
    if (clean.length == 1) {
      await falar("Apresente a letra $clean.");
    } else if (posicaoAtual != null && tamanhoTotal != null && tamanhoTotal > 1) {
      final letraEsperada = clean[posicaoAtual];
      if (posicaoAtual == 0) {
        await falar("Palavra $clean. Apresente a primeira letra: $letraEsperada.");
      } else {
        await falar("Apresente a letra $letraEsperada.");
      }
    } else {
      await falar("Apresente a palavra $clean.");
    }
  }

  /// Frase de exemplo para o professor ouvir o volume e a velocidade escolhidos.
  Future<void> falarExemplo() => falar('Olá! Apresente a letra A.');

  /// Para a fala se a tela for fechada
  Future<void> parar() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
