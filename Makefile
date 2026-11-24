# Kuusense — common commands. Run `make help`.

# firebase-tools needs Java 21+; prefer Homebrew's openjdk@21 if present.
JAVA21 := /opt/homebrew/opt/openjdk@21/bin
export PATH := $(if $(wildcard $(JAVA21)),$(JAVA21):,)$(PATH)

# LAN IP of this computer (used by physical phones to reach the emulators).
LAN_IP ?= $(shell ipconfig getifaddr en0 2>/dev/null)

.PHONY: help setup emulators simulator tokens emotibit scan monitor record web mobile mobile-device test test-protocol test-apps test-rules e2e analyze

help:
	@echo "make setup          Install all dependencies"
	@echo "make emulators      Start local Firebase (Auth, Firestore, Storage, UI on :4000)"
	@echo "make simulator      Start a fake EmotiBit on this computer"
	@echo "make scan           Find EmotiBits on the WiFi network      (IP=x.x.x.x optional)"
	@echo "make monitor        Live view of what the EmotiBit sends     (IP=, ARGS=-v for diagnostics)"
	@echo "make record         Monitor + save a session to recordings/"
	@echo "make emotibit ARGS='analyze recordings/<dir>/raw.csv'   Any emotibit CLI command"
	@echo "make tokens         Regenerate Dart/CSS from shared/design/tokens.json"
	@echo "make web            Run the researcher platform in Chrome"
	@echo "make mobile         Run the tutor app (simulator/emulator)"
	@echo "make mobile-device  Run the app on a physical phone (uses LAN_IP=$(LAN_IP))"
	@echo "make test           Run all automated tests"
	@echo "make e2e            End-to-end tutor flow on a simulator (needs make emulators)"
	@echo "make analyze        Static analysis of all Dart code"

setup:
	flutter pub get
	cd firebase && npm install

emulators:
	firebase emulators:start --project demo-kuusense --import=.emulator-data --export-on-exit=.emulator-data

tokens:
	dart run tools/design_tokens/bin/generate.dart

EMOTIBIT := dart run tools/emotibit_cli/bin/emotibit.dart
IP_ARG := $(if $(IP),--ip $(IP),)

simulator:
	$(EMOTIBIT) simulate

emotibit:
	$(EMOTIBIT) $(ARGS)

scan:
	$(EMOTIBIT) scan $(IP_ARG) $(ARGS)

monitor:
	$(EMOTIBIT) monitor $(IP_ARG) $(ARGS)

record:
	$(EMOTIBIT) record $(IP_ARG) $(ARGS)

web:
	cd apps/web && flutter run -d chrome --web-port 5050

mobile:
	cd apps/mobile && flutter run

mobile-device:
	cd apps/mobile && flutter run --dart-define=EMULATOR_HOST=$(LAN_IP)

test: test-protocol test-apps test-rules

test-protocol:
	cd packages/kuusense_models && dart test
	cd packages/emotibit && dart test

test-apps:
	cd packages/kuusense_firebase && flutter test
	cd apps/mobile && flutter test

# End-to-end tutor flow on a simulator, against running emulators (make emulators).
e2e:
	cd apps/mobile && flutter test integration_test

test-rules:
	cd firebase && npm test

analyze:
	cd packages/emotibit && dart analyze
	cd tools/emotibit_cli && dart analyze
	cd packages/kuusense_models && dart analyze
	cd packages/kuusense_firebase && flutter analyze
	cd shared/kuusense_ui && flutter analyze
	cd tools/design_tokens && dart analyze
	cd apps/mobile && flutter analyze lib
	cd apps/web && flutter analyze lib
