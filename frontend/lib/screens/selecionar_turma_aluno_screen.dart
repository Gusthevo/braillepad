import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/turma_service.dart';
import '../services/aluno_service.dart';
import '../services/sessao_service.dart';
import 'execucao_sessao_screen.dart';

class SelecionarTurmaAlunoScreen extends StatefulWidget {
  final Map<String, dynamic> atividade;

  const SelecionarTurmaAlunoScreen({
    super.key,
    required this.atividade,
  });

  @override
  State<SelecionarTurmaAlunoScreen> createState() => _SelecionarTurmaAlunoScreenState();
}

class _SelecionarTurmaAlunoScreenState extends State<SelecionarTurmaAlunoScreen> {
  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];

  String? _selectedTurmaId;
  String? _selectedAlunoId;

  bool _isLoadingTurmas = true;
  bool _isLoadingAlunos = false;
  bool _isStartingSession = false;

  @override
  void initState() {
    super.initState();
    _loadTurmas();
  }

  Future<void> _loadTurmas() async {
    setState(() => _isLoadingTurmas = true);
    final turmas = await TurmaService.getTurmas();
    if (mounted) {
      setState(() {
        _turmas = turmas;
        _isLoadingTurmas = false;
        if (turmas.isNotEmpty) {
          _selectedTurmaId = turmas.first['id'];
          _loadAlunosDaTurma(_selectedTurmaId!);
        }
      });
    }
  }

  Future<void> _loadAlunosDaTurma(String turmaId) async {
    setState(() {
      _isLoadingAlunos = true;
      _selectedAlunoId = null;
    });

    final alunos = await AlunoService.getAlunos(turmaId: turmaId);
    if (mounted) {
      setState(() {
        _alunos = alunos;
        _isLoadingAlunos = false;
        if (alunos.isNotEmpty) {
          _selectedAlunoId = alunos.first['id'];
        }
      });
    }
  }

  void _iniciarSessaoAtendimento({bool encerrarAnterior = false}) async {
    if (_selectedTurmaId == null || _selectedAlunoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma turma e um aluno para iniciar.')),
      );
      return;
    }

    setState(() => _isStartingSession = true);

    final sessao = await SessaoService.iniciarSessao(
      alunoId: _selectedAlunoId!,
      atividadeId: widget.atividade['id'],
      turmaId: _selectedTurmaId!,
      modoEntrada: 'MANUAL',
      encerrarAnterior: encerrarAnterior,
    );

    if (mounted) {
      setState(() => _isStartingSession = false);

      if (sessao != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExecucaoSessaoScreen(sessao: sessao),
          ),
        );
      } else {
        // Sugestão 2: Modal quando já existe sessão ativa
        _exibirDialogoSessaoConflito();
      }
    }
  }

  void _exibirDialogoSessaoConflito() async {
    final sessaoAtiva = await SessaoService.getSessaoAtiva();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Atendimento em Andamento'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Você já possui uma sessão ativa em andamento:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (sessaoAtiva != null) ...[
              Text('Aluno: ${sessaoAtiva['aluno_nome']}'),
              Text('Atividade: ${sessaoAtiva['atividade_titulo']}'),
              const SizedBox(height: 12),
            ],
            Text(
              'O que deseja fazer?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (sessaoAtiva != null) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExecucaoSessaoScreen(sessao: sessaoAtiva),
                  ),
                );
              }
            },
            child: const Text('Continuar Sessão Ativa'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            onPressed: () {
              Navigator.pop(dialogContext);
              _iniciarSessaoAtendimento(encerrarAnterior: true);
            },
            child: const Text('Encerrar Anterior (Parcial) e Iniciar Nova'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Seleção para Atendimento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoadingTurmas
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.extension_rounded, color: AppTheme.primaryOrange),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.atividade['titulo'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Ordem estrita: Módulo ➔ Atividade ➔ Turma ➔ Aluno',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Step 1: Selecionar Turma (RF-015)
                    const Text(
                      '1. Selecione a Turma:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 8),

                    _turmas.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Nenhuma turma ativa encontrada. Cadastre uma turma primeiro.'),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedTurmaId,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.groups_outlined, color: AppTheme.primaryOrange),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: _turmas.map((t) {
                              return DropdownMenuItem<String>(
                                value: t['id'],
                                child: Text(t['nome']),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedTurmaId = val);
                                _loadAlunosDaTurma(val);
                              }
                            },
                          ),

                    const SizedBox(height: 24),

                    // Step 2: Selecionar Aluno (RF-015)
                    const Text(
                      '2. Selecione o Aluno para o Atendimento:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 8),

                    _isLoadingAlunos
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
                        : _alunos.isEmpty
                            ? const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Nenhum aluno cadastrado nesta turma.'),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedAlunoId,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryOrange),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: _alunos.map((a) {
                                  return DropdownMenuItem<String>(
                                    value: a['id'],
                                    child: Text('${a['nome']} ${a['sobrenome']}'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedAlunoId = val);
                                },
                              ),

                    const Spacer(),

                    // Iniciar Atendimento Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_selectedTurmaId != null && _selectedAlunoId != null && !_isStartingSession)
                            ? () => _iniciarSessaoAtendimento(encerrarAnterior: false)
                            : null,
                        icon: _isStartingSession
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 24),
                        label: Text(
                          _isStartingSession ? 'Iniciando Sessão...' : 'Iniciar Atendimento Individual',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
