import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const BraillepadApp());
}

class BraillepadApp extends StatelessWidget {
  const BraillepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BraillePad MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: AuthService.isLoggedIn ? const WelcomeScreen() : const LoginScreen(),
    );
  }
}
