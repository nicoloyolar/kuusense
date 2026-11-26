import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_mobile/features/children/child_form_screen.dart';
import 'package:kuusense_mobile/features/children/join_with_code_screen.dart';
import 'package:kuusense_mobile/features/tutor/tutor_profile_screen.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Pushes [screen] over a blank home so the screen can pop with a result.
Future<List<Object?>> pumpPushed(WidgetTester tester, Widget screen) async {
  final results = <Object?>[];
  await tester.pumpWidget(MaterialApp(
    theme: KuuTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => results.add(
            await Navigator.of(context).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => screen)),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('register child', () {
    testWidgets('requires nickname, birth year, avatar and consent', (tester) async {
      ChildFormData? submitted;
      await pumpPushed(tester, ChildFormScreen(now: DateTime(2026), onSubmit: (d) async => submitted = d));

      await tapButton(tester, 'Registrar');
      expect(find.text('Completa el apodo'), findsOneWidget);
      expect(find.text('Elige el año de nacimiento'), findsOneWidget);
      expect(find.text('Elige un avatar'), findsNWidgets(2)); // title + error
      expect(find.text('Debes confirmarlo para continuar'), findsOneWidget);
      expect(submitted, isNull);
    });

    testWidgets('submits the form once everything is filled', (tester) async {
      ChildFormData? submitted;
      final results = await pumpPushed(
        tester,
        ChildFormScreen(now: DateTime(2026), onSubmit: (d) async => submitted = d),
      );

      await tester.enterText(find.byType(TextFormField).first, ' Tomi ');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2018  (8 años aprox.)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('avatar-rocket')));
      await tester.tap(find.byKey(const ValueKey('avatar-rocket')));
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tapButton(tester, 'Registrar');

      expect(submitted?.displayName, 'Tomi');
      expect(submitted?.birthYear, 2018);
      expect(submitted?.avatarId, 'rocket');
      expect(results, [true]);
    });

    testWidgets('editing does not ask for consent again', (tester) async {
      await pumpPushed(
        tester,
        ChildFormScreen(
          initial: const ChildFormData(displayName: 'Tomi', avatarId: 'sun', birthYear: 2018),
          onSubmit: (_) async {},
        ),
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
    });
  });

  group('join with code', () {
    testWidgets('rejects short codes without calling the server', (tester) async {
      var calls = 0;
      await pumpPushed(tester, JoinWithCodeScreen(onJoin: (_) async => calls++));
      await tester.enterText(find.byType(TextField), 'ab1');
      await tapButton(tester, 'Unirme');
      expect(find.text('El código tiene 6 caracteres.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('explains an expired code', (tester) async {
      await pumpPushed(
        tester,
        JoinWithCodeScreen(onJoin: (_) async => throw const InviteFailure(InviteFailureReason.expired)),
      );
      await tester.enterText(find.byType(TextField), 'k7m2pq');
      await tapButton(tester, 'Unirme');
      expect(find.text('El código venció. Pide uno nuevo.'), findsOneWidget);
    });

    testWidgets('closes after joining', (tester) async {
      String? used;
      final results = await pumpPushed(tester, JoinWithCodeScreen(onJoin: (c) async => used = c));
      await tester.enterText(find.byType(TextField), 'k7m2pq');
      await tapButton(tester, 'Unirme');
      expect(used, 'K7M2PQ');
      expect(results, [true]);
    });
  });

  group('tutor profile', () {
    testWidgets('requires a tutor type, then saves', (tester) async {
      (String, TutorType)? saved;
      final results = await pumpPushed(
        tester,
        TutorProfileScreen(
          initialName: 'Ana',
          onSave: (name, type) async => saved = (name, type),
        ),
      );
      await tapButton(tester, 'Guardar');
      expect(find.text('Elige una opción'), findsOneWidget);
      expect(saved, isNull);

      await tester.tap(find.text('Docente'));
      await tapButton(tester, 'Guardar');
      expect(saved, ('Ana', TutorType.teacher));
      expect(results, [null]);
    });
  });
}
