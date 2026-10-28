import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/aluno_service.dart';
import '../services/turma_service.dart';
import 'aluno_detail_modal.dart';

class AlunosScreen extends StatefulWidget {
  final String? initialTurmaId;

  const AlunosScreen({
    super.key,
    this.initialTurmaId,
  });

  @override
  State<AlunosScreen> createState() => _AlunosScreenState();
}

class _AlunosScreenState extends State<AlunosScreen> {
  List<Map<String, dynamic>> _alunos = [];
  List<Map<String, dynamic>> _turmas = [];
  bool _isLoading = true;

  String? _selectedTurmaFilterId;
  String _searchQuery = '';
  bool _incluirArquivados = false;

  @override
  void initState() {
    super.initState();
    _selectedTurmaFilterId = widget.initialTurmaId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final turmas = await TurmaService.getTurmas();
    final alunos = await AlunoService.getAlunos(
      turmaId: _selectedTurmaFilterId,
      incluirArquivados: _incluirArquivados,
    );

    if (mounted) {
      setState(() {
        _turmas = turmas;
        _alunos = alunos;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAlunos {
    if (_searchQuery.isEmpty) return _alunos;
    return _alunos.where((a) {
      final nomeCompleto = '${a['nome']} ${a['sobrenome']}'.toLowerCase();
      return nomeCompleto.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showNovoAlunoModal() async {
    if (_turmas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre ao menos uma turma antes de adicionar alunos.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final sobrenomeController = TextEditingController();
    final matriculaController = TextEditingController();
    final observacoesController = TextEditingController();

    String turmaSelecionadaId = _selectedTurmaFilterId ?? _turmas.first['id'];
    String nivelBraille = 'INICIANTE';

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
                      'Cadastrar Novo Aluno',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Turma Mandatória Dropdown (RF-009)
                    DropdownButtonFormField<String>(
                      initialValue: turmaSelecionadaId,
                      decoration: InputDecoration(
                        labelText: 'Turma Atual *',
                        prefixIcon: const Icon(Icons.groups_outlined),
                        filled: true,
                        fillColor: AppTheme.warmBackground,
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
                        if (val != null) setModalState(() => turmaSelecionadaId = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Nome
                    TextFormField(
                      controller: nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome do Aluno *',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: AppTheme.warmBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe o nome do aluno';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Sobrenome
                    TextFormField(
                      controller: sobrenomeController,
                      decoration: InputDecoration(
                        labelText: 'Sobrenome *',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: AppTheme.warmBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe o sobrenome do aluno';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        // Matrícula
                        Expanded(
                          child: TextFormField(
                            controller: matriculaController,
                            decoration: InputDecoration(
                              labelText: 'Matrícula (opcional)',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: AppTheme.warmBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Nível de Braille
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: nivelBraille,
                            decoration: InputDecoration(
                              labelText: 'Nível Braille',
                              filled: true,
                              fillColor: AppTheme.warmBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'INICIANTE', child: Text('Iniciante')),
                              DropdownMenuItem(value: 'EM_APRENDIZAGEM', child: Text('Aprendizagem')),
                              DropdownMenuItem(value: 'FAMILIARIZADO', child: Text('Familiarizado')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => nivelBraille = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Observações Pedagógicas
                    TextFormField(
                      controller: observacoesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observações Pedagógicas (opcional)',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        filled: true,
                        fillColor: AppTheme.warmBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(modalContext);

                          final res = await AlunoService.createAluno(
                            turmaAtualId: turmaSelecionadaId,
                            nome: nomeController.text.trim(),
                            sobrenome: sobrenomeController.text.trim(),
                            matricula: matriculaController.text.trim().isNotEmpty ? matriculaController.text.trim() : null,
                            nivelBraille: nivelBraille,
                            observacoesPedagogicas: observacoesController.text.trim().isNotEmpty ? observacoesController.text.trim() : null,
                          );

                          if (mounted && res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Aluno cadastrado com sucesso!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          }
                        },
                        child: const Text('Salvar Aluno'),
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

  void _showAlunoDetailModal(String alunoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlunoDetailModal(
        alunoId: alunoId,
        onUpdated: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAlunos;

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Gestão de Alunos'),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (val) {
              setState(() => _incluirArquivados = val);
              _loadData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.check_rounded,
                        color: !_incluirArquivados ? AppTheme.primaryOrange : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Apenas Alunos Ativos'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.check_rounded,
                        color: _incluirArquivados ? AppTheme.primaryOrange : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Exibir Arquivados'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryOrange,
        onPressed: _showNovoAlunoModal,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Novo Aluno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Buscar aluno por nome...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryOrange),
                      filled: true,
                      fillColor: AppTheme.warmBackground,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Dropdown by Turma
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedTurmaFilterId,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por Turma',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.warmBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas as Turmas'),
                      ),
                      ..._turmas.map((t) {
                        return DropdownMenuItem<String?>(
                          value: t['id'],
                          child: Text(t['nome']),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedTurmaFilterId = val);
                      _loadData();
                    },
                  ),
                ],
              ),
            ),

            // Student List View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 70, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum aluno encontrado',
                                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Clique em "+ Novo Aluno" para cadastrar',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final aluno = filtered[index];
                            final isArquivado = aluno['arquivado_em'] != null;

                            return Card(
                              child: ListTile(
                                onTap: () => _showAlunoDetailModal(aluno['id']),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                                  child: const Icon(Icons.person_rounded, color: AppTheme.primaryOrange),
                                ),
                                title: Text(
                                  '${aluno['nome']} ${aluno['sobrenome']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Text(
                                  'Turma: ${aluno['turma_nome']} • Braille: ${aluno['nivel_braille'] ?? 'INICIANTE'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: isArquivado
                                    ? const Chip(
                                        label: Text('Arquivado', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: Colors.grey,
                                      )
                                    : const Icon(Icons.chevron_right_rounded),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
