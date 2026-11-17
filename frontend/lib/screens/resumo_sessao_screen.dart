import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sessao_service.dart';
import 'main_shell_screen.dart';

class ResumoSessaoScreen extends StatefulWidget {
  final Map<String, dynamic> sessao;

  const ResumoSessaoScreen({
    super.key,
    required this.sessao,
  });

  @override
  State<ResumoSessaoScreen> createState() => _ResumoSessaoScreenState();
}

class _ResumoSessaoScreenState extends State<ResumoSessaoScreen> {
  final _comentarioController = TextEditingController();

  String _nivelAuxilioFase1 = 'INDEPENDENTE';
  String _nivelAuxilioFase2 = 'INDEPENDENTE';
  String _compreensaoInstrucoes = 'SIM';
  String _autonomiaExploracao = 'SIM';
  int _avaliacaoEstrelas = 5;

  bool _isSaving = false;

  final Map<int, String> _descricoesEstrelas = const {
    1: '★ Reconhecimento ainda não demonstrado.',
    2: '★★ Reconhecimento inicial, com necessidade de apoio frequente.',
    3: '★★★ Reconhecimento parcial, com necessidade de algumas intervenções.',
    4: '★★★★ Reconhecimento consistente na maioria das oportunidades.',
    5: '★★★★★ Reconhecimento consistente e com autonomia.',
  };

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  String _formatarDuracao(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _salvarAvaliacao() async {
    setState(() => _isSaving = true);

    final durSec = (widget.sessao['duracao_segundos'] as int?) ?? 0;

    final res = await SessaoService.finalizarSessao(
      widget.sessao['id'],
      duracaoSegundos: durSec,
      nivelAuxilioFase1: _nivelAuxilioFase1,
      nivelAuxilioFase2: _nivelAuxilioFase2,
      compreensaoInstrucoes: _compreensaoInstrucoes,
      autonomiaExploracao: _autonomiaExploracao,
      comentario: _comentarioController.text.trim().isNotEmpty ? _comentarioController.text.trim() : null,
      avaliacaoEstrelas: _avaliacaoEstrelas,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação pedagógica e observações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _repetirAtividade() async {
    final novaSessao = await SessaoService.iniciarSessao(
      alunoId: widget.sessao['aluno_id'],
      atividadeId: widget.sessao['atividade_id'],
      turmaId: widget.sessao['turma_historica_id'],
      modoEntrada: widget.sessao['modo_entrada'] ?? 'MANUAL',
    );

    if (mounted && novaSessao != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nova sessão iniciada para repetição (RF-025). Histórico anterior preservado!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertas = (widget.sessao['alertas_gerados'] as List?) ?? [];
    final duracaoSec = (widget.sessao['duracao_segundos'] as int?) ?? 0;
    final pctAcertos = (widget.sessao['percentual_acertos'] as num?)?.toDouble() ?? 100.0;

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Avaliação pelo Professor'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Header Resumo Card com Temporizador e Taxa de Acertos Real
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aluno: ${widget.sessao['aluno_nome'] ?? 'Aluno DTAE'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Atividade: ${widget.sessao['atividade_titulo'] ?? 'Atividade 01 — Vogais'}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        pctAcertos >= 75.0
                                            ? Icons.check_circle_rounded
                                            : (pctAcertos >= 50.0 ? Icons.warning_amber_rounded : Icons.cancel_rounded),
                                        color: pctAcertos >= 75.0 ? Colors.green : (pctAcertos >= 50.0 ? Colors.orange : Colors.red),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Acertos: ${pctAcertos.toStringAsFixed(1)}%',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: pctAcertos >= 75.0
                                                ? Colors.green.shade800
                                                : (pctAcertos >= 50.0 ? Colors.orange.shade900 : Colors.red.shade800),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, color: AppTheme.primaryOrange, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Duração: ${_formatarDuracao(duracaoSec)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Alertas Automáticos Gerados (Seção 1.1)
                    if (alertas.isNotEmpty) ...[
                      const Text(
                        'Alertas Automáticos da Atividade:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      const SizedBox(height: 8),
                      ...alertas.map((a) {
                        return Card(
                          color: Colors.orange.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            title: Text(a['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(a['mensagem'] ?? ''),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Questionário de Acompanhamento (Perguntas 1 a 4)
                    const Text(
                      'Acompanhamento do Professor (Nível de Auxílio):',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 12),

                    // Pergunta 1: Fase 01
                    DropdownButtonFormField<String>(
                      initialValue: _nivelAuxilioFase1,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Pergunta 1 — Nível de auxílio na Fase 01',
                        prefixIcon: const Icon(Icons.handshake_outlined, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'INDEPENDENTE', child: Text('Independente, sem auxílio', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'REPETICAO', child: Text('Precisou repetição de instruções', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'VERBAL', child: Text('Orientações verbais', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'TATIL', child: Text('Demonstração / Orientação tátil', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'DIRETO', child: Text('Auxílio direto e frequente', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'VARIOU', child: Text('Nível de auxílio variou', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _nivelAuxilioFase1 = val);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Pergunta 2: Fase 02
                    DropdownButtonFormField<String>(
                      initialValue: _nivelAuxilioFase2,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Pergunta 2 — Nível de auxílio na Fase 02',
                        prefixIcon: const Icon(Icons.handshake_outlined, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'INDEPENDENTE', child: Text('Independente, sem auxílio', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'REPETICAO', child: Text('Precisou repetição de instruções', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'VERBAL', child: Text('Orientações verbais', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'TATIL', child: Text('Demonstração / Orientação tátil', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'DIRETO', child: Text('Auxílio direto e frequente', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'VARIOU', child: Text('Nível de auxílio variou', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _nivelAuxilioFase2 = val);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Pergunta 3: Compreensão
                    DropdownButtonFormField<String>(
                      initialValue: _compreensaoInstrucoes,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Pergunta 3 — Compreendeu as instruções?',
                        prefixIcon: const Icon(Icons.psychology_outlined, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'SIM', child: Text('Sim, compreendeu e realizou', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'PARCIAL', child: Text('Compreendeu parcialmente', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'REPETIDAS', child: Text('Precisou de repetidas explicações', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'NAO_AVALIADO', child: Text('Não foi possível avaliar', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _compreensaoInstrucoes = val);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Pergunta 4: Autonomia
                    DropdownButtonFormField<String>(
                      initialValue: _autonomiaExploracao,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Pergunta 4 — Autonomia na exploração das fichas',
                        prefixIcon: const Icon(Icons.explore_outlined, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'SIM', child: Text('Sim, explorou autonomamente', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'PARCIAL', child: Text('Parcialmente, precisou orientações', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'NAO', child: Text('Não, precisou auxílio frequente', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'NAO_AVALIADO', child: Text('Não foi possível avaliar', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _autonomiaExploracao = val);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Avaliação Geral por Estrelas (1 a 5 ★★★★★)
                    const Text(
                      'Avaliação Geral do Professor (Escala de Estrelas):',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 8),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starVal = index + 1;
                                return IconButton(
                                  icon: Icon(
                                    starVal <= _avaliacaoEstrelas ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: Colors.amber.shade700,
                                    size: 36,
                                  ),
                                  onPressed: () {
                                    setState(() => _avaliacaoEstrelas = starVal);
                                  },
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _descricoesEstrelas[_avaliacaoEstrelas] ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Anotações Pedagógicas
                    TextField(
                      controller: _comentarioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Anotações e Observações Pedagógicas',
                        hintText: 'Registre dificuldades observadas, estratégias e intervenções realizadas...',
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _salvarAvaliacao,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Salvando...' : 'Salvar Avaliação pelo Professor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _repetirAtividade,
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryOrange),
                      label: const Text('Repetir Atividade', style: TextStyle(color: AppTheme.primaryOrange)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryOrange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MainShellScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Dashboard'),
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
