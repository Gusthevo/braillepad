import 'package:flutter/material.dart';

/// Cores e rótulos compartilhados pelos widgets de métricas.
///
/// Os limiares seguem o padrão do `config_metricas` do banco
/// (verde ≥ 75, amarelo ≥ 50). O status do aluno vem pronto do backend;
/// estes limiares só colorem notas e percentuais individuais.
class MetricasCores {
  static const double limiarVerde = 75.0;
  static const double limiarAmarelo = 50.0;

  static final Color verde = Colors.green.shade600;
  static final Color amarelo = Colors.amber.shade700;
  static final Color vermelho = Colors.red.shade600;
  static final Color cinza = Colors.grey.shade400;

  static Color porValor(double? valor) {
    if (valor == null) return cinza;
    if (valor >= limiarVerde) return verde;
    if (valor >= limiarAmarelo) return amarelo;
    return vermelho;
  }

  static Color porStatus(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'VERDE':
        return verde;
      case 'AMARELO':
        return amarelo;
      case 'VERMELHO':
        return vermelho;
      default:
        return Colors.grey.shade500;
    }
  }

  static String rotuloStatus(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'VERDE':
        return 'Autonomia';
      case 'AMARELO':
        return 'Em desenvolvimento';
      case 'VERMELHO':
        return 'Precisa de apoio';
      default:
        return 'Dados insuficientes';
    }
  }

  static IconData iconeStatus(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'VERDE':
        return Icons.emoji_events_rounded;
      case 'AMARELO':
        return Icons.trending_up_rounded;
      case 'VERMELHO':
        return Icons.support_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }
}

String formatarDataCurta(String? iso, {bool comAno = false}) {
  final dt = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  String dois(int n) => n.toString().padLeft(2, '0');
  return comAno ? '${dois(dt.day)}/${dois(dt.month)}/${dt.year}' : '${dois(dt.day)}/${dois(dt.month)}';
}
