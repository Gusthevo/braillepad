import 'package:flutter/material.dart';

/// Cores e tema do app.
///
/// As cores são getters porque mudam com o modo de alto contraste
/// ([altoContraste]), escolhido pelo professor nas Configurações. No alto
/// contraste o fundo fica branco, o texto preto e o laranja escurece para
/// #8F2B00 (contraste 8,4:1 sobre branco; o laranja normal tem 2,8:1).
class AppTheme {
  static bool altoContraste = false;

  // Paleta normal
  static const Color _laranja = Color(0xFFFF6D00);
  static const Color _laranjaClaro = Color(0xFFFF9E40);
  static const Color _laranjaEscuro = Color(0xFFC53D00);
  static const Color _ambar = Color(0xFFFFAB00);
  static const Color _fundoQuente = Color(0xFFFFF8F2);
  static const Color _textoEscuro = Color(0xFF2C1D11);

  // Paleta de alto contraste
  static const Color _hcPrimaria = Color(0xFF8F2B00);
  static const Color _hcDestaque = Color(0xFF6B4000);

  static Color get primaryOrange => altoContraste ? _hcPrimaria : _laranja;
  static Color get primaryOrangeLight => altoContraste ? _hcPrimaria : _laranjaClaro;
  static Color get primaryOrangeDark => altoContraste ? Colors.black : _laranjaEscuro;
  static Color get amberAccent => altoContraste ? _hcDestaque : _ambar;
  static Color get warmBackground => altoContraste ? Colors.white : _fundoQuente;
  static Color get cardBackground => Colors.white;
  static Color get darkText => altoContraste ? Colors.black : _textoEscuro;

  static LinearGradient get orangeGradient => altoContraste
      ? const LinearGradient(colors: [_hcPrimaria, _hcPrimaria])
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C00), Color(0xFFFF5252), Color(0xFFFFAB00)],
        );

  static LinearGradient get welcomeGradient => altoContraste
      ? const LinearGradient(colors: [_hcPrimaria, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter)
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF7A00), Color(0xFFFF5500), Color(0xFFE63900)],
        );

  static ThemeData get themeData => altoContraste ? _temaAltoContraste() : _temaNormal();

  static ThemeData _temaNormal() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _laranja,
        primary: _laranja,
        secondary: _ambar,
        surface: _fundoQuente,
        onPrimary: Colors.white,
        onSurface: _textoEscuro,
      ),
      scaffoldBackgroundColor: _fundoQuente,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _textoEscuro),
        titleTextStyle: TextStyle(
          color: _textoEscuro,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _laranja,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: _laranja.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
      ),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData _temaAltoContraste() {
    const borda = BorderSide(color: Colors.black, width: 2);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: _hcPrimaria,
        onPrimary: Colors.white,
        secondary: _hcDestaque,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black,
        outline: Colors.black,
        error: Color(0xFFB00020),
      ),
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: base.textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black),
      iconTheme: const IconThemeData(color: Colors.black),
      dividerTheme: const DividerThemeData(color: Colors.black, thickness: 1.5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        shape: Border(bottom: borda),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _hcPrimaria,
          foregroundColor: Colors.white,
          elevation: 0,
          side: borda,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: borda,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _hcPrimaria,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: borda),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        hintStyle: const TextStyle(color: Color(0xFF333333)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: borda),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _hcPrimaria, width: 3),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Colors.black),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _hcPrimaria : Colors.white),
        trackOutlineColor: WidgetStateProperty.all(Colors.black),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: _hcPrimaria,
        inactiveTrackColor: Colors.black26,
        thumbColor: _hcPrimaria,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.black,
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: _hcPrimaria,
        unselectedItemColor: Colors.black,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _hcPrimaria.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.black)),
      ),
    );
  }
}
