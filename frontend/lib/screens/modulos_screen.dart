import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/atividade_service.dart';
import 'atividade_detail_screen.dart';

class ModulosScreen extends StatefulWidget {
  const ModulosScreen({super.key});

  @override
  State<ModulosScreen> createState() => _ModulosScreenState();
}

class _ModulosScreenState extends State<ModulosScreen> {
  List<Map<String, dynamic>> _modulos = [];
  final Map<int, List<Map<String, dynamic>>> _atividadesPorModulo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    final modulos = await AtividadeService.getModulos();

    for (var m in modulos) {
      final modId = m['id'] as int;
      final atvs = await AtividadeService.getAtividadesPorModulo(modId);
      _atividadesPorModulo[modId] = atvs;
    }

    if (mounted) {
      setState(() {
        _modulos = modulos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Catálogo de Atividades DTAE'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
              : _modulos.isEmpty
                  ? const Center(child: Text('Nenhum módulo encontrado.'))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _modulos.length,
                      itemBuilder: (context, index) {
                        final mod = _modulos[index];
                        final modId = mod['id'] as int;
                        final atividades = _atividadesPorModulo[modId] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            initiallyExpanded: index == 0,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${mod['numero']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryOrange,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            title: Text(
                              mod['nome'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.darkText,
                              ),
                            ),
                            subtitle: Text(
                              mod['descricao'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            children: [
                              const Divider(height: 1),
                              ...atividades.map((atv) {
                                return ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AtividadeDetailScreen(atividadeId: atv['id']),
                                      ),
                                    );
                                  },
                                  leading: const Icon(Icons.extension_outlined, color: AppTheme.primaryOrange),
                                  title: Text(
                                    atv['titulo'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    atv['descricao'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
