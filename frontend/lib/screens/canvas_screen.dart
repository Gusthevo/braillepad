import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/drawing_point.dart';
import '../widgets/interactive_canvas.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  Stroke? _currentStroke;

  Color _selectedColor = AppTheme.primaryOrange;
  double _strokeWidth = 5.0;
  bool _isEraser = false;
  CanvasGridType _gridType = CanvasGridType.dots;

  final List<Color> _palette = const [
    AppTheme.primaryOrange,
    Color(0xFFE53935), // Red
    Color(0xFF00ACC1), // Cyan/Teal
    Color(0xFF1E88E5), // Blue
    Color(0xFF8E24AA), // Purple
    Color(0xFF43A047), // Green
    Color(0xFF212121), // Black
  ];

  void _onPanStart(DrawingPoint point) {
    setState(() {
      _currentStroke = Stroke(
        points: [point],
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        isEraser: _isEraser,
      );
    });
  }

  void _onPanUpdate(DrawingPoint point) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke!.points.add(point);
    });
  }

  void _onPanEnd() {
    if (_currentStroke != null) {
      setState(() {
        _strokes.add(_currentStroke!);
        _redoStack.clear();
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStack.add(_strokes.removeLast());
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _strokes.add(_redoStack.removeLast());
      });
    }
  }

  void _clearCanvas() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Tela?'),
        content: const Text('Tem certeza de que deseja apagar todo o desenho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              setState(() {
                _strokes.clear();
                _redoStack.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tela limpa'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );
  }

  void _saveCanvas() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Desenho salvo na Galeria!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Tela Interativa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Grid switch button
          PopupMenuButton<CanvasGridType>(
            icon: const Icon(Icons.grid_4x4_rounded),
            tooltip: 'Estilo da Grade',
            onSelected: (type) => setState(() => _gridType = type),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: CanvasGridType.dots,
                child: Row(
                  children: [
                    Icon(Icons.grain_rounded, color: AppTheme.primaryOrange),
                    SizedBox(width: 8),
                    Text('Grade de Pontos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: CanvasGridType.grid,
                child: Row(
                  children: [
                    Icon(Icons.grid_on_rounded, color: AppTheme.primaryOrange),
                    SizedBox(width: 8),
                    Text('Grade de Linhas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: CanvasGridType.blank,
                child: Row(
                  children: [
                    Icon(Icons.crop_square_rounded, color: AppTheme.primaryOrange),
                    SizedBox(width: 8),
                    Text('Tela em Branco'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            onPressed: _strokes.isNotEmpty ? _undo : null,
            tooltip: 'Desfazer',
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            onPressed: _redoStack.isNotEmpty ? _redo : null,
            tooltip: 'Refazer',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _strokes.isNotEmpty ? _clearCanvas : null,
            tooltip: 'Limpar',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: _strokes.isNotEmpty ? _saveCanvas : null,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: InteractiveCanvas(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    gridType: _gridType,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                  ),
                ),
              ),
            ),
          ),

          // Drawing Toolbar & Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stroke Width Slider & Tool Switcher
                Row(
                  children: [
                    // Tool toggle (Pen vs Eraser)
                    ChoiceChip(
                      label: const Icon(Icons.edit_rounded, size: 20),
                      selected: !_isEraser,
                      selectedColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _isEraser = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Icon(Icons.auto_fix_normal_rounded, size: 20),
                      selected: _isEraser,
                      selectedColor: Colors.grey.shade300,
                      onSelected: (selected) {
                        if (selected) setState(() => _isEraser = true);
                      },
                    ),
                    const SizedBox(width: 16),

                    // Live Brush size preview
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: Container(
                        width: _strokeWidth,
                        height: _strokeWidth,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isEraser ? Colors.grey : _selectedColor,
                        ),
                      ),
                    ),

                    // Slider
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.primaryOrange,
                          thumbColor: AppTheme.primaryOrange,
                        ),
                        child: Slider(
                          value: _strokeWidth,
                          min: 2.0,
                          max: 30.0,
                          onChanged: (val) => setState(() => _strokeWidth = val),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Color Palette Picker
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _palette.map((color) {
                      final isSelected = !_isEraser && _selectedColor == color;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                              _isEraser = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 42 : 34,
                            height: isSelected ? 42 : 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.orange.shade900 : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
