import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'metricas_cores.dart';

/// Linha de evolução das notas sobre faixas de status (vermelho/amarelo/verde).
///
/// [historico] vem do backend do mais recente para o mais antigo; o gráfico
/// desenha em ordem cronológica (esquerda = mais antigo).
class EvolucaoChart extends StatelessWidget {
  final List<Map<String, dynamic>> historico;

  const EvolucaoChart({super.key, required this.historico});

  @override
  Widget build(BuildContext context) {
    final pontos = historico.reversed
        .map((h) => _Ponto(
              nota: (h['nota'] as num).toDouble(),
              rotulo: formatarDataCurta(h['data'] as String?),
            ))
        .toList();

    if (pontos.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'O gráfico aparece após a primeira atividade concluída.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      );
    }

    final resumo = pontos.length >= 2
        ? 'Notas de ${pontos.first.nota.toStringAsFixed(0)} a ${pontos.last.nota.toStringAsFixed(0)} '
            'nas últimas ${pontos.length} atividades.'
        : 'Uma nota: ${pontos.first.nota.toStringAsFixed(0)}.';

    return Semantics(
      label: 'Gráfico de evolução. $resumo',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox(
          height: 170,
          width: double.infinity,
          child: CustomPaint(painter: _EvolucaoPainter(pontos: pontos, progresso: t)),
        ),
      ),
    );
  }
}

class _Ponto {
  final double nota;
  final String rotulo;
  const _Ponto({required this.nota, required this.rotulo});
}

class _EvolucaoPainter extends CustomPainter {
  final List<_Ponto> pontos;
  final double progresso;

  _EvolucaoPainter({required this.pontos, required this.progresso});

  @override
  void paint(Canvas canvas, Size size) {
    const margemEsq = 28.0;
    const margemDir = 12.0;
    const margemTopo = 10.0;
    const margemBase = 22.0;
    final area = Rect.fromLTRB(margemEsq, margemTopo, size.width - margemDir, size.height - margemBase);

    double y(double nota) => area.bottom - area.height * (nota.clamp(0, 100) / 100);

    // Faixas de status
    final faixas = [
      (0.0, MetricasCores.limiarAmarelo, MetricasCores.vermelho),
      (MetricasCores.limiarAmarelo, MetricasCores.limiarVerde, MetricasCores.amarelo),
      (MetricasCores.limiarVerde, 100.0, MetricasCores.verde),
    ];
    for (final (de, ate, cor) in faixas) {
      canvas.drawRect(
        Rect.fromLTRB(area.left, y(ate), area.right, y(de)),
        Paint()..color = cor.withValues(alpha: 0.08),
      );
    }

    // Eixo Y: 0, 50, 75, 100
    final estiloEixo = TextStyle(fontSize: 9, color: Colors.grey.shade500);
    for (final v in [0.0, MetricasCores.limiarAmarelo, MetricasCores.limiarVerde, 100.0]) {
      canvas.drawLine(
        Offset(area.left, y(v)),
        Offset(area.right, y(v)),
        Paint()
          ..color = Colors.grey.shade300
          ..strokeWidth = 0.6,
      );
      _texto(canvas, v.toStringAsFixed(0), Offset(0, y(v) - 6), estiloEixo, largura: margemEsq - 4, alinhar: TextAlign.right);
    }

    // Posições X
    final n = pontos.length;
    double x(int i) => n == 1 ? area.center.dx : area.left + area.width * i / (n - 1);
    final posicoes = [for (var i = 0; i < n; i++) Offset(x(i), y(pontos[i].nota))];

    // Linha (revelada progressivamente)
    if (n >= 2) {
      final caminho = Path()..moveTo(posicoes.first.dx, posicoes.first.dy);
      for (var i = 1; i < n; i++) {
        final ant = posicoes[i - 1];
        final atual = posicoes[i];
        final meioX = (ant.dx + atual.dx) / 2;
        caminho.cubicTo(meioX, ant.dy, meioX, atual.dy, atual.dx, atual.dy);
      }
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, area.left + (area.width + margemDir) * progresso, size.height));
      final preenchimento = Path.from(caminho)
        ..lineTo(posicoes.last.dx, area.bottom)
        ..lineTo(posicoes.first.dx, area.bottom)
        ..close();
      canvas.drawPath(
        preenchimento,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryOrange.withValues(alpha: 0.18), AppTheme.primaryOrange.withValues(alpha: 0)],
          ).createShader(area),
      );
      canvas.drawPath(
        caminho,
        Paint()
          ..color = AppTheme.primaryOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Pontos e rótulos de data
    final estiloData = TextStyle(fontSize: 9, color: Colors.grey.shade600);
    final mostrarTodasDatas = n <= 6;
    for (var i = 0; i < n; i++) {
      final visivel = n == 1 || (posicoes[i].dx - area.left) <= (area.width + margemDir) * progresso;
      if (!visivel) continue;
      final cor = MetricasCores.porValor(pontos[i].nota);
      final ultimo = i == n - 1;
      canvas.drawCircle(posicoes[i], ultimo ? 6 : 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(posicoes[i], ultimo ? 4.5 : 3.2, Paint()..color = cor);
      if (ultimo) {
        _texto(
          canvas,
          pontos[i].nota.toStringAsFixed(0),
          posicoes[i] + const Offset(-20, -20),
          TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor),
          largura: 40,
          alinhar: TextAlign.center,
        );
      }
      if (mostrarTodasDatas || i == 0 || ultimo) {
        _texto(canvas, pontos[i].rotulo, Offset(posicoes[i].dx - 20, area.bottom + 6), estiloData,
            largura: 40, alinhar: TextAlign.center);
      }
    }
  }

  void _texto(Canvas canvas, String texto, Offset pos, TextStyle estilo,
      {required double largura, TextAlign alinhar = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textAlign: alinhar,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: largura, maxWidth: largura);
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_EvolucaoPainter old) => old.progresso != progresso || old.pontos != pontos;
}
