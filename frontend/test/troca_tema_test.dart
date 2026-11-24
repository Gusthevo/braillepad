import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:braillepad_frontend/main.dart';
import 'package:braillepad_frontend/screens/main_shell_screen.dart';
import 'package:braillepad_frontend/services/preferencias_service.dart';

void main() {
  testWidgets('trocar alto contraste e tamanho da letra não quebra as telas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BraillepadApp());
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const MainShellScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações').last);
    await tester.pumpAndSettle(const Duration(seconds: 6));
    final p = PreferenciasService.atual;
    p.value = p.value.copyWith(altoContraste: true);
    await tester.pumpAndSettle();
    p.value = p.value.copyWith(escalaFonte: 1.4);
    await tester.pumpAndSettle();
    p.value = p.value.copyWith(altoContraste: false);
    await tester.pumpAndSettle();
  });
}
