import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'canvas_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<Map<String, dynamic>> _savedArtworks = [
    {
      'title': 'Braille Dot Matrix Alpha',
      'date': 'Oct 24, 2024',
      'icon': Icons.grain_rounded,
      'color': const Color(0xFFFF6D00),
      'isFavorite': true,
    },
    {
      'title': 'Orange Geometric Pattern',
      'date': 'Oct 22, 2024',
      'icon': Icons.architecture_rounded,
      'color': const Color(0xFFFF9E40),
      'isFavorite': false,
    },
    {
      'title': 'Tactile Symbol Practice',
      'date': 'Oct 18, 2024',
      'icon': Icons.touch_app_rounded,
      'color': const Color(0xFFE65100),
      'isFavorite': true,
    },
    {
      'title': 'Freehand Sunset Canvas',
      'date': 'Oct 15, 2024',
      'icon': Icons.palette_rounded,
      'color': const Color(0xFFFFAB00),
      'isFavorite': false,
    },
  ];

  void _showArtworkDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item['icon'] as IconData,
                size: 60,
                color: item['color'] as Color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item['title'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created on ${item['date']}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CanvasScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Canvas'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      item['isFavorite'] = !(item['isFavorite'] as bool);
                    });
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    item['isFavorite'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: Colors.red,
                  ),
                  label: Text(item['isFavorite'] ? 'Unfavorite' : 'Favorite'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Saved Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryOrange,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CanvasScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Canvas', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _savedArtworks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.collections_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No saved artworks yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _savedArtworks.length,
                  itemBuilder: (context, index) {
                    final item = _savedArtworks[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showArtworkDetail(item),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (item['color'] as Color).withValues(alpha: 0.12),
                                Colors.white,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: Icon(
                                  item['isFavorite'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 48,
                                    color: item['color'] as Color,
                                  ),
                                ),
                              ),
                              Text(
                                item['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                item['date'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
