import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'alfabeto_tatil.dart';
import 'metricas_cores.dart';

/// Turma como grade de cartões (ordem alfabética, sem ranking entre alunos).
class TurmaGrid extends StatelessWidget {
  final Map<String, dynamic> turma;
  final String? alunoSelecionadoId;
  final ValueChanged<String> onSelecionar;

  const TurmaGrid({
    super.key,
    required this.turma,
    required this.alunoSelecionadoId,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final alunos = ((turma['alunos_metricas'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final media = (turma['media_turma'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                turma['turma_nome'] ?? 'Turma',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              media != null ? 'Média ${media.toStringAsFixed(0)}' : 'Média —',
              style: TextStyle(fontWeight: FontWeight.bold, color: MetricasCores.porValor(media)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BarraDistribuicao(turma: turma),
        const SizedBox(height: 14),
        if (alunos.isEmpty)
          Text('Nenhum aluno nesta turma.', style: TextStyle(color: Colors.grey.shade600))
        else
          LayoutBuilder(builder: (context, constraints) {
            const espaco = 10.0;
            final colunas = constraints.maxWidth >= 520 ? 3 : 2;
            final largura = (constraints.maxWidth - espaco * (colunas - 1)) / colunas;
            return Wrap(
              spacing: espaco,
              runSpacing: espaco,
              children: [
                for (final a in alunos)
                  SizedBox(
                    width: largura,
                    child: _CartaoAluno(
                      aluno: a,
                      selecionado: a['aluno_id'] == alunoSelecionadoId,
                      onTap: () => onSelecionar(a['aluno_id'] as String),
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _BarraDistribuicao extends StatelessWidget {
  final Map<String, dynamic> turma;

  const _BarraDistribuicao({required this.turma});

  @override
  Widget build(BuildContext context) {
    final grupos = [
      ('VERDE', (turma['alunos_verde'] as num?)?.toInt() ?? 0),
      ('AMARELO', (turma['alunos_amarelo'] as num?)?.toInt() ?? 0),
      ('VERMELHO', (turma['alunos_vermelho'] as num?)?.toInt() ?? 0),
      ('CINZA', (turma['alunos_cinza'] as num?)?.toInt() ?? 0),
    ];
    final total = grupos.fold<int>(0, (s, g) => s + g.$2);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final (status, qtd) in grupos)
                  if (qtd > 0) Expanded(flex: qtd, child: Container(color: MetricasCores.porStatus(status))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final (status, qtd) in grupos)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: MetricasCores.porStatus(status), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('${MetricasCores.rotuloStatus(status)}: $qtd',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _CartaoAluno extends StatelessWidget {
  final Map<String, dynamic> aluno;
  final bool selecionado;
  final VoidCallback onTap;

  const _CartaoAluno({required this.aluno, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nome = (aluno['aluno_nome'] as String? ?? '').trim();
    final partes = nome.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciais = partes.isEmpty
        ? '?'
        : (partes.first[0] + (partes.length > 1 ? partes.last[0] : '')).toUpperCase();
    final status = aluno['status_colorido'] as String? ?? 'CINZA';
    final cor = MetricasCores.porStatus(status);
    final media = (aluno['media_notas'] as num?)?.toDouble();
    final fichas = ((aluno['fichas'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final alertas = (aluno['alertas'] as List?)?.length ?? 0;

    return Material(
      color: selecionado ? AppTheme.primaryOrange.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionado ? AppTheme.primaryOrange : Colors.grey.shade200,
              width: selecionado ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: cor.withValues(alpha: 0.15),
                    child: Text(iniciais, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome.isEmpty ? 'Aluno' : nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          media != null ? '${media.toStringAsFixed(0)} pts' : 'sem nota',
                          style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (alertas > 0)
                    Tooltip(
                      message: '$alertas alerta${alertas == 1 ? '' : 's'} pedagógico${alertas == 1 ? '' : 's'}',
                      child: Icon(Icons.notifications_active_rounded, size: 16, color: Colors.orange.shade700),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              AlfabetoTatil(fichas: fichas, compacta: true),
            ],
          ),
        ),
      ),
    );
  }
}
