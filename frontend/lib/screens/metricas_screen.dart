import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/turma_service.dart';
import '../services/aluno_service.dart';
import '../services/metricas_service.dart';
import '../widgets/metricas/alfabeto_tatil.dart';
import '../widgets/metricas/evolucao_chart.dart';
import '../widgets/metricas/metricas_cores.dart';
import '../widgets/metricas/status_gauge.dart';
import '../widgets/metricas/trilha_modulos.dart';
import '../widgets/metricas/turma_grid.dart';

class MetricasScreen extends StatefulWidget {
  const MetricasScreen({super.key});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  final _scrollController = ScrollController();

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Carregamento
  // ---------------------------------------------------------------------------

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
    if (alunoId != null && alunoId != _selectedAlunoId && _alunos.any((a) => a['id'] == alunoId)) {
      await _loadMetricasAluno(alunoId);
    }
  }

  void _selecionarAlunoDaGrade(String alunoId) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
    if (alunoId != _selectedAlunoId) _loadMetricasAluno(alunoId);
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Métricas e Relatórios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoadingTurmas
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : RefreshIndicator(
                color: AppTheme.primaryOrange,
                onRefresh: _recarregar,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _buildFiltros(),
                    const SizedBox(height: 16),
                    if (_erroAluno) _buildErroCard('Não foi possível carregar as métricas do aluno.'),
                    if (_erroTurma) _buildErroCard('Não foi possível carregar o relatório da turma.'),
                    if (_isLoadingMetricas && _metricasAluno == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                      ),
                    if (_metricasAluno != null)
                      AnimatedOpacity(
                        opacity: _isLoadingMetricas ? 0.4 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: _buildPainelAluno(_metricasAluno!),
                      ),
                    if (_metricasTurma != null) ...[
                      const SizedBox(height: 8),
                      _Secao(
                        icone: Icons.groups_rounded,
                        titulo: 'Turma',
                        subtitulo: 'Toque num aluno para ver o painel dele',
                        child: TurmaGrid(
                          turma: _metricasTurma!,
                          alunoSelecionadoId: _selectedAlunoId,
                          onSelecionar: _selecionarAlunoDaGrade,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFiltros() {
    InputDecoration deco(String rotulo, IconData icone) => InputDecoration(
          labelText: rotulo,
          prefixIcon: Icon(icone, color: AppTheme.primaryOrange),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        );

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('turmas_${_turmas.length}_$_selectedTurmaId'),
            initialValue: _selectedTurmaId,
            isExpanded: true,
            decoration: deco('Turma', Icons.groups_outlined),
            items: [
              for (final t in _turmas)
                DropdownMenuItem<String>(
                  value: t['id'],
                  child: Text(t['nome'] ?? '', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (val) {
              if (val != null && val != _selectedTurmaId) _onTurmaChanged(val);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String?>(
            // Recria o campo quando a turma ou o aluno mudam (initialValue só é lido uma vez).
            key: ValueKey('alunos_${_selectedTurmaId}_${_alunos.length}_$_selectedAlunoId'),
            initialValue: _selectedAlunoId,
            isExpanded: true,
            hint: Text(_isLoadingMetricas ? 'Carregando...' : 'Sem alunos', overflow: TextOverflow.ellipsis),
            decoration: deco('Aluno', Icons.person_outline),
            items: [
              for (final a in _alunos)
                DropdownMenuItem<String?>(
                  value: a['id'],
                  child: Text('${a['nome']} ${a['sobrenome']}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (val) {
              if (val != null) _loadMetricasAluno(val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPainelAluno(Map<String, dynamic> m) {
    final historico = ((m['historico'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final modulos = ((m['progresso_modulos'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final fichas = ((m['fichas'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final alertas = ((m['alertas'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final janela = (m['notas_janela'] as num?)?.toInt() ?? 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Medidor de status
        _Secao(
          icone: Icons.person_rounded,
          titulo: m['aluno_nome'] ?? 'Aluno',
          subtitulo: m['turma_nome'],
          child: StatusGauge(
            media: (m['media_notas'] as num?)?.toDouble(),
            status: m['status_colorido'] ?? 'CINZA',
            descricao: m['descricao_status'] ?? '',
            notasJanela: janela,
            totalConcluidas: (m['total_sessoes_concluidas'] as num?)?.toInt() ?? 0,
            sessoesSemana: (m['sessoes_semana'] as num?)?.toInt() ?? 0,
          ),
        ),

        // 2. Alertas pedagógicos logo abaixo do status, para não passarem despercebidos
        if (alertas.isNotEmpty) ...[
          for (final a in alertas) _AlertaCard(alerta: a),
          const SizedBox(height: 4),
        ],

        // 3. Trilha
        _Secao(
          icone: Icons.route_rounded,
          titulo: 'Trilha de atividades',
          child: TrilhaModulos(modulos: modulos),
        ),

        // 4. Alfabeto tátil
        _Secao(
          icone: Icons.grid_view_rounded,
          titulo: 'Alfabeto tátil',
          subtitulo: 'Acerto por ficha · toque para ver detalhes',
          child: fichas.any((f) => f['percentual'] != null)
              ? AlfabetoTatil(fichas: fichas)
              : Text(
                  'As fichas aparecem coloridas depois das primeiras leituras no PAD.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
        ),

        // 5. Evolução
        _Secao(
          icone: Icons.show_chart_rounded,
          titulo: 'Evolução das notas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EvolucaoChart(historico: historico),
              if (historico.isNotEmpty) ...[
                const Divider(height: 24),
                for (final (i, h) in historico.indexed) _LinhaHistorico(sessao: h, naMedia: i < janela),
                const SizedBox(height: 4),
                Text(
                  '★ = conta na média do status (últimas $janela atividades concluídas).',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErroCard(String mensagem) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.cloud_off_rounded, color: Colors.red.shade700),
        title: Text(mensagem, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600)),
        subtitle: const Text('Verifique a conexão com o servidor.'),
        trailing: TextButton(onPressed: _recarregar, child: const Text('Tentar de novo')),
      ),
    );
  }
}

/// Cartão de seção com ícone e título.
class _Secao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final Widget child;

  const _Secao({required this.icone, required this.titulo, this.subtitulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, size: 18, color: AppTheme.primaryOrange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      if (subtitulo != null && subtitulo!.isNotEmpty)
                        Text(subtitulo!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _AlertaCard extends StatelessWidget {
  final Map<String, dynamic> alerta;

  const _AlertaCard({required this.alerta});

  @override
  Widget build(BuildContext context) {
    final tipo = alerta['tipo'] as String? ?? '';
    final (icone, cor, fundo) = switch (tipo) {
      'EVOLUCAO' => (Icons.trending_up_rounded, Colors.green.shade800, Colors.green.shade50),
      'FICHA_DIFICIL' => (Icons.touch_app_rounded, Colors.deepOrange.shade800, Colors.deepOrange.shade50),
      _ => (Icons.trending_down_rounded, Colors.red.shade800, Colors.red.shade50),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: fundo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icone, color: cor),
        title: Text(alerta['titulo'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 14)),
        subtitle: Text(alerta['mensagem'] ?? '', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  final Map<String, dynamic> sessao;
  final bool naMedia;

  const _LinhaHistorico({required this.sessao, required this.naMedia});

  @override
  Widget build(BuildContext context) {
    final nota = (sessao['nota'] as num).toDouble();
    final pct = (sessao['percentual_acertos'] as num?)?.toDouble();
    final cor = MetricasCores.porValor(nota);
    final subtitulo = [
      formatarDataCurta(sessao['data'] as String?, comAno: true),
      if (pct != null) 'acertos ${pct.toStringAsFixed(0)}%',
    ].where((e) => e.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: naMedia ? const Icon(Icons.star_rounded, size: 16, color: AppTheme.amberAccent) : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessao['atividade_titulo'] ?? 'Atividade',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(
              nota.toStringAsFixed(0),
              style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
