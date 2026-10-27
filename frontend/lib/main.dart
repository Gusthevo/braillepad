import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const BraillepadApp());
}

class BraillepadApp extends StatelessWidget {
  const BraillepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Braillepad Frontend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const WelcomeScreen(),
    );
  }
}
