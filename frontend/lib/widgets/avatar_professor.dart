import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Avatar circular: a foto de perfil, ou as iniciais quando não há foto
/// (ou quando ela não carrega). A cor das iniciais vem do nome, então cada
/// pessoa mantém sempre a mesma cor.
class AvatarProfessor extends StatelessWidget {
  final String? fotoUrl;
  final String nome;
  final double tamanho;

  const AvatarProfessor({super.key, required this.fotoUrl, required this.nome, this.tamanho = 100});

  static const _cores = [
    Color(0xFFC2410C), // laranja escuro
    Color(0xFF0F766E), // verde-azulado
    Color(0xFF1D4ED8), // azul
    Color(0xFF7E22CE), // roxo
    Color(0xFFBE185D), // rosa
    Color(0xFF4D7C0F), // verde
  ];

  static String iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  /// URLs relativas do servidor (/static/...) viram absolutas.
  static String? resolverUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('/') ? '${ApiService.baseUrl}$url' : url;
  }

  Color get _cor {
    if (AppTheme.altoContraste) return Colors.black;
    final soma = nome.codeUnits.fold<int>(0, (s, c) => s + c);
    return _cores[soma % _cores.length];
  }

  Widget _iniciais() {
    return Container(
      color: _cor,
      alignment: Alignment.center,
      child: Text(
        iniciais(nome),
        style: TextStyle(
          color: Colors.white,
          fontSize: tamanho * 0.38,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = resolverUrl(fotoUrl);
    return Semantics(
      image: true,
      label: url != null ? 'Foto de perfil de $nome' : 'Iniciais de $nome',
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: ClipOval(
          child: url == null
              ? _iniciais()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // Decodifica no tamanho exibido, não nos 512 px originais.
                  cacheWidth: (tamanho * MediaQuery.devicePixelRatioOf(context)).round(),
                  loadingBuilder: (context, child, progresso) => progresso == null
                      ? child
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            _iniciais(),
                            const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                  errorBuilder: (context, erro, pilha) => _iniciais(),
                ),
        ),
      ),
    );
  }
}
