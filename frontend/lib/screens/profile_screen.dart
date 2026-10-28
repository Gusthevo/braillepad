import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
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
    final urlController = TextEditingController();

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
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Alterar Foto de Perfil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Insira o link (URL) da sua imagem de perfil',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Custom URL Input
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL da Imagem de Perfil',
                  hintText: 'https://exemplo.com/sua_foto.jpg',
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor: AppTheme.warmBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final customUrl = urlController.text.trim();
                    if (customUrl.isNotEmpty) {
                      Navigator.pop(context);
                      _updatePhoto(customUrl);
                    }
                  },
                  child: const Text('Salvar Foto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updatePhoto(String photoUrl) async {
    setState(() => _isLoading = true);

    final success = await AuthService.updateProfile(fotoUrl: photoUrl);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada no banco de dados!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar foto no servidor.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prof = AuthService.currentProfessor ?? {
      'nome': 'Professor(a)',
      'sobrenome': 'DTAE',
      'email': 'professor@escola.edu.br',
      'foto_url': null,
      'instituicao': 'Atendimento Educacional Especializado',
      'especialidade': 'Educação Especial e Braille',
    };

    final nomeCompleto = '${prof['nome'] ?? ''} ${prof['sobrenome'] ?? ''}'.trim();
    String? fotoUrl = prof['foto_url'];

    // Resolve relative static URLs if returned from backend
    if (fotoUrl != null && fotoUrl.startsWith('/static/')) {
      fotoUrl = '${ApiService.baseUrl}$fotoUrl';
    }

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
                    GestureDetector(
                      onTap: _isLoading ? null : _showAvatarPickerModal,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppTheme.primaryOrange,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: fotoUrl != null && fotoUrl.isNotEmpty
                                  ? Image.network(
                                      fotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.person_rounded,
                                        size: 58,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 58,
                                      color: AppTheme.primaryOrange,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
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

                    const SizedBox(height: 16),

                    Text(
                      nomeCompleto.isEmpty ? 'Professor DTAE' : nomeCompleto,
                      style: const TextStyle(
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
                        avatar: const Icon(Icons.school_rounded, size: 16, color: AppTheme.primaryOrange),
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
                    leading: const Icon(Icons.badge_outlined, color: AppTheme.primaryOrange),
                    title: const Text('Especialidade'),
                    subtitle: Text(prof['especialidade'] ?? 'Não informada'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.security_outlined, color: AppTheme.primaryOrange),
                    title: Text('Tipo de Conta'),
                    subtitle: Text('Professor / Responsável AEE'),
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
