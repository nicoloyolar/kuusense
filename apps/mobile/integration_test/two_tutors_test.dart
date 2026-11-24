// End-to-end check of the Fase 0 tutor flow against the local Firebase
// emulators: two tutors with different accounts follow the same child.
//
// Run with the emulators up (`make emulators`) and a simulator booted:
//   make e2e
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_mobile/main.dart';

/// Pumps until [finder] matches (Firestore streams and spinners never
/// "settle", so pumpAndSettle cannot be used).
Future<void> waitFor(WidgetTester t, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) throw TestFailure('Timed out waiting for $finder');
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

Future<void> createAccount(WidgetTester t, String name, String email) async {
  await tap(t, find.text('Crear una cuenta'));
  await type(t, 'Tu nombre', name);
  await type(t, 'Correo', email);
  await type(t, 'Contraseña', 'clave1234');
  await type(t, 'Repite la contraseña', 'clave1234');
  await tap(t, find.byType(Checkbox));
  await tap(t, find.widgetWithText(FilledButton, 'Crear cuenta'));
}

Future<void> signIn(WidgetTester t, String email) async {
  await type(t, 'Correo', email);
  await type(t, 'Contraseña', 'clave1234');
  await tap(t, find.widgetWithText(FilledButton, 'Ingresar'));
}

Future<void> completeProfile(WidgetTester t, String type) async {
  await waitFor(t, find.text('¡Hola! Cuéntanos un poco de ti'));
  await tap(t, find.text(type));
  await tap(t, find.widgetWithText(FilledButton, 'Continuar'));
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

  testWidgets('two tutors with different accounts follow the same child', (t) async {
    await initKuusenseFirebase();
    final auth = FirebaseAuthService();
    await auth.signOut();
    final run = DateTime.now().millisecondsSinceEpoch;
    final ana = 'ana.$run@kuusense.test';
    final bruno = 'bruno.$run@kuusense.test';
    final birthYear = DateTime.now().year - 8;

    await t.pumpWidget(KuusenseApp(auth: auth));

    // --- Ana: account, profile, registers a child and creates an invite.
    await waitFor(t, find.text('Te damos la bienvenida'));
    await createAccount(t, 'Ana', ana);
    await completeProfile(t, 'Familiar');
    await tap(t, find.text('Registrar un niño/a'));
    await type(t, 'Apodo o nombre visible', 'Tomi');
    await tap(t, find.byType(DropdownButtonFormField<int>));
    await tap(t, find.text('$birthYear  (8 años aprox.)').last);
    await tap(t, find.byKey(const ValueKey('avatar-rocket')));
    await tap(t, find.byType(Checkbox));
    await tap(t, find.widgetWithText(FilledButton, 'Registrar'));

    await waitFor(t, find.text('Solo tú lo acompañas'));
    expect(find.text('Eres el/la responsable de este perfil'), findsOneWidget);
    await tap(t, find.text('Invitar a otro tutor'));
    await waitFor(t, find.byType(SelectableText));
    final code = t.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(code, hasLength(Invite.codeLength));
    await t.tapAt(const Offset(20, 60)); // close the sheet
    await t.pump(const Duration(seconds: 1));
    await backToHome(t);
    await waitFor(t, find.text('Tomi'));
    await signOutFromHome(t);

    // --- Bruno: account, profile, joins with the code.
    await createAccount(t, 'Bruno', bruno);
    await completeProfile(t, 'Docente');
    await waitFor(t, find.text('Todavía no acompañas a ningún niño/a. Regístralo, o únete con el código '
        'que te compartió otro tutor.'));
    await tap(t, find.text('Tengo un código de invitación'));
    await t.enterText(find.byType(TextField), code.toLowerCase());
    await tap(t, find.widgetWithText(FilledButton, 'Unirme'));

    await waitFor(t, find.text('2 tutores lo acompañan'));
    expect(find.text('Tomi'), findsWidgets);
    expect(find.text('Te uniste con un código'), findsOneWidget);
    expect(find.text('Desvincularme'), findsOneWidget);

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
    await waitFor(t, find.text('2 tutores lo acompañan'));
    expect(find.text('Eliminar a Tomi'), findsOneWidget);
  });
}
