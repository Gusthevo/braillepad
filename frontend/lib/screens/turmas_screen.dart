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
  bool _isGridView = false; // Toggle entre Lista e Grade (RF-007)
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

  void _showNovaTurmaModal() {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final descricaoController = TextEditingController();
    final anoEscolarController = TextEditingController(text: '1º Ano');
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
                        // Ano Escolar
                        Expanded(
                          child: TextFormField(
                            controller: anoEscolarController,
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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(modalContext);

                          final novaTurma = await TurmaService.createTurma(
                            nome: nomeController.text.trim(),
                            descricao: descricaoController.text.trim(),
                            anoLetivo: anoLetivo,
                            anoEscolar: anoEscolarController.text.trim(),
                            turno: turno,
                          );

                          if (mounted && novaTurma != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Turma criada com sucesso!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadTurmas();
                          }
                        },
                        child: const Text('Salvar Turma'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Minhas Turmas'),
        actions: [
          // Toggle Lista / Grade (RF-007)
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'Ver em Lista' : 'Ver em Grade',
          ),
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (val) {
              setState(() => _incluirArquivadas = val);
              _loadTurmas();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.check_rounded,
                        color: !_incluirArquivadas ? AppTheme.primaryOrange : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Apenas Turmas Ativas'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.check_rounded,
                        color: _incluirArquivadas ? AppTheme.primaryOrange : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Exibir Arquivadas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryOrange,
        onPressed: _showNovaTurmaModal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nova Turma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
              : _turmas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined, size: 70, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma turma cadastrada',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clique em "+ Nova Turma" para começar',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                      ? GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _turmas.length,
                          itemBuilder: (context, index) => _buildTurmaCard(_turmas[index]),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _turmas.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildTurmaCard(_turmas[index]),
                        ),
        ),
      ),
    );
  }

  Widget _buildTurmaCard(Map<String, dynamic> turma) {
    final isArquivada = turma['arquivada_em'] != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TurmaDetailScreen(turmaId: turma['id']),
            ),
          );
          _loadTurmas();
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
                  Expanded(
                    child: Text(
                      turma['nome'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  if (isArquivada)
                    const Chip(
                      label: Text('Arquivada', style: TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: Colors.grey,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                turma['descricao'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.primaryOrange),
                      const SizedBox(width: 4),
                      Text(
                        '${turma['total_alunos'] ?? 0} alunos',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    '${turma['ano_escolar'] ?? ''} • ${turma['turno'] ?? ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
