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
  String _nivelAjuda = 'NENHUMA';
  String _compreensao = 'TOTAL';
  double? _notaFinal;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notaFinal = (widget.sessao['nota'] as num?)?.toDouble() ?? 100.0;
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _salvarEFinalizar() async {
    setState(() => _isSaving = true);

    final res = await SessaoService.finalizarSessao(
      widget.sessao['id'],
      nivelAjuda: _nivelAjuda,
      compreensao: _compreensao,
      comentario: _comentarioController.text.trim().isNotEmpty ? _comentarioController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res != null) {
        setState(() {
          _notaFinal = (res['nota'] as num?)?.toDouble() ?? _notaFinal;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão e avaliação salvas com sucesso!'),
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
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Resumo da Sessão'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    // Score Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryOrange, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'Nota DTAE Calculada',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_notaFinal?.toStringAsFixed(1) ?? '100.0'} / 100',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Chip(
                              avatar: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                              label: Text(
                                widget.sessao['status'] ?? 'CONCLUIDA',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              backgroundColor: Colors.green.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Session Info Details
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aluno: ${widget.sessao['aluno_nome'] ?? 'Aluno'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Atividade: ${widget.sessao['atividade_titulo'] ?? 'Atividade'}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Mediação Pedagógica Section (RF-026)
                    const Text(
                      'Mediação e Avaliação Pedagógica:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 10),

                    // Nível de Ajuda Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _nivelAjuda,
                      decoration: InputDecoration(
                        labelText: 'Nível de Ajuda do Professor',
                        prefixIcon: const Icon(Icons.handshake_outlined, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'NENHUMA', child: Text('Sem Ajuda (+40 pts)')),
                        DropdownMenuItem(value: 'VERBAL', child: Text('Dica Verbal (+20 pts)')),
                        DropdownMenuItem(value: 'FISICA', child: Text('Mediação Intensa (+0 pts)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _nivelAjuda = val);
                          _salvarEFinalizar();
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Compreensão Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _compreensao,
                      decoration: InputDecoration(
                        labelText: 'Compreensão do Aluno',
                        prefixIcon: const Icon(Icons.psychology_outlined, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'TOTAL', child: Text('Compreensão Total (Sim)')),
                        DropdownMenuItem(value: 'PARCIAL', child: Text('Compreensão Parcial (Em parte)')),
                        DropdownMenuItem(value: 'NENHUMA', child: Text('Ainda Não')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _compreensao = val);
                          _salvarEFinalizar();
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Observações / Comentários (RF-026)
                    TextField(
                      controller: _comentarioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Observação Pedagógica da Sessão',
                        hintText: 'Ex: Apresentou excelente ritmo na percepção das vogais...',
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryOrange),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _salvarEFinalizar,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Salvando...' : 'Salvar Observações'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons: Repetir vs Concluir
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
