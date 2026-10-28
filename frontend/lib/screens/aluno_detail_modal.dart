import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/aluno_service.dart';
import '../services/turma_service.dart';

class AlunoDetailModal extends StatefulWidget {
  final String alunoId;
  final VoidCallback onUpdated;

  const AlunoDetailModal({
    super.key,
    required this.alunoId,
    required this.onUpdated,
  });

  @override
  State<AlunoDetailModal> createState() => _AlunoDetailModalState();
}

class _AlunoDetailModalState extends State<AlunoDetailModal> {
  Map<String, dynamic>? _aluno;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final detail = await AlunoService.getAlunoDetail(widget.alunoId);
    if (mounted) {
      setState(() {
        _aluno = detail;
        _isLoading = false;
      });
    }
  }

  void _showTransferirModal() async {
    final turmas = await TurmaService.getTurmas();
    final turmasDestino = turmas.where((t) => t['id'] != _aluno?['turma_atual_id']).toList();

    if (!mounted) return;

    if (turmasDestino.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não existem outras turmas ativas disponíveis para transferência.')),
      );
      return;
    }

    String? turmaDestinoId = turmasDestino.first['id'];
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryOrange),
              SizedBox(width: 8),
              Text('Transferir Aluno'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aluno: ${_aluno?['nome']} ${_aluno?['sobrenome']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Turma Atual: ${_aluno?['turma_nome']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Dropdown Turma de Destino
              DropdownButtonFormField<String>(
                initialValue: turmaDestinoId,
                decoration: InputDecoration(
                  labelText: 'Turma de Destino *',
                  filled: true,
                  fillColor: AppTheme.warmBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: turmasDestino.map((t) {
                  return DropdownMenuItem<String>(
                    value: t['id'],
                    child: Text(t['nome']),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => turmaDestinoId = val),
              ),

              const SizedBox(height: 12),

              // Motivo
              TextField(
                controller: motivoController,
                decoration: InputDecoration(
                  labelText: 'Motivo da Transferência (opcional)',
                  hintText: 'Ex: Mudança de horário/turno',
                  filled: true,
                  fillColor: AppTheme.warmBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
              onPressed: () async {
                if (turmaDestinoId == null) return;
                Navigator.pop(dialogContext);

                final res = await AlunoService.transferirAluno(
                  widget.alunoId,
                  turmaDestinoId: turmaDestinoId!,
                  motivo: motivoController.text.trim().isNotEmpty ? motivoController.text.trim() : null,
                );

                if (mounted && res != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aluno transferido com sucesso! Histórico preservado.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  widget.onUpdated();
                  _loadDetail();
                }
              },
              child: const Text('Confirmar Transferência'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleArquivar() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar Aluno?'),
        content: const Text(
          'O aluno será arquivado, mas todo o histórico de sessões e tentativas continuará preservado.',
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
              final ok = await AlunoService.arquivarAluno(widget.alunoId);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aluno arquivado com sucesso.')),
                );
                widget.onUpdated();
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
      return Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
      );
    }

    if (_aluno == null) {
      return Container(
        height: 250,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: Text('Aluno não encontrado.')),
      );
    }

    final transferencias = (_aluno!['historico_transferencias'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Avatar & Name
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                  child: const Icon(Icons.person_rounded, size: 36, color: AppTheme.primaryOrange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_aluno!['nome']} ${_aluno!['sobrenome']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.groups_rounded, size: 16, color: AppTheme.primaryOrange),
                          const SizedBox(width: 4),
                          Text(
                            _aluno!['turma_nome'] ?? 'Sem Turma',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Braille Familiarity & Info Chips
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.grain_rounded, size: 16, color: AppTheme.primaryOrange),
                  label: Text('Braille: ${_aluno!['nivel_braille'] ?? 'INICIANTE'}'),
                  backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                ),
                if (_aluno!['matricula'] != null && _aluno!['matricula'].toString().isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.badge_outlined, size: 16, color: Colors.blue),
                    label: Text('Matrícula: ${_aluno!['matricula']}'),
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  ),
              ],
            ),

            if (_aluno!['observacoes_pedagogicas'] != null &&
                _aluno!['observacoes_pedagogicas'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Observações Pedagógicas:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warmBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _aluno!['observacoes_pedagogicas'],
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                ),
              ),
            ],

            // Transfer History Section (RF-011)
            if (transferencias.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Histórico de Transferências:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...transferencias.map((tr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${tr['turma_origem_nome']} ➔ ${tr['turma_destino_nome']}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showTransferirModal,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Transferir Turma'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _handleArquivar,
                  icon: const Icon(Icons.archive_outlined, size: 18, color: Colors.redAccent),
                  label: const Text('Arquivar', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
