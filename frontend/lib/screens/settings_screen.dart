import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/preferencias_service.dart';
import '../services/tts_service.dart';
import '../services/feedback_service.dart';

/// Configurações do professor. Cada mudança vale na hora no app inteiro
/// (tema, tamanho da letra, voz, sons, vibração e modo da atividade) e é
/// gravada no servidor; se a gravação falhar, a opção volta ao valor anterior.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _carregando = true;
  String? _erroCarregar;

  // Valores dos sliders enquanto o dedo está arrastando (gravados ao soltar).
  double? _escalaArrastando;
  double? _volumeVozArrastando;
  double? _velocidadeArrastando;
  double? _volumeSomArrastando;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregar = null;
    });
    final r = await PreferenciasService.carregar();
    if (!mounted) return;
    setState(() {
      _carregando = false;
      _erroCarregar = r.ok ? null : r.erro;
    });
  }

  Future<void> _salvar(Preferencias nova, {String? confirmacao}) async {
    final r = await PreferenciasService.salvar(nova);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(r.ok ? (confirmacao ?? 'Preferência salva.') : 'Não foi salvo: ${r.erro}'),
        duration: Duration(milliseconds: r.ok ? 1200 : 4000),
        backgroundColor: r.ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _restaurarPadrao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar padrões?'),
        content: const Text(
          'Alto contraste, tamanho da letra, voz, sons, vibração e modo da atividade '
          'voltam aos valores iniciais.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmar == true) {
      await _salvar(Preferencias.padrao, confirmacao: 'Configurações padrão restauradas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Configurações'),
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Voltar',
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: _carregando
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : ValueListenableBuilder<Preferencias>(
                valueListenable: PreferenciasService.atual,
                builder: (context, p, _) => RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_erroCarregar != null) _avisoErro(),
                      ..._secaoAcessibilidade(p),
                      ..._secaoAtividade(p),
                      ..._secaoVoz(p),
                      ..._secaoEfeitos(p),
                      const SizedBox(height: 8),
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade700),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: _restaurarPadrao,
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Restaurar configurações padrão'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ───────────────────────── Seções ─────────────────────────

  List<Widget> _secaoAcessibilidade(Preferencias p) {
    final escala = (_escalaArrastando ?? p.escalaFonte).clamp(0.8, 1.6);
    return [
      _cabecalho('Acessibilidade da tela', Icons.visibility_rounded),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Alto contraste'),
                subtitle: const Text('Fundo branco, texto preto e cores mais escuras em todo o app (baixa visão).'),
                value: p.altoContraste,
                onChanged: (v) => _salvar(p.copyWith(altoContraste: v)),
              ),
              const Divider(),
              _rotuloSlider('Tamanho da letra', '${(escala * 100).round()}%'),
              Slider(
                value: escala,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                label: '${(escala * 100).round()}%',
                activeColor: AppTheme.primaryOrange,
                onChanged: (v) => setState(() => _escalaArrastando = v),
                onChangeEnd: (v) async {
                  await _salvar(p.copyWith(escalaFonte: double.parse(v.toStringAsFixed(2))));
                  if (mounted) setState(() => _escalaArrastando = null);
                },
              ),
              // Prévia: enquanto arrasta, mostra o tamanho sem reconstruir o app inteiro.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warmBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.textScalerOf(context).scale(1.0) / p.escalaFonte * escala,
                    ),
                  ),
                  child: Text(
                    'Exemplo: Maria concluiu a atividade de vogais.',
                    style: TextStyle(fontSize: 14, color: AppTheme.darkText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _secaoAtividade(Preferencias p) {
    Widget opcao(ModoExecucao modo, IconData icone, String titulo, String descricao) {
      final selecionado = p.modoExecucao == modo;
      return Semantics(
        selected: selecionado,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: selecionado ? null : () => _salvar(p.copyWith(modoExecucao: modo)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selecionado ? AppTheme.primaryOrange.withValues(alpha: 0.08) : null,
              border: Border.all(
                color: selecionado ? AppTheme.primaryOrange : Colors.grey.shade400,
                width: selecionado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icone, color: selecionado ? AppTheme.primaryOrange : Colors.grey.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(descricao, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
                Icon(
                  selecionado ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selecionado ? AppTheme.primaryOrange : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      _cabecalho('Como as respostas entram na atividade', Icons.tune_rounded),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              opcao(
                ModoExecucao.manual,
                Icons.touch_app_rounded,
                'Toque na tela',
                'Aparecem botões com as fichas (A, E, M, L...). Você toca a ficha que a criança apresentou. '
                    'O PAD, se conectado, também funciona.',
              ),
              const SizedBox(height: 10),
              opcao(
                ModoExecucao.pad,
                Icons.sensors_rounded,
                'Somente fichas no PAD',
                'Os botões somem: só contam as fichas lidas pelo BraillePad. '
                    'Se o PAD desconectar, dá para liberar o toque naquela sessão.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _secaoVoz(Preferencias p) {
    final volume = (_volumeVozArrastando ?? p.volumeVoz.toDouble()).clamp(20.0, 100.0);
    final velocidade = (_velocidadeArrastando ?? p.velocidadeFala).clamp(0.3, 0.7);
    final nomeVelocidade = velocidade < 0.42
        ? 'Lenta'
        : velocidade > 0.58
            ? 'Rápida'
            : 'Normal';

    return [
      _cabecalho('Voz que orienta a criança', Icons.record_voice_over_rounded),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A voz fala as instruções ("Apresente a letra A") e sempre fica ativa, '
                'mesmo com os sons desligados.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              _rotuloSlider('Volume da voz', '${volume.round()}%'),
              Slider(
                value: volume,
                min: 20,
                max: 100,
                divisions: 8,
                label: '${volume.round()}%',
                activeColor: AppTheme.primaryOrange,
                onChanged: (v) => setState(() => _volumeVozArrastando = v),
                onChangeEnd: (v) async {
                  await _salvar(p.copyWith(volumeVoz: v.round()));
                  if (mounted) setState(() => _volumeVozArrastando = null);
                },
              ),
              _rotuloSlider('Velocidade da fala', nomeVelocidade),
              Slider(
                value: velocidade,
                min: 0.3,
                max: 0.7,
                divisions: 8,
                label: nomeVelocidade,
                activeColor: AppTheme.primaryOrange,
                onChanged: (v) => setState(() => _velocidadeArrastando = v),
                onChangeEnd: (v) async {
                  await _salvar(p.copyWith(velocidadeFala: double.parse(v.toStringAsFixed(2))));
                  if (mounted) setState(() => _velocidadeArrastando = null);
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => TtsService.instance.falarExemplo(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Ouvir exemplo'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _secaoEfeitos(Preferencias p) {
    final volume = (_volumeSomArrastando ?? p.volumeSom.toDouble()).clamp(0.0, 100.0);
    return [
      _cabecalho('Sons e vibração de acerto e erro', Icons.celebration_rounded),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Sons de acerto e erro'),
                subtitle: const Text('"Plim" a cada letra, som de acerto, som suave no erro e fanfarra ao concluir a fase.'),
                value: p.somAtivo,
                onChanged: (v) => _salvar(p.copyWith(somAtivo: v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _rotuloSlider(
                  'Volume dos sons',
                  p.somAtivo ? '${volume.round()}%' : 'desligado',
                  apagado: !p.somAtivo,
                ),
              ),
              Slider(
                value: volume,
                min: 0,
                max: 100,
                divisions: 10,
                label: '${volume.round()}%',
                activeColor: AppTheme.primaryOrange,
                onChanged: p.somAtivo ? (v) => setState(() => _volumeSomArrastando = v) : null,
                onChangeEnd: (v) async {
                  await _salvar(p.copyWith(volumeSom: v.round()));
                  if (mounted) setState(() => _volumeSomArrastando = null);
                  FeedbackService.instance.testar();
                },
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Vibração'),
                subtitle: const Text('O aparelho vibra junto com os sons (pulsos diferentes para acerto, erro e conclusão).'),
                value: p.vibracaoAtiva,
                onChanged: (v) => _salvar(p.copyWith(vibracaoAtiva: v)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: (p.somAtivo || p.vibracaoAtiva) ? () => FeedbackService.instance.testar() : null,
                  icon: const Icon(Icons.vibration_rounded),
                  label: const Text('Testar som e vibração'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  // ───────────────────────── Auxiliares ─────────────────────────

  Widget _avisoErro() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.red.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Não foi possível buscar suas configurações no servidor.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_erroCarregar ?? ''} Abaixo estão as últimas salvas neste aparelho; '
            'mudanças só serão gravadas quando a conexão voltar.',
            style: TextStyle(fontSize: 13, color: Colors.red.shade900),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar de novo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rotuloSlider(String titulo, String valor, {bool apagado = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: apagado ? Colors.grey.shade600 : null,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: apagado ? Colors.grey.shade600 : AppTheme.primaryOrange,
          ),
        ),
      ],
    );
  }

  Widget _cabecalho(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Colors.grey.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
