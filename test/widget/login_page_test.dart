import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/login_page.dart';

void main() {
  testWidgets('LoginPage exibe campos de autenticação', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
