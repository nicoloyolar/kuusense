# KúuSense

App and platform that anticipate emotional-dysregulation episodes in children with autism (NNA con TEA) using EmotiBit physiological data, and support their tutors (family, teachers, therapists) with alerts and sensory strategies. Flutter mobile app (tutor mode + child mode), Flutter web platform (researchers/admin), Firebase backend.

Read before structural work: `docs/REQUISITOS.md` (requirements, decisions, open questions), `docs/PLAN.md` (phases; only work inside the approved phase), `docs/ARCHITECTURE.md`.

## Working with the owner
- The owner directs the work and does not read code. **Present a plan and get approval before any sizeable change.** Report what changed and how it was verified, in Spanish, briefly.
- UI text is in Spanish (Chile). Code, identifiers and code comments are in English.
- Ask before: adding a Firebase product or paid service, changing the data model or security-rule semantics, or touching a real (non-demo) Firebase project.
- Client documents are confidential (industrial secret). Never send them, or derived details, to external services. `docs/cliente/` is git-ignored.

## Layout and dependency rules
- `packages/emotibit`: pure Dart EmotiBit protocol, recorder, stats and simulator. **No Flutter or Firebase imports.**
- `packages/kuusense_models`: pure Dart data model (epoch-ms times, no Firebase types).
- `packages/kuusense_firebase`: Firebase bootstrap, the `AuthService` interface and `KuusenseRepository`. Apps never call Firestore, Storage or Firebase Auth directly.
- `shared/design/tokens.json`: single source of truth for brand identity (colors, fonts, radii, spacing). Run `make tokens` after changing it. Never hardcode colors or sizes in the apps; use the theme or `Kuu*` tokens.
- `shared/kuusense_ui`: Flutter theme, logo, brand assets and form validators shared by both apps.
- App code is organized by feature: `apps/*/lib/features/<feature>/`.
- `apps/mobile`: depends on `emotibit` + `kuusense_firebase` + `kuusense_ui`. State in controllers; screens stay thin.
- `apps/web`: depends on `kuusense_firebase` + `kuusense_ui` (never on `emotibit`).
- `tools/emotibit_cli`: terminal tool (`scan`, `monitor`, `record`, `analyze`, `simulate`) that depends on `emotibit` only.
- Dart pub workspace: run `flutter pub get` at the repo root.

## Commands (see `make help`)
- `make test` (protocol tests + security-rule tests on emulators) and `make analyze` must pass before declaring work done.
- `make scan` / `make monitor` / `make record` work against a real EmotiBit or `make simulator`.
- `make emulators` / `make web` / `make mobile` give the local dev loop with no real hardware or Firebase project.
- firebase-tools requires Java 21+ (Homebrew `openjdk@21`, wired in the Makefile).

## Rules
- Any change to `firebase/*.rules` needs matching tests in `firebase/test/rules.test.mjs`.
- Any protocol change needs a test in `packages/emotibit/test`, and the simulator must stay consistent with it.
- `raw.csv` must stay byte-compatible with the EmotiBit SD-card format (unmodified packet lines).
- Never store high-frequency samples in Firestore. Raw data goes to Storage.
- Children's data is sensitive health data of minors: minimize and pseudonymize, and never add personal fields without explicit approval.
- Never commit `recordings/` (physiological data).
- Protocol facts marked "no verificado" in `docs/ARCHITECTURE.md` must be confirmed with real hardware before relying on them.
