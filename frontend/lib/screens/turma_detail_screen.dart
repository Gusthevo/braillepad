import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/turma_service.dart';

class TurmaDetailScreen extends StatefulWidget {
  final String turmaId;

  const TurmaDetailScreen({
    super.key,
    required this.turmaId,
  });

  @override
  State<TurmaDetailScreen> createState() => _TurmaDetailScreenState();
}

class _TurmaDetailScreenState extends State<TurmaDetailScreen> {
  Map<String, dynamic>? _turma;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTurmaDetail();
  }

  Future<void> _loadTurmaDetail() async {
    setState(() => _isLoading = true);
    final detail = await TurmaService.getTurmaDetail(widget.turmaId);
    if (mounted) {
      setState(() {
        _turma = detail;
        _isLoading = false;
      });
    }
  }

  void _handleArquivarTurma() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar Turma?'),
        content: const Text(
          'A turma será arquivada, mas todo o histórico de sessões e alunos continuará salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await TurmaService.arquivarTurma(widget.turmaId);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Turma arquivada com sucesso.')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.warmBackground,
        appBar: AppBar(title: const Text('Detalhes da Turma')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
      );
    }

    if (_turma == null) {
      return Scaffold(
        backgroundColor: AppTheme.warmBackground,
        appBar: AppBar(title: const Text('Detalhes da Turma')),
        body: const Center(child: Text('Turma não encontrada.')),
      );
    }

    final alunos = (_turma!['alunos'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: Text(_turma!['nome'] ?? 'Detalhes da Turma'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Colors.redAccent),
            onPressed: _handleArquivarTurma,
            tooltip: 'Arquivar Turma',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Header Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _turma!['nome'] ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _turma!['descricao'] ?? 'Sem descrição.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryOrange),
                          label: Text('Ano Letivo: ${_turma!['ano_letivo'] ?? '2026'}'),
                          backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        ),
                        Chip(
                          avatar: const Icon(Icons.school_rounded, size: 16, color: AppTheme.primaryOrange),
                          label: Text(_turma!['ano_escolar'] ?? '1º Ano'),
                          backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        ),
                        Chip(
                          avatar: const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryOrange),
                          label: Text(_turma!['turno'] ?? 'MANHA'),
                          backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Students Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alunos da Turma (${alunos.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Navegue para o Módulo de Alunos para adicionar alunos a esta turma.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Novo Aluno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // List of Students (RF-008)
            alunos.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum aluno cadastrado nesta turma',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: alunos.map((aluno) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                            child: const Icon(Icons.person_rounded, color: AppTheme.primaryOrange),
                          ),
                          title: Text(
                            '${aluno['nome']} ${aluno['sobrenome']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            aluno['familiaridade_braille'] != null
                                ? 'Braille: ${aluno['familiaridade_braille']}'
                                : 'Sem histórico',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {},
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
