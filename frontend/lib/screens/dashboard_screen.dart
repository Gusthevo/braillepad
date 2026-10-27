import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'canvas_screen.dart';
import 'braille_pad_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  final List<_DashboardItem> _items = const [
    _DashboardItem(
      title: 'Interactive Canvas',
      subtitle: 'Freehand drawing, brush tools & interactive touch',
      icon: Icons.draw_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFFF6D00), Color(0xFFFF9E40)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: CanvasScreen(),
      heroTag: 'canvas_hero',
    ),
    _DashboardItem(
      title: 'Braille Pad Studio',
      subtitle: '6/8 Dot Braille cell touch matrix & translation',
      icon: Icons.grid_on_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: BraillePadScreen(),
      heroTag: 'braille_hero',
    ),
    _DashboardItem(
      title: 'Saved Gallery',
      subtitle: 'View, edit and export your created canvases',
      icon: Icons.collections_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFF57C00), Color(0xFFFFB300)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: GalleryScreen(),
      heroTag: 'gallery_hero',
    ),
    _DashboardItem(
      title: 'Settings',
      subtitle: 'Brush sensitivity, grid options & preferences',
      icon: Icons.tune_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFEF6C00), Color(0xFFFF8A65)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      routeWidget: SettingsScreen(),
      heroTag: 'settings_hero',
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
                applicationName: 'Braillepad Frontend',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.gesture_rounded,
                  color: AppTheme.primaryOrange,
                  size: 40,
                ),
                children: [
                  const Text('An interactive Flutter canvas and braille pad studio.'),
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
                        'Select Functionality',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                      ),
                      Text(
                        'Explore interactive features below',
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

              // 4 Dashboard Options Grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 2 : 1,
                        childAspectRatio: isWide ? 1.8 : 2.1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return _DashboardCard(item: _items[index]);
                      },
                    );
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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.item.routeWidget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0.1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isHovered ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: _isHovered ? 2 : 6,
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
                // Icon with Hero tag
                Hero(
                  tag: widget.item.heroTag,
                  child: Container(
                    width: 64,
                    height: 64,
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
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.item.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
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
