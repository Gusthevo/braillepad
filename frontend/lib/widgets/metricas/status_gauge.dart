import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'metricas_cores.dart';

/// Medidor circular com a média das últimas notas e o status colorido.
class StatusGauge extends StatelessWidget {
  final double? media;
  final String status;
  final String descricao;
  final int notasJanela;
  final int totalConcluidas;
  final int sessoesSemana;

  const StatusGauge({
    super.key,
    required this.media,
    required this.status,
    required this.descricao,
    required this.notasJanela,
    required this.totalConcluidas,
    required this.sessoesSemana,
  });

  @override
  Widget build(BuildContext context) {
    final cor = MetricasCores.porStatus(status);
    final cinza = status.toUpperCase() == 'CINZA';

    return Semantics(
      label: 'Média ${media?.toStringAsFixed(0) ?? 'indisponível'} pontos. '
          'Status: ${MetricasCores.rotuloStatus(status)}. $descricao',
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ((media ?? 0) / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => CustomPaint(
                painter: _GaugePainter(progresso: valor, cor: cinza ? Colors.grey.shade400 : cor),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        media != null ? (valor * 100).toStringAsFixed(0) : '—',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: cinza ? Colors.grey.shade600 : cor,
                          height: 1,
                        ),
                      ),
                      Text(
                        'média',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MetricasCores.iconeStatus(status), size: 16, color: cor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          MetricasCores.rotuloStatus(status),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  descricao,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pilula(
                      icone: Icons.local_fire_department_rounded,
                      cor: sessoesSemana > 0 ? AppTheme.primaryOrange : Colors.grey,
                      texto: '$sessoesSemana na semana',
                    ),
                    _Pilula(
                      icone: Icons.check_circle_rounded,
                      cor: Colors.teal,
                      texto: '$totalConcluidas concluída${totalConcluidas == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Média das últimas $notasJanela notas',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pilula extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;

  const _Pilula({required this.icone, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.warmBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progresso;
  final Color cor;

  _GaugePainter({required this.progresso, required this.cor});

  static const double _inicio = math.pi * 0.75; // 135°
  static const double _varredura = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 12.0;
    final rect = Rect.fromLTWH(espessura / 2, espessura / 2, size.width - espessura, size.height - espessura);

    final trilho = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _inicio, _varredura, false, trilho);

    // Marcas dos limiares amarelo (50) e verde (75)
    final centro = rect.center;
    final raio = rect.width / 2;
    for (final limiar in [MetricasCores.limiarAmarelo, MetricasCores.limiarVerde]) {
      final ang = _inicio + _varredura * limiar / 100;
      final p1 = centro + Offset(math.cos(ang), math.sin(ang)) * (raio - espessura);
      final p2 = centro + Offset(math.cos(ang), math.sin(ang)) * (raio - espessura - 5);
      canvas.drawLine(p1, p2, Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
    }

    if (progresso <= 0) return;
    final arco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _inicio, _varredura * progresso, false, arco);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progresso != progresso || old.cor != cor;
}
