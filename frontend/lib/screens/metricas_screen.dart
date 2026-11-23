import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/turma_service.dart';
import '../services/aluno_service.dart';
import '../services/metricas_service.dart';

class MetricasScreen extends StatefulWidget {
  const MetricasScreen({super.key});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];

  String? _selectedTurmaId;
  String? _selectedAlunoId;

  Map<String, dynamic>? _metricasAluno;
  Map<String, dynamic>? _metricasTurma;

  bool _isLoadingTurmas = true;
  bool _isLoadingMetricas = false;
  bool _erroAluno = false;
  bool _erroTurma = false;

  // Limiares padrão do config_metricas (usados só para colorir as barras).
  static const double _limiarVerde = 75.0;
  static const double _limiarAmarelo = 50.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingTurmas = true);
    final turmas = await TurmaService.getTurmas();
    if (!mounted) return;

    setState(() {
      _turmas = turmas;
      _isLoadingTurmas = false;
    });
    if (turmas.isNotEmpty) {
      await _onTurmaChanged(turmas.first['id']);
    }
  }

  Future<void> _onTurmaChanged(String turmaId) async {
    setState(() {
      _selectedTurmaId = turmaId;
      _selectedAlunoId = null;
      _alunos = [];
      _metricasAluno = null;
      _metricasTurma = null;
      _erroAluno = false;
      _erroTurma = false;
      _isLoadingMetricas = true;
    });

    final alunos = await AlunoService.getAlunos(turmaId: turmaId);
    final metricasTurma = await MetricasService.getMetricasTurma(turmaId);

    // Ignora a resposta se o professor já trocou de turma no meio do caminho.
    if (!mounted || _selectedTurmaId != turmaId) return;

    setState(() {
      _alunos = alunos;
      _metricasTurma = metricasTurma;
      _erroTurma = metricasTurma == null;
      if (alunos.isEmpty) _isLoadingMetricas = false;
    });

    if (alunos.isNotEmpty) {
      await _loadMetricasAluno(alunos.first['id']);
    }
  }

  Future<void> _loadMetricasAluno(String alunoId) async {
    setState(() {
      _selectedAlunoId = alunoId;
      _erroAluno = false;
      _isLoadingMetricas = true;
    });
    final metricas = await MetricasService.getMetricasAluno(alunoId);

    // Ignora a resposta se outro aluno foi selecionado enquanto carregava.
    if (!mounted || _selectedAlunoId != alunoId) return;

    setState(() {
      _metricasAluno = metricas;
      _erroAluno = metricas == null;
      _isLoadingMetricas = false;
    });
  }

  Future<void> _recarregar() async {
    final turmaId = _selectedTurmaId;
    final alunoId = _selectedAlunoId;
    if (turmaId == null) {
      await _loadInitialData();
      return;
    }
    await _onTurmaChanged(turmaId);
    if (alunoId != null &&
        alunoId != _selectedAlunoId &&
        _alunos.any((a) => a['id'] == alunoId)) {
      await _loadMetricasAluno(alunoId);
    }
  }

  String _formatarData(String? iso) {
    final dt = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(dt.day)}/${dois(dt.month)}/${dt.year}';
  }

  Color _corDaNota(double nota) {
    if (nota >= _limiarVerde) return Colors.green.shade700;
    if (nota >= _limiarAmarelo) return Colors.amber.shade800;
    return Colors.red.shade700;
  }

  Widget _buildErroCard(String mensagem) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.cloud_off_rounded, color: Colors.red.shade700),
        title: Text(mensagem,
            style: TextStyle(
                color: Colors.red.shade900, fontWeight: FontWeight.w600)),
        subtitle: const Text('Verifique a conexão com o servidor.'),
        trailing: TextButton(
            onPressed: _recarregar, child: const Text('Tentar de novo')),
      ),
    );
  }

  Widget _buildStatusColoridoBadge(String statusStr) {
    Color bg;
    IconData icon;
    String label;

    switch (statusStr.toUpperCase()) {
      case 'VERDE':
        bg = Colors.green.shade600;
        icon = Icons.check_circle_rounded;
        label = '🟢 Verde (Autonomia)';
        break;
      case 'AMARELO':
        bg = Colors.amber.shade800;
        icon = Icons.warning_amber_rounded;
        label = '🟡 Amarelo (Em Desenvolv.)';
        break;
      case 'VERMELHO':
        bg = Colors.red.shade600;
        icon = Icons.error_outline_rounded;
        label = '🔴 Vermelho (Precisa Apoio)';
        break;
      default:
        bg = Colors.grey.shade600;
        icon = Icons.help_outline_rounded;
        label = '⚪ Cinza (Dados Insufic.)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
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
        title: const Text('Métricas e Relatórios (T05)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoadingTurmas
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : RefreshIndicator(
                color: AppTheme.primaryOrange,
                onRefresh: _recarregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    // Filter Section Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filtros de Relatório:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),

                            // Turma Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTurmaId,
                              decoration: InputDecoration(
                                labelText: 'Turma',
                                prefixIcon: const Icon(Icons.groups_outlined,
                                    color: AppTheme.primaryOrange),
                                filled: true,
                                fillColor: AppTheme.warmBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                if (val != null) _onTurmaChanged(val);
                              },
                            ),

                            const SizedBox(height: 10),

                            // Aluno Dropdown
                            DropdownButtonFormField<String?>(
                              key: ValueKey(
                                  'alunos_${_selectedTurmaId}_${_alunos.length}'),
                              initialValue: _selectedAlunoId,
                              hint: Text(_isLoadingMetricas
                                  ? 'Carregando alunos...'
                                  : 'Nenhum aluno nesta turma'),
                              decoration: InputDecoration(
                                labelText: 'Aluno',
                                prefixIcon: const Icon(Icons.person_outline,
                                    color: AppTheme.primaryOrange),
                                filled: true,
                                fillColor: AppTheme.warmBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: _alunos.map((a) {
                                return DropdownMenuItem<String?>(
                                  value: a['id'],
                                  child: Text('${a['nome']} ${a['sobrenome']}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) _loadMetricasAluno(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _isLoadingMetricas
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryOrange))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_erroAluno)
                                _buildErroCard(
                                    'Não foi possível carregar as métricas do aluno.'),
                              if (_erroTurma)
                                _buildErroCard(
                                    'Não foi possível carregar o relatório da turma.'),

                              // 1. Status Colorido do Aluno (RF-031) - Margem Fixada com Expanded
                              if (_metricasAluno != null) ...[
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _metricasAluno!['aluno_nome'] ??
                                                    'Aluno',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildStatusColoridoBadge(
                                                _metricasAluno![
                                                        'status_colorido'] ??
                                                    'CINZA'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _metricasAluno!['descricao_status'] ??
                                              '',
                                          style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildMetricTile(
                                                'Média das últimas ${_metricasAluno!['notas_janela'] ?? 3} notas',
                                                _metricasAluno![
                                                            'media_notas'] !=
                                                        null
                                                    ? '${(_metricasAluno!['media_notas'] as num).toStringAsFixed(1)} pts'
                                                    : '—',
                                                Icons.analytics_rounded,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildMetricTile(
                                                'Sessões Concluídas',
                                                '${_metricasAluno!['total_sessoes_concluidas'] ?? 0}',
                                                Icons
                                                    .check_circle_outline_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 2. Histórico das Últimas Atividades / Notas
                                const SizedBox(height: 16),
                                const Text(
                                  'Histórico de Notas (mais recente primeiro):',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkText),
                                ),
                                const SizedBox(height: 8),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Builder(builder: (context) {
                                      final historico =
                                          (_metricasAluno!['historico']
                                                  as List?) ??
                                              const [];
                                      final janela =
                                          (_metricasAluno!['notas_janela']
                                                      as num?)
                                                  ?.toInt() ??
                                              3;
                                      if (historico.isEmpty) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12.0),
                                            child: Text(
                                              'Nenhuma atividade concluída com nota ainda.',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 13),
                                            ),
                                          ),
                                        );
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ...historico
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final h = entry.value
                                                as Map<String, dynamic>;
                                            final nota =
                                                (h['nota'] as num).toDouble();
                                            final pct = (h['percentual_acertos']
                                                    as num?)
                                                ?.toDouble();
                                            final cor = _corDaNota(nota);
                                            final entraNaMedia =
                                                entry.key < janela;
                                            final subtitulo = [
                                              h['modulo_nome'] ?? '',
                                              _formatarData(
                                                  h['data'] as String?),
                                              if (pct != null)
                                                'acertos ${pct.toStringAsFixed(0)}%',
                                            ]
                                                .where((e) =>
                                                    e.toString().isNotEmpty)
                                                .join(' · ');

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor:
                                                        cor.withValues(
                                                            alpha: entraNaMedia
                                                                ? 0.15
                                                                : 0.06),
                                                    child: Icon(
                                                      entraNaMedia
                                                          ? Icons.star_rounded
                                                          : Icons
                                                              .history_rounded,
                                                      size: 14,
                                                      color: cor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          h['atividade_titulo'] ??
                                                              'Atividade',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13),
                                                        ),
                                                        Text(
                                                          subtitulo,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey
                                                                  .shade600),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          child:
                                                              LinearProgressIndicator(
                                                            value: (nota /
                                                                    100.0)
                                                                .clamp(
                                                                    0.0, 1.0),
                                                            backgroundColor:
                                                                Colors.grey
                                                                    .shade200,
                                                            color: cor,
                                                            minHeight: 6,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    '${nota.toStringAsFixed(1)} pts',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: cor),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          const SizedBox(height: 6),
                                          Text(
                                            '★ = nota considerada no status (últimas $janela atividades concluídas).',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),

                                // 3. Alertas Pedagógicos (RF-032)
                                if ((_metricasAluno!['alertas'] as List?)
                                        ?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Alertas Pedagógicos:',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkText),
                                  ),
                                  const SizedBox(height: 8),
                                  ...(_metricasAluno!['alertas'] as List)
                                      .map((alerta) {
                                    final isEvolucao =
                                        alerta['tipo'] == 'EVOLUCAO';
                                    final isFicha =
                                        alerta['tipo'] == 'FICHA_DIFICIL';
                                    return Card(
                                      color: isEvolucao
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                      child: ListTile(
                                        leading: Icon(
                                          isEvolucao
                                              ? Icons.trending_up_rounded
                                              : (isFicha
                                                  ? Icons.touch_app_rounded
                                                  : Icons
                                                      .warning_amber_rounded),
                                          color: isEvolucao
                                              ? Colors.green.shade800
                                              : Colors.orange.shade900,
                                        ),
                                        title: Text(
                                          alerta['titulo'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isEvolucao
                                                ? Colors.green.shade900
                                                : Colors.orange.shade900,
                                          ),
                                        ),
                                        subtitle:
                                            Text(alerta['mensagem'] ?? ''),
                                      ),
                                    );
                                  }),
                                ],
                              ],

                              const SizedBox(height: 24),

                              // 3. Relatório Coletivo da Turma (RF-033)
                              if (_metricasTurma != null) ...[
                                const Text(
                                  'Relatório Coletivo da Turma:',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkText),
                                ),
                                const SizedBox(height: 8),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _metricasTurma!['turma_nome'] ??
                                              'Turma',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _metricasTurma!['media_turma'] != null
                                              ? 'Média da turma: ${(_metricasTurma!['media_turma'] as num).toStringAsFixed(1)} pts · ${_metricasTurma!['total_alunos'] ?? 0} alunos'
                                              : 'Média da turma: — (ainda sem alunos com status definido) · ${_metricasTurma!['total_alunos'] ?? 0} alunos',
                                          style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildStatusCountChip(
                                                '🟢 Verdes',
                                                _metricasTurma![
                                                        'alunos_verde'] ??
                                                    0,
                                                Colors.green.shade700),
                                            _buildStatusCountChip(
                                                '🟡 Amarelos',
                                                _metricasTurma![
                                                        'alunos_amarelo'] ??
                                                    0,
                                                Colors.amber.shade800),
                                            _buildStatusCountChip(
                                                '🔴 Vermelhos',
                                                _metricasTurma![
                                                        'alunos_vermelho'] ??
                                                    0,
                                                Colors.red.shade700),
                                            _buildStatusCountChip(
                                                '⚪ Cinzas',
                                                _metricasTurma![
                                                        'alunos_cinza'] ??
                                                    0,
                                                Colors.grey.shade600),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warmBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryOrange, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText)),
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStatusCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
