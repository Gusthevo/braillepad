import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'metricas_cores.dart';

/// Trilha de progresso: cada módulo é uma linha de "fases" (atividades 01–10).
///
/// ● concluída (cor da última nota)   ◐ iniciada sem concluir
/// ◉ próxima sugerida                 ○ pendente
class TrilhaModulos extends StatelessWidget {
  final List<Map<String, dynamic>> modulos;

  const TrilhaModulos({super.key, required this.modulos});

  @override
  Widget build(BuildContext context) {
    if (modulos.isEmpty) {
      return Text('Nenhum módulo cadastrado.', style: TextStyle(color: Colors.grey.shade600));
    }
    // A "próxima atividade" só é destacada no primeiro módulo ainda incompleto.
    final moduloAtual = modulos.indexWhere((m) =>
        ((m['atividades'] as List?) ?? const []).any((a) => (a as Map)['status'] != 'CONCLUIDA'));
    return Column(
      children: [
        for (final (i, m) in modulos.indexed) ...[
          _LinhaModulo(modulo: m, destacarProxima: i == moduloAtual),
          if (m != modulos.last) const SizedBox(height: 18),
        ],
        const SizedBox(height: 12),
        const _Legenda(),
      ],
    );
  }
}

class _LinhaModulo extends StatelessWidget {
  final Map<String, dynamic> modulo;
  final bool destacarProxima;

  const _LinhaModulo({required this.modulo, required this.destacarProxima});

  @override
  Widget build(BuildContext context) {
    final atividades = ((modulo['atividades'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final concluidas = (modulo['concluidas'] as num?)?.toInt() ?? 0;
    final total = (modulo['total'] as num?)?.toInt() ?? atividades.length;
    final indiceProxima = destacarProxima ? atividades.indexWhere((a) => a['status'] != 'CONCLUIDA') : -1;
    final completo = total > 0 && concluidas == total;
    final nome = (modulo['nome'] as String? ?? '').replaceFirst(RegExp(r'^M[óo]dulo \d+\s*[—-]\s*'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              completo ? Icons.workspace_premium_rounded : Icons.flag_rounded,
              size: 18,
              color: completo ? Colors.amber.shade700 : AppTheme.primaryOrange,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                nome.isEmpty ? 'Módulo ${modulo['modulo_id']}' : nome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Text(
              '$concluidas/$total',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: completo ? Colors.amber.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final n = atividades.length;
          if (n == 0) return const SizedBox.shrink();
          const conector = 5.0;
          final tamanho = ((constraints.maxWidth - conector * (n - 1)) / n).clamp(18.0, 30.0);
          return Row(
            children: [
              for (var i = 0; i < n; i++) ...[
                _NoAtividade(
                  atividade: atividades[i],
                  tamanho: tamanho,
                  proxima: i == indiceProxima,
                ),
                if (i < n - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: atividades[i]['status'] == 'CONCLUIDA'
                            ? MetricasCores.porValor((atividades[i]['ultima_nota'] as num?)?.toDouble())
                                .withValues(alpha: 0.6)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          );
        }),
      ],
    );
  }
}

class _NoAtividade extends StatelessWidget {
  final Map<String, dynamic> atividade;
  final double tamanho;
  final bool proxima;

  const _NoAtividade({required this.atividade, required this.tamanho, required this.proxima});

  @override
  Widget build(BuildContext context) {
    final status = atividade['status'] as String? ?? 'PENDENTE';
    final numero = (atividade['numero'] as num?)?.toInt() ?? 0;
    final ultima = (atividade['ultima_nota'] as num?)?.toDouble();
    final melhor = (atividade['melhor_nota'] as num?)?.toDouble();
    final concluida = status == 'CONCLUIDA';
    final iniciada = status == 'INICIADA';
    final cor = concluida ? MetricasCores.porValor(ultima) : AppTheme.primaryOrange;

    final detalhe = concluida
        ? 'Última nota: ${ultima?.toStringAsFixed(1) ?? '—'} · Melhor: ${melhor?.toStringAsFixed(1) ?? '—'}'
        : iniciada
            ? 'Iniciada, mas ainda não concluída'
            : (proxima ? 'Próxima atividade sugerida' : 'Ainda não realizada');

    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      message: '${atividade['titulo'] ?? 'Atividade $numero'}\n$detalhe',
      child: Semantics(
        label: 'Atividade $numero, $detalhe',
        child: Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: concluida ? cor : (iniciada ? cor.withValues(alpha: 0.15) : Colors.white),
            border: Border.all(
              color: concluida ? cor : (proxima || iniciada ? AppTheme.primaryOrange : Colors.grey.shade300),
              width: proxima ? 2.5 : 1.5,
            ),
            boxShadow: proxima
                ? [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.35), blurRadius: 6)]
                : null,
          ),
          child: Center(
            child: concluida && melhor != null && melhor >= MetricasCores.limiarVerde
                ? Icon(Icons.star_rounded, size: tamanho * 0.6, color: Colors.white)
                : Text(
                    '$numero',
                    style: TextStyle(
                      fontSize: tamanho * 0.4,
                      fontWeight: FontWeight.bold,
                      color: concluida
                          ? Colors.white
                          : (proxima || iniciada ? AppTheme.primaryOrange : Colors.grey.shade500),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget marca, String texto) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [marca, const SizedBox(width: 4), Text(texto, style: TextStyle(fontSize: 10, color: Colors.grey.shade700))],
        );
    Widget bola(Color fundo, Color borda, {double largura = 1.5}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fundo, border: Border.all(color: borda, width: largura)),
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(Icon(Icons.star_rounded, size: 14, color: MetricasCores.verde), 'Concluída com ≥75'),
        item(bola(MetricasCores.amarelo, MetricasCores.amarelo), 'Concluída'),
        item(bola(Colors.white, AppTheme.primaryOrange, largura: 2.5), 'Próxima'),
        item(bola(Colors.white, Colors.grey.shade300), 'Pendente'),
        Text('Toque numa fase para ver as notas', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}
