// End-to-end check of the tutor flow against the local Firebase emulators:
// two tutors (created by an admin) follow the same child.
//
// Run with the emulators up (`make emulators`) and a simulator booted:
//   make e2e
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_mobile/main.dart';

/// Pumps until [finder] matches (Firestore streams and spinners never
/// "settle", so pumpAndSettle cannot be used).
Future<void> waitFor(
  WidgetTester t,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out waiting for $finder');
    }
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await waitFor(t, finder);
  await t.ensureVisible(finder.first);
  await t.pump(const Duration(milliseconds: 200));
  await t.tap(finder.first);
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> type(WidgetTester t, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await waitFor(t, field);
  await t.ensureVisible(field);
  await t.enterText(field, text);
}

/// Tutors are created by an admin on the web platform; here the test plays
/// the admin: it creates the account and writes the tutor profile straight
/// to the Firestore emulator (the `owner` token bypasses the rules).
Future<void> seedTutor(String name, String email, String type) async {
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'clave1234',
  );
  final uid = cred.user!.uid;
  await FirebaseAuth.instance.signOut();
  // The profile and its public card, as the web platform writes them.
  await _writeDoc('tutors/$uid', {
    'displayName': {'stringValue': name},
    'type': {'stringValue': type},
    'email': {'stringValue': email},
    'active': {'booleanValue': true},
    'createdAtMs': {'integerValue': '${DateTime.now().millisecondsSinceEpoch}'},
  });
  await _writeDoc('tutors/$uid/public/card', {
    'displayName': {'stringValue': name},
    'type': {'stringValue': type},
    'photoPath': {'nullValue': null},
  });
}

Future<void> _writeDoc(String path, Map<String, Object?> fields) async {
  final host = KuusenseEnv.emulatorHost;
  final client = HttpClient();
  try {
    final req = await client.patchUrl(
      Uri.parse(
        'http://$host:8080/v1/projects/demo-kuusense/databases/(default)/documents/$path',
      ),
    );
    req.headers
      ..contentType = ContentType.json
      ..set('Authorization', 'Bearer owner');
    req.write(jsonEncode({'fields': fields}));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw TestFailure('seeding $path failed: ${res.statusCode}');
    }
  } finally {
    client.close();
  }
}

Future<void> signIn(WidgetTester t, String email) async {
  await type(t, 'Correo', email);
  await type(t, 'Contraseña', 'clave1234');
  await tap(t, find.widgetWithText(FilledButton, 'Ingresar'));
}

Future<void> signOutFromHome(WidgetTester t) async {
  await tap(t, find.byTooltip('Mi cuenta'));
  await tap(t, find.text('Cerrar sesión').last);
  await tap(t, find.widgetWithText(FilledButton, 'Cerrar sesión'));
  await waitFor(t, find.text('Te damos la bienvenida'));
}

Future<void> backToHome(WidgetTester t) async {
  while (find.text('Mis niños/as').evaluate().isEmpty) {
    await t.pageBack();
    await t.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two tutors with different accounts follow the same child', (
    t,
  ) async {
    await initKuusenseFirebase();
    final auth = FirebaseAuthService();
    await auth.signOut();
    final run = DateTime.now().millisecondsSinceEpoch;
    final ana = 'ana.$run@kuusense.test';
    final bruno = 'bruno.$run@kuusense.test';
    await seedTutor('Ana', ana, 'family');
    await seedTutor('Bruno', bruno, 'teacher');

    await t.pumpWidget(KuusenseApp(auth: auth));

    // --- Ana: signs in, registers a child and creates an invite.
    await waitFor(t, find.text('Te damos la bienvenida'));
    await signIn(t, ana);
    await tap(t, find.text('Registrar un niño/a'));
    await type(t, 'Apodo o nombre visible', 'Tomi');
    await tap(t, find.text('Día'));
    await tap(t, find.text('1').last);
    await tap(t, find.text('Mes'));
    await tap(t, find.text('enero').last);
    // The current year is the first option.
    await tap(t, find.text('Año'));
    await tap(t, find.text('${DateTime.now().year}').last);
    await tap(t, find.byKey(const ValueKey('avatar-rocket')));
    await tap(t, find.byType(Checkbox));
    await tap(t, find.widgetWithText(FilledButton, 'Registrar'));

    await waitFor(t, find.text('Solo tú lo acompañas'));
    await tap(t, find.text('Invitar'));
    await waitFor(t, find.byType(SelectableText));
    final code = t.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(code, hasLength(Invite.codeLength));
    await t.tapAt(const Offset(20, 60)); // close the sheet
    await t.pump(const Duration(seconds: 1));
    await backToHome(t);
    await waitFor(t, find.text('Tomi'));
    await signOutFromHome(t);

    // --- Bruno: signs in and joins with the code.
    await signIn(t, bruno);
    await waitFor(
      t,
      find.text(
        'Todavía no acompañas a ningún niño/a. Regístralo, o únete con el código '
        'que te compartió otro tutor.',
      ),
    );
    await tap(t, find.text('Tengo un código de invitación'));
    await t.enterText(find.byType(TextField), code.toLowerCase());
    await tap(t, find.widgetWithText(FilledButton, 'Unirme'));

    await waitFor(t, find.text('2 tutores'));
    expect(find.text('Tomi'), findsWidgets);
    await tap(t, find.byTooltip('Más opciones'));
    expect(find.text('Desvincularme'), findsOneWidget);
    await t.tapAt(const Offset(20, 300)); // close the menu
    await t.pump(const Duration(seconds: 1));

    // The code was single-use.
    await backToHome(t);
    await tap(t, find.text('Agregar'));
    await tap(t, find.text('Tengo un código de invitación'));
    await t.enterText(find.byType(TextField), code);
    await tap(t, find.widgetWithText(FilledButton, 'Unirme'));
    await waitFor(t, find.text('El código no existe o ya fue usado.'));
    await backToHome(t);
    await signOutFromHome(t);

    // --- Ana sees both tutors.
    await signIn(t, ana);
    await tap(t, find.text('Tomi'));
    await waitFor(t, find.text('2 tutores'));
    await tap(t, find.text('Tutores'));
    await waitFor(t, find.text('Bruno'));
    expect(find.text('Ana (tú)'), findsOneWidget);
    expect(find.text('Responsable'), findsOneWidget);
  });
}
