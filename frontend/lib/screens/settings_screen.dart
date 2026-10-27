import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hapticFeedback = true;
  bool _gridSnap = true;
  bool _soundEffects = false;
  double _defaultBrushSize = 5.0;
  double _touchSensitivity = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Canvas Preferences
            _buildSectionHeader('Preferências da Tela'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeTrackColor: AppTheme.primaryOrange,
                      title: const Text('Ajuste à Grade'),
                      subtitle: const Text('Ajustar pontos de desenho às interseções da grade'),
                      value: _gridSnap,
                      onChanged: (val) => setState(() => _gridSnap = val),
                    ),
                    const Divider(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Espessura Padrão do Pincel',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${_defaultBrushSize.toInt()} px',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _defaultBrushSize,
                          min: 2,
                          max: 20,
                          activeColor: AppTheme.primaryOrange,
                          onChanged: (val) => setState(() => _defaultBrushSize = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tactile & Feedback Settings
            _buildSectionHeader('Tátil e Feedback'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeTrackColor: AppTheme.primaryOrange,
                      title: const Text('Vibração Háptica'),
                      subtitle: const Text('Vibrar o dispositivo ao tocar nos pontos ou desenhar'),
                      value: _hapticFeedback,
                      onChanged: (val) => setState(() => _hapticFeedback = val),
                    ),
                    const Divider(),
                    SwitchListTile(
                      activeTrackColor: AppTheme.primaryOrange,
                      title: const Text('Feedback Sonoro de Toque'),
                      subtitle: const Text('Tocar sons suaves durante as interações ao toque'),
                      value: _soundEffects,
                      onChanged: (val) => setState(() => _soundEffects = val),
                    ),
                    const Divider(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sensibilidade do Toque',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${(_touchSensitivity * 100).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _touchSensitivity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: AppTheme.primaryOrange,
                          onChanged: (val) => setState(() => _touchSensitivity = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Reset Button
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _hapticFeedback = true;
                    _gridSnap = true;
                    _soundEffects = false;
                    _defaultBrushSize = 5.0;
                    _touchSensitivity = 0.8;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configurações restauradas para o padrão')),
                  );
                },
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restaurar Padrões'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
