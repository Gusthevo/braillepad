import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/avatar_professor.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Conta?'),
        content: const Text('Você precisará informar seu e-mail e senha para acessar novamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AuthService.logout();
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerModal() {
    final temFoto = (AuthService.currentProfessor?['foto_url'] as String?)?.isNotEmpty ?? false;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Foto de perfil',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: AppTheme.primaryOrange),
                title: const Text('Tirar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _escolherFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: AppTheme.primaryOrange),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _escolherFoto(ImageSource.gallery);
                },
              ),
              if (temFoto)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  title: Text('Remover foto', style: TextStyle(color: Colors.red.shade700)),
                  onTap: () {
                    Navigator.pop(context);
                    _removerFoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Escolhe a foto, abre o recorte circular e envia. O app já reduz a imagem
  /// (até 1024 px, JPEG 85%), então o envio fica pequeno mesmo no 4G.
  Future<void> _escolherFoto(ImageSource origem) async {
    try {
      final escolhida = await ImagePicker().pickImage(
        source: origem,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (escolhida == null) return; // cancelou

      final recortada = await ImageCropper().cropImage(
        sourcePath: escolhida.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 1024,
        maxHeight: 1024,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar foto',
            toolbarColor: AppTheme.primaryOrange,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primaryOrange,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Ajustar foto',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
      if (recortada == null) return; // cancelou no recorte

      await _executar(() => AuthService.enviarFoto(recortada.path), 'Foto de perfil atualizada.');
    } catch (e) {
      debugPrint('Erro ao escolher foto: $e');
      _avisar('Não foi possível abrir a ${origem == ImageSource.camera ? 'câmera' : 'galeria'}.', erro: true);
    }
  }

  Future<void> _removerFoto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text('No lugar da foto aparecerão as suas iniciais.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmar == true) await _executar(AuthService.removerFoto, 'Foto removida.');
  }

  Future<void> _executar(Future<String?> Function() acao, String sucesso) async {
    setState(() => _isLoading = true);
    final erro = await acao();
    if (!mounted) return;
    setState(() => _isLoading = false);
    _avisar(erro ?? sucesso, erro: erro != null);
  }

  void _avisar(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? Colors.red.shade700 : Colors.green.shade700,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final prof = AuthService.currentProfessor ??
        {
          'nome': 'Professor(a)',
          'sobrenome': 'DTAE',
          'email': 'professor@escola.edu.br',
          'foto_url': null,
          'instituicao': 'Atendimento Educacional Especializado',
          'especialidade': 'Educação Especial e Braille',
        };

    final nomeCompleto = '${prof['nome'] ?? ''} ${prof['sobrenome'] ?? ''}'.trim();
    final String? fotoUrl = prof['foto_url'];

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Perfil do Professor'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _handleLogout,
            tooltip: 'Sair da Conta',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // User Avatar & Name Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Interactive Profile Avatar with Camera Icon Overlay
                    Semantics(
                      button: true,
                      label: 'Alterar foto de perfil',
                      child: GestureDetector(
                        onTap: _isLoading ? null : _showAvatarPickerModal,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryOrange, width: 3),
                              ),
                              child: AvatarProfessor(fotoUrl: fotoUrl, nome: nomeCompleto, tamanho: 100),
                            ),
                            if (_isLoading)
                              const Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.all(3),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      nomeCompleto.isEmpty ? 'Professor DTAE' : nomeCompleto,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      prof['email'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    if (prof['instituicao'] != null && prof['instituicao'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Chip(
                        avatar: Icon(Icons.school_rounded, size: 16, color: AppTheme.primaryOrange),
                        label: Text(prof['instituicao']),
                        backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Info Details
            _buildSectionHeader('Dados Cadastrais'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.badge_outlined, color: AppTheme.primaryOrange),
                    title: const Text('Especialidade'),
                    subtitle: Text(prof['especialidade'] ?? 'Não informada'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.security_outlined, color: AppTheme.primaryOrange),
                    title: const Text('Tipo de Conta'),
                    subtitle: const Text('Professor / Responsável AEE'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Option
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da Conta'),
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
