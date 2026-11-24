import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/preferencias_service.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  // Aplica a última preferência conhecida já na abertura (mesmo sem rede)...
  await PreferenciasService.carregarCache();
  AppTheme.altoContraste = PreferenciasService.atual.value.altoContraste;
  runApp(const BraillepadApp());
  // ...e depois atualiza com o servidor.
  if (AuthService.isLoggedIn) PreferenciasService.carregar();
}

class BraillepadApp extends StatefulWidget {
  const BraillepadApp({super.key});

  @override
  State<BraillepadApp> createState() => _BraillepadAppState();
}

class _BraillepadAppState extends State<BraillepadApp> {
  @override
  void initState() {
    super.initState();
    PreferenciasService.atual.addListener(_aoMudarPreferencias);
  }

  @override
  void dispose() {
    PreferenciasService.atual.removeListener(_aoMudarPreferencias);
    super.dispose();
  }

  void _aoMudarPreferencias() {
    final alto = PreferenciasService.atual.value.altoContraste;
    final mudouContraste = alto != AppTheme.altoContraste;
    AppTheme.altoContraste = alto;
    setState(() {});
    if (mudouContraste) {
      // As telas usam as cores de AppTheme diretamente; reconstrói todas,
      // mantendo a navegação e o estado de cada uma.
      void reconstruir(Element e) {
        e.markNeedsBuild();
        e.visitChildren(reconstruir);
      }

      (context as Element).visitChildren(reconstruir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final escala = PreferenciasService.atual.value.escalaFonte;
    return MaterialApp(
      title: 'BraillePad MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      // Sem animação entre os temas: as telas já trocam de cor na hora (via
      // AppTheme), e interpolar o tema normal com o de alto contraste falha
      // nos estilos de texto dos botões ("Failed to interpolate TextStyles"),
      // erro que deixava a árvore quebrada e causava o "GlobalKey was used
      // multiple times".
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        // Tamanho da letra escolhido pelo professor, somado ao do sistema.
        final mq = MediaQuery.of(context);
        final sistema = mq.textScaler.scale(1.0);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear((sistema * escala).clamp(0.8, 2.4))),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthService.isLoggedIn ? const WelcomeScreen() : const LoginScreen(),
    );
  }
}
