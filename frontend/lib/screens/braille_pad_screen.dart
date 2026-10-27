import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BraillePadScreen extends StatefulWidget {
  const BraillePadScreen({super.key});

  @override
  State<BraillePadScreen> createState() => _BraillePadScreenState();
}

class _BraillePadScreenState extends State<BraillePadScreen> {
  // 6 Braille dots state: index 0..5
  final List<bool> _dots = [false, false, false, false, false, false];
  String _constructedText = '';

  // Standard English Braille Map (Dot combinations -> Letter)
  static final Map<String, String> _brailleMap = {
    '100000': 'a',
    '110000': 'b',
    '100100': 'c',
    '100110': 'd',
    '100010': 'e',
    '110100': 'f',
    '110110': 'g',
    '110010': 'h',
    '010100': 'i',
    '010110': 'j',
    '101000': 'k',
    '111000': 'l',
    '101100': 'm',
    '101110': 'n',
    '101010': 'o',
    '111100': 'p',
    '111110': 'q',
    '111010': 'r',
    '011100': 's',
    '011110': 't',
    '101001': 'u',
    '111001': 'v',
    '010111': 'w',
    '101101': 'x',
    '101111': 'y',
    '101011': 'z',
  };

  String get _currentKey {
    return _dots.map((b) => b ? '1' : '0').join();
  }

  String get _translatedChar {
    return _brailleMap[_currentKey] ?? '?';
  }

  void _toggleDot(int index) {
    setState(() {
      _dots[index] = !_dots[index];
    });
  }

  void _addCurrentCharacter() {
    final char = _translatedChar;
    if (char != '?') {
      setState(() {
        _constructedText += char;
        _clearDots();
      });
    }
  }

  void _clearDots() {
    setState(() {
      for (int i = 0; i < _dots.length; i++) {
        _dots[i] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Braille Pad Studio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Constructed Text Display Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Constructed Text:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _constructedText.isEmpty ? 'Tap dots to form letters...' : _constructedText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _constructedText.isEmpty ? Colors.grey.shade400 : AppTheme.darkText,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Current Translated Letter Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Detected Character: ',
                    style: TextStyle(fontSize: 18, color: AppTheme.darkText),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(_translatedChar),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _translatedChar.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Interactive 6-Dot Braille Grid Matrix
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppTheme.primaryOrangeLight.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 40,
                      children: List.generate(6, (index) {
                        final isActive = _dots[index];
                        return GestureDetector(
                          onTap: () => _toggleDot(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? AppTheme.primaryOrange : Colors.grey.shade200,
                              boxShadow: [
                                if (isActive)
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),

              // Actions Toolbar (Add Letter, Space, Backspace, Clear)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _translatedChar != '?' ? _addCurrentCharacter : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Letter'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _constructedText += ' '),
                    icon: const Icon(Icons.space_bar_rounded),
                    label: const Text('Space'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (_constructedText.isNotEmpty) {
                        setState(() {
                          _constructedText =
                              _constructedText.substring(0, _constructedText.length - 1);
                        });
                      }
                    },
                    icon: const Icon(Icons.backspace_rounded),
                    label: const Text('Backspace'),
                  ),
                  IconButton(
                    onPressed: _clearDots,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset Dots',
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
