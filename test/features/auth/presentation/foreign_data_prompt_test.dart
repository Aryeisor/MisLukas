import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/auth/domain/entities/auth_user.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/auth/presentation/widgets/foreign_data_prompt.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

/// Dueño anterior de los datos del celular.
const AuthUser previousOwner = AuthUser(
  id: '00000000-0000-4000-8000-000000000002',
  email: 'andres@ejemplo.com',
);

void main() {
  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  testWidgetsWithDatabase(
    'al iniciar sesión con otra cuenta avisa y, al continuar, borra y entra',
    (tester, db) async {
      final session = TestSession(initialOwner: previousOwner.id);
      await pumpApp(tester, database: db, session: session);

      await loginAsDemoUser(tester);

      // No entra a Inicio hasta confirmar.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text(ForeignDataPrompt.title), findsOneWidget);
      expect(find.text(ForeignDataPrompt.message), findsOneWidget);

      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();

      expect(session.wiper.wipes, 1);
      expect(session.store.owner, testUser.id);
      expect(find.byType(HomeScreen), findsOneWidget);
      // Los datos del otro usuario ya no están.
      expect(find.text('Aún no tienes movimientos este mes'), findsOneWidget);
    },
  );

  testWidgetsWithDatabase(
    'al cancelar, cierra la sesión y conserva los datos del otro usuario',
    (tester, db) async {
      final session = TestSession(initialOwner: previousOwner.id);
      final auth = FakeAuthRepository();
      await pumpApp(tester, database: db, auth: auth, session: session);

      await loginAsDemoUser(tester);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(session.wiper.wipes, 0);
      expect(session.store.owner, previousOwner.id);
    },
  );

  testWidgetsWithDatabase(
    'si la app abre con la sesión de otra cuenta, avisa en el login',
    (tester, db) async {
      final session = TestSession(initialOwner: previousOwner.id);
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
        session: session,
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(ForeignDataPrompt.title), findsOneWidget);
    },
  );

  testWidgetsWithDatabase('el mismo usuario entra sin aviso', (
    tester,
    db,
  ) async {
    final session = TestSession(initialOwner: testUser.id);
    await pumpApp(tester, database: db, session: session);

    await loginAsDemoUser(tester);

    expect(find.text(ForeignDataPrompt.title), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(session.wiper.wipes, 0);
  });
}
