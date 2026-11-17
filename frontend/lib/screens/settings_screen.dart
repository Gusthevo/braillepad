import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/preferencias_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  bool _somAtivo = true;
  bool _vibracaoAtiva = true;
  bool _altoContraste = false;
  int _volumeSom = 80;
  String _modoExecucaoPadrao = 'MANUAL';

  @override
  void initState() {
    super.initState();
    _loadPreferencias();
  }

  Future<void> _loadPreferencias() async {
    setState(() => _isLoading = true);
    final prefs = await PreferenciasService.getPreferencias();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (prefs != null) {
          _somAtivo = prefs['som_ativo'] ?? true;
          _vibracaoAtiva = prefs['vibracao_ativa'] ?? true;
          _altoContraste = prefs['alto_contraste'] ?? false;
          _volumeSom = prefs['volume_som'] ?? 80;
          _modoExecucaoPadrao = prefs['modo_execucao_padrao'] ?? 'MANUAL';
        }
      });
    }
  }

  Future<void> _savePreferencia({
    bool? somAtivo,
    bool? vibracaoAtiva,
    bool? altoContraste,
    int? volumeSom,
    String? modoExecucaoPadrao,
  }) async {
    final ok = await PreferenciasService.updatePreferencias(
      somAtivo: somAtivo,
      vibracaoAtiva: vibracaoAtiva,
      altoContraste: altoContraste,
      volumeSom: volumeSom,
      modoExecucaoPadrao: modoExecucaoPadrao,
    );

    if (mounted && ok) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferências atualizadas no PostgreSQL!'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Configurações DTAE'),
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  // Acessibilidade e Tela
                  _buildSectionHeader('Acessibilidade & Interface'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            activeTrackColor: AppTheme.primaryOrange,
                            title: const Text('Modo de Alto Contraste'),
                            subtitle: const Text('Reforçar contraste visual para alunos com baixa visão (AEE)'),
                            value: _altoContraste,
                            onChanged: (val) {
                              setState(() => _altoContraste = val);
                              _savePreferencia(altoContraste: val);
                            },
                          ),
                          const Divider(),
                          DropdownButtonFormField<String>(
                            initialValue: _modoExecucaoPadrao,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Modo Padrão de Execução de Atendimento',
                              prefixIcon: const Icon(Icons.tune_rounded, color: AppTheme.primaryOrange),
                              filled: true,
                              fillColor: AppTheme.warmBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MANUAL', child: Text('Modo Manual (Toque em Tela)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'SIMULACAO', child: Text('Modo Simulação RFID (Hardware)', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _modoExecucaoPadrao = val);
                                _savePreferencia(modoExecucaoPadrao: val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tátil e Feedback Sonoro do BraillePad
                  _buildSectionHeader('Feedback Sonoro & Tátil do BraillePad'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            activeTrackColor: AppTheme.primaryOrange,
                            title: const Text('Sons do BraillePad'),
                            subtitle: const Text('Emitir feedback de áudio de acerto/erro ao aproximar fichas'),
                            value: _somAtivo,
                            onChanged: (val) {
                              setState(() => _somAtivo = val);
                              _savePreferencia(somAtivo: val);
                            },
                          ),
                          const Divider(),
                          SwitchListTile(
                            activeTrackColor: AppTheme.primaryOrange,
                            title: const Text('Vibração Háptica Tátil'),
                            subtitle: const Text('Vibrar o dispositivo para reforçar percepção tátil'),
                            value: _vibracaoAtiva,
                            onChanged: (val) {
                              setState(() => _vibracaoAtiva = val);
                              _savePreferencia(vibracaoAtiva: val);
                            },
                          ),
                          const Divider(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Volume dos Efeitos Sonoros',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$_volumeSom%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _volumeSom.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 10,
                                activeColor: AppTheme.primaryOrange,
                                onChanged: (val) {
                                  setState(() => _volumeSom = val.toInt());
                                },
                                onChangeEnd: (val) {
                                  _savePreferencia(volumeSom: val.toInt());
                                },
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
                          _somAtivo = true;
                          _vibracaoAtiva = true;
                          _altoContraste = false;
                          _volumeSom = 80;
                          _modoExecucaoPadrao = 'MANUAL';
                        });
                        _savePreferencia(
                          somAtivo: true,
                          vibracaoAtiva: true,
                          altoContraste: false,
                          volumeSom: 80,
                          modoExecucaoPadrao: 'MANUAL',
                        );
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restaurar Configurações Padrão'),
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
