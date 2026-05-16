// Smoke test pro CONTACT.
//
// Pumpuje AuthPage (nevyžaduje inicializovaný Supabase, protože síťové
// volání proběhne až po stisku tlačítka) a ověří, že se vykreslí.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:contact/features/auth/auth_page.dart';

void main() {
  testWidgets('AuthPage se vykreslí s názvem a přihlašovacím tlačítkem',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));

    expect(find.text('CONTACT'), findsOneWidget);
    expect(find.text('Přihlásit se'), findsOneWidget);
  });
}
