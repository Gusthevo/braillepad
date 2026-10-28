import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'health_pad_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  final List<_DashboardItem> _items = const [
    _DashboardItem(
      title: 'Métricas e Relatórios',
      subtitle: 'Indicadores de aprendizagem, gráficos e alertas pedagógicos',
      icon: Icons.analytics_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFFF6D00), Color(0xFFFF9E40)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: _PlaceholderScreen(title: 'Métricas e Relatórios'),
      heroTag: 'metricas_hero',
    ),
    _DashboardItem(
      title: 'Turmas',
      subtitle: 'Gerencie suas turmas, ano letivo e alunos vinculados',
      icon: Icons.groups_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: _PlaceholderScreen(title: 'Turmas'),
      heroTag: 'turmas_hero',
    ),
    _DashboardItem(
      title: 'Alunos',
      subtitle: 'Lista geral de alunos, transferências e histórico individual',
      icon: Icons.person_search_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFF57C00), Color(0xFFFFB300)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: _PlaceholderScreen(title: 'Alunos'),
      heroTag: 'alunos_hero',
    ),
    _DashboardItem(
      title: 'Atividades',
      subtitle: 'Catálogo de Módulos DTAE (Vogais, Sílabas e Palavras)',
      icon: Icons.extension_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFEF6C00), Color(0xFFFF8A65)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: _PlaceholderScreen(title: 'Atividades'),
      heroTag: 'atividades_hero',
    ),
    _DashboardItem(
      title: 'Health PAD',
      subtitle: 'Status de conexão com o dispositivo embarcado',
      icon: Icons.sensors_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFD84315), Color(0xFFFF7043)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: HealthPadScreen(),
      heroTag: 'health_pad_hero',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'BraillePad MVP',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryOrange,
                  size: 40,
                ),
                children: [
                  const Text('Plataforma DTAE para apoio à alfabetização em Braille.'),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header greeting
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.dashboard_rounded,
                      color: AppTheme.primaryOrange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navegue pelas opções',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                      ),
                      Text(
                        'Explore as funcionalidades do DTAE',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dashboard Options Grid
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _DashboardCard(item: _items[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Widget routeWidget;
  final String heroTag;

  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.routeWidget,
    required this.heroTag,
  });
}

class _DashboardCard extends StatefulWidget {
  final _DashboardItem item;

  const _DashboardCard({required this.item});

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isHovered = false;

  void _navigateToScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => widget.item.routeWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isHovered ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: _isHovered ? 2 : 5,
        child: InkWell(
          onTapDown: (_) => setState(() => _isHovered = true),
          onTapCancel: () => setState(() => _isHovered = false),
          onTap: () {
            setState(() => _isHovered = false);
            _navigateToScreen();
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.item.gradient,
            ),
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Hero(
                  tag: widget.item.heroTag,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      widget.item.icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded, size: 64, color: AppTheme.primaryOrange),
            const SizedBox(height: 16),
            Text(
              'Módulo: $title',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Próxima etapa do MVP DTAE',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
