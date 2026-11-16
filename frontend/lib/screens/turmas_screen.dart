import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/turma_service.dart';
import 'turma_detail_screen.dart';

class TurmasScreen extends StatefulWidget {
  const TurmasScreen({super.key});

  @override
  State<TurmasScreen> createState() => _TurmasScreenState();
}

class _TurmasScreenState extends State<TurmasScreen> {
  List<Map<String, dynamic>> _turmas = [];
  bool _isLoading = true;
  bool _isGridView = false;
  bool _incluirArquivadas = false;

  @override
  void initState() {
    super.initState();
    _loadTurmas();
  }

  Future<void> _loadTurmas() async {
    setState(() => _isLoading = true);
    final turmas = await TurmaService.getTurmas(incluirArquivadas: _incluirArquivadas);
    if (mounted) {
      setState(() {
        _turmas = turmas;
        _isLoading = false;
      });
    }
  }

  void _showCreateTurmaModal() {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final descricaoController = TextEditingController();
    String anoEscolar = '1º Ano';
    int anoLetivo = DateTime.now().year;
    String turno = 'MANHA';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
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
                    const Text(
                      'Criar Nova Turma',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nome da Turma
                    TextFormField(
                      controller: nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome da Turma *',
                        hintText: 'Ex: Turma A - Manhã',
                        prefixIcon: const Icon(Icons.groups_outlined),
                        filled: true,
                        fillColor: AppTheme.warmBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe o nome da turma';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Descrição
                    TextFormField(
                      controller: descricaoController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Descrição / Observação *',
                        hintText: 'Ex: Atendimento AEE para alfabetização',
                        prefixIcon: const Icon(Icons.description_outlined),
                        filled: true,
                        fillColor: AppTheme.warmBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe a descrição da turma';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        // Ano Escolar Dropdown (1º Ano ao 3º Ano)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: anoEscolar,
                            decoration: InputDecoration(
                              labelText: 'Ano Escolar',
                              prefixIcon: const Icon(Icons.school_outlined),
                              filled: true,
                              fillColor: AppTheme.warmBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: '1º Ano', child: Text('1º Ano')),
                              DropdownMenuItem(value: '2º Ano', child: Text('2º Ano')),
                              DropdownMenuItem(value: '3º Ano', child: Text('3º Ano')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => anoEscolar = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Turno Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: turno,
                            decoration: InputDecoration(
                              labelText: 'Turno',
                              filled: true,
                              fillColor: AppTheme.warmBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MANHA', child: Text('Manhã')),
                              DropdownMenuItem(value: 'TARDE', child: Text('Tarde')),
                              DropdownMenuItem(value: 'NOITE', child: Text('Noite')),
                              DropdownMenuItem(value: 'INTEGRAL', child: Text('Integral')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => turno = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final res = await TurmaService.createTurma(
                            nome: nomeController.text.trim(),
                            descricao: descricaoController.text.trim(),
                            anoLetivo: anoLetivo,
                            anoEscolar: anoEscolar,
                            turno: turno,
                          );

                          if (modalContext.mounted) {
                            Navigator.pop(modalContext);
                          }
                          if (mounted) {
                            if (res != null) {
                              _loadTurmas();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Turma criada com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Erro ao criar turma.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Salvar Turma',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _arquivarTurma(String turmaId, String nome) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar Turma?'),
        content: Text('A turma "$nome" será arquivada. O histórico dos alunos continuará preservado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await TurmaService.arquivarTurma(turmaId);
              if (mounted && ok) {
                _loadTurmas();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Turma arquivada com sucesso.')),
                );
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
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Gestão de Turmas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Toggle View Mode (List vs Grid)
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'Ver em Lista' : 'Ver em Grade',
          ),
          // Filter Archived
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (val) {
              setState(() => _incluirArquivadas = val);
              _loadTurmas();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: false,
                child: Text('Apenas Turmas Ativas'),
              ),
              const PopupMenuItem(
                value: true,
                child: Text('Incluir Arquivadas'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : _turmas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma turma encontrada',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('Clique no botão abaixo para criar sua primeira turma.'),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTurmas,
                    color: AppTheme.primaryOrange,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _isGridView ? _buildGridView() : _buildListView(),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTurmaModal,
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Turma'),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      itemCount: _turmas.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = _turmas[index];
        final isArquivada = t['arquivada_em'] != null;

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isArquivada
                  ? Colors.grey.shade300
                  : AppTheme.primaryOrange.withValues(alpha: 0.15),
              child: Icon(
                Icons.groups_rounded,
                color: isArquivada ? Colors.grey.shade600 : AppTheme.primaryOrange,
              ),
            ),
            title: Text(
              t['nome'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isArquivada ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '${t['ano_escolar'] ?? '1º Ano'} • ${t['turno'] ?? 'MANHA'} • ${t['total_alunos'] ?? 0} alunos',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isArquivada)
                  IconButton(
                    icon: const Icon(Icons.archive_outlined, color: Colors.orange),
                    onPressed: () => _arquivarTurma(t['id'], t['nome']),
                    tooltip: 'Arquivar Turma',
                  ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TurmaDetailScreen(turmaId: t['id']),
                ),
              ).then((_) => _loadTurmas());
            },
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final t = _turmas[index];
        final isArquivada = t['arquivada_em'] != null;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TurmaDetailScreen(turmaId: t['id']),
                ),
              ).then((_) => _loadTurmas());
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                        child: const Icon(Icons.groups_rounded, color: AppTheme.primaryOrange),
                      ),
                      if (!isArquivada)
                        IconButton(
                          icon: const Icon(Icons.archive_outlined, color: Colors.orange, size: 20),
                          onPressed: () => _arquivarTurma(t['id'], t['nome']),
                          tooltip: 'Arquivar',
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['nome'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t['ano_escolar'] ?? '1º Ano'} • ${t['total_alunos'] ?? 0} alunos',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
