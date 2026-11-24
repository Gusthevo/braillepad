import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'metricas_cores.dart';

/// Mapa de calor do desempenho por ficha (A, E, I, O, U, M, L...).
///
/// Na versão completa cada ficha é um cartão tocável com % de acerto e a
/// troca mais comum; na versão [compacta] (cartões da turma) vira uma fileira
/// de quadradinhos coloridos.
class AlfabetoTatil extends StatelessWidget {
  final List<Map<String, dynamic>> fichas;
  final bool compacta;

  const AlfabetoTatil({super.key, required this.fichas, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    if (fichas.isEmpty) return const SizedBox.shrink();
    return compacta ? _compacta() : _completa(context);
  }

  Widget _compacta() {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final f in fichas)
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MetricasCores.porValor((f['percentual'] as num?)?.toDouble()).withValues(
                alpha: f['percentual'] == null ? 0.25 : 0.85,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              f['simbolo'] ?? '',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: f['percentual'] == null ? Colors.grey.shade600 : Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _completa(BuildContext context) {
    final maisDificil = fichas
        .where((f) => f['percentual'] != null && ((f['erros'] as num?) ?? 0) > 0)
        .fold<Map<String, dynamic>?>(null, (pior, f) {
      if (pior == null) return f;
      return (f['percentual'] as num) < (pior['percentual'] as num) ? f : pior;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          const espaco = 8.0;
          final porLinha = constraints.maxWidth >= 420 ? 7 : 4;
          final largura = (constraints.maxWidth - espaco * (porLinha - 1)) / porLinha;
          return Wrap(
            spacing: espaco,
            runSpacing: espaco,
            children: [
              for (final f in fichas)
                _CartaoFicha(ficha: f, largura: largura, destaque: identical(f, maisDificil)),
            ],
          );
        }),
        if (maisDificil != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warmBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: AppTheme.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Foco sugerido: ficha ${maisDificil['simbolo']} '
                    '(${(maisDificil['percentual'] as num).toStringAsFixed(0)}% de acerto'
                    '${maisDificil['troca_mais_comum'] != null ? ', costuma trocar por ${maisDificil['troca_mais_comum']}' : ''}).',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CartaoFicha extends StatelessWidget {
  final Map<String, dynamic> ficha;
  final double largura;
  final bool destaque;

  const _CartaoFicha({required this.ficha, required this.largura, required this.destaque});

  @override
  Widget build(BuildContext context) {
    final simbolo = ficha['simbolo'] as String? ?? '?';
    final pct = (ficha['percentual'] as num?)?.toDouble();
    final acertos = (ficha['acertos'] as num?)?.toInt() ?? 0;
    final erros = (ficha['erros'] as num?)?.toInt() ?? 0;
    final troca = ficha['troca_mais_comum'] as String?;
    final cor = MetricasCores.porValor(pct);
    final semDados = pct == null;

    final detalhe = semDados
        ? 'Ainda não foi pedida em nenhuma atividade.'
        : '$acertos acerto${acertos == 1 ? '' : 's'} e $erros erro${erros == 1 ? '' : 's'}'
            '${troca != null ? '. Troca mais comum: $troca' : ''}';

    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      message: 'Ficha $simbolo: $detalhe',
      child: Semantics(
        label: 'Ficha $simbolo, ${semDados ? 'sem dados' : '${pct.toStringAsFixed(0)} por cento de acerto'}',
        child: Container(
          width: largura,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: semDados ? Colors.grey.shade100 : cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: destaque ? cor : (semDados ? Colors.grey.shade300 : cor.withValues(alpha: 0.4)),
              width: destaque ? 2.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                simbolo,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: semDados ? Colors.grey.shade400 : cor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                semDados ? '—' : '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: semDados ? Colors.grey.shade500 : Colors.grey.shade800,
                ),
              ),
              if (!semDados) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      color: cor,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
