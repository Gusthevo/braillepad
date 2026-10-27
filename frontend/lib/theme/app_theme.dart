import 'package:flutter/material.dart';

class AppTheme {
  // Primary Orange Color Palette
  static const Color primaryOrange = Color(0xFFFF6D00); // Vibrant Orange
  static const Color primaryOrangeLight = Color(0xFFFF9E40);
  static const Color primaryOrangeDark = Color(0xFFC53D00);
  static const Color amberAccent = Color(0xFFFFAB00);
  static const Color warmBackground = Color(0xFFFFF8F2);
  static const Color cardBackground = Colors.white;
  static const Color darkText = Color(0xFF2C1D11);
  
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF8C00), // Dark Orange
      Color(0xFFFF5252), // Coral / Warm Red-Orange
      Color(0xFFFFAB00), // Amber
    ],
  );

  static const LinearGradient welcomeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFF7A00),
      Color(0xFFFF5500),
      Color(0xFFE63900),
    ],
  );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        secondary: amberAccent,
        surface: warmBackground,
        onPrimary: Colors.white,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: warmBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: primaryOrange.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        color: cardBackground,
      ),
      fontFamily: 'Roboto',
    );
  }
}
