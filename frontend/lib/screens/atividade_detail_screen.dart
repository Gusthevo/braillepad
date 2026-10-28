import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/atividade_service.dart';
import 'selecionar_turma_aluno_screen.dart';

class AtividadeDetailScreen extends StatefulWidget {
  final String atividadeId;

  const AtividadeDetailScreen({
    super.key,
    required this.atividadeId,
  });

  @override
  State<AtividadeDetailScreen> createState() => _AtividadeDetailScreenState();
}

class _AtividadeDetailScreenState extends State<AtividadeDetailScreen> {
  Map<String, dynamic>? _atividade;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final detail = await AtividadeService.getAtividadeDetail(widget.atividadeId);
    if (mounted) {
      setState(() {
        _atividade = detail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.warmBackground,
        appBar: AppBar(title: const Text('Detalhes da Atividade')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
      );
    }

    if (_atividade == null) {
      return Scaffold(
        backgroundColor: AppTheme.warmBackground,
        appBar: AppBar(title: const Text('Detalhes da Atividade')),
        body: const Center(child: Text('Atividade não encontrada.')),
      );
    }

    final fases = (_atividade!['fases'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: Text(_atividade!['titulo'] ?? 'Atividade'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    // Header Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _atividade!['titulo'] ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _atividade!['descricao'] ?? '',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                            if (_atividade!['objetivo'] != null && _atividade!['objetivo'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Objetivo Pedagógico: ${_atividade!['objetivo']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryOrange),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Fases da Atividade Section
                    const Text(
                      'Fases da Atividade:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),

                    const SizedBox(height: 12),

                    fases.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('Fases padrão: Explorar, Em Ordem e Embaralhada.'),
                            ),
                          )
                        : Column(
                            children: fases.map((fase) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                                    child: Text(
                                      '${fase['ordem']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                                    ),
                                  ),
                                  title: Text(fase['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'Tipo: ${fase['tipo_fase']} • Pontuável: ${fase['pontuavel'] == true ? 'Sim' : 'Não'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Iniciar Atividade Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelecionarTurmaAlunoScreen(atividade: _atividade!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Selecionar Turma e Aluno (RF-015)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
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
