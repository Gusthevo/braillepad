import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sessao_service.dart';
import 'resumo_sessao_screen.dart';

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
  final List<String> _vogaisAlvo = const ['A', 'E', 'I', 'O', 'U'];
  int _alvoIndexAtual = 0;
  int _tentativaAtual = 1;
  int _posicaoAtual = 1;
  int _totalAcertos = 0;
  int _totalErros = 0;

  void _registrarRespostaFicha(String fichaTocada) async {
    final esperado = _vogaisAlvo[_alvoIndexAtual];
    final isCorreta = fichaTocada == esperado;

    await SessaoService.registrarLeituraFicha(
      widget.sessao['id'],
      alvoId: 'alvo_${esperado.toLowerCase()}',
      posicao: _posicaoAtual,
      fichaCodigo: 'VOGAL_$fichaTocada',
      correta: isCorreta,
    );

    if (!mounted) return;

    if (isCorreta) {
      setState(() {
        _totalAcertos++;
        _tentativaAtual = 1;
        _posicaoAtual = 1;

        if (_alvoIndexAtual < _vogaisAlvo.length - 1) {
          _alvoIndexAtual++;
        } else {
          _concluirSessao();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Acerto! Ficha $fichaTocada reconhecida.'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
        ),
      );
    } else {
      // Regra de Erro RN-12: Incrementa tentativas e reinicia da 1ª posição
      setState(() {
        _totalErros++;
        _tentativaAtual++;
        _posicaoAtual = 1;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Ficha Incorreta'),
            ],
          ),
          content: Text(
            'A ficha apresentada foi "$fichaTocada", mas a esperada era "$esperado".\n\n'
            'Regra RN-12: A leitura deste alvo será reiniciada a partir da 1ª posição (Tentativa $_tentativaAtual).',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }
  }

  void _concluirSessao() async {
    final resumo = await SessaoService.finalizarSessao(
      widget.sessao['id'],
      nivelAjuda: 'NENHUMA',
      compreensao: 'TOTAL',
      comentario: 'Atendimento concluído com sucesso.',
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

  @override
  Widget build(BuildContext context) {
    final alvoAtualStr = _vogaisAlvo[_alvoIndexAtual];

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Execução de Atendimento (T13)'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outlined, color: Colors.green),
            onPressed: _concluirSessao,
            tooltip: 'Finalizar Atendimento',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header Card
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              widget.sessao['atividade_titulo'] ?? 'Atividade',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text('Tentativa $_tentativaAtual', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Active Target Card
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Alvo Solicitado (${_alvoIndexAtual + 1} / ${_vogaisAlvo.length}):',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryOrange,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            alvoAtualStr,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Apresente a ficha correspondente no PAD ou toque abaixo para registrar (Modo Manual):',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Touch Card Buttons
              const Text(
                'Fichas em Braille (Registrar Toque):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _vogaisAlvo.map((v) {
                  return SizedBox(
                    width: 60,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryOrange,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppTheme.primaryOrange, width: 2),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _registrarRespostaFicha(v),
                      child: Text(
                        v,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Live Stats Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 6),
                      Text('Acertos: $_totalAcertos', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 6),
                      Text('Erros: $_totalErros', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Finalizar Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _concluirSessao,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Finalizar Atendimento (RF-024)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
