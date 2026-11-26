# Kuusense — common commands. Run `make help`.

# firebase-tools needs Java 21+; prefer Homebrew's openjdk@21 if present.
JAVA21 := /opt/homebrew/opt/openjdk@21/bin
export PATH := $(if $(wildcard $(JAVA21)),$(JAVA21):,)$(PATH)

# LAN IP of this computer (used by physical phones to reach the emulators).
LAN_IP ?= $(shell ipconfig getifaddr en0 2>/dev/null)

.PHONY: help setup emulators simulator tokens emotibit scan monitor record web mobile mobile-device mobile-test web-test deploy-rules-test deploy-web-test staff tutor test test-protocol test-apps test-rules e2e analyze

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
	@echo "make mobile-test    Run the app against the real project kuusense-test"
	@echo "make web-test       Run the web platform against kuusense-test"
	@echo "make staff EMAIL=..  Give an account admin/researcher access (kuusense-test)"
	@echo "make deploy-web-test  Publish the web platform to kuusense-test (Hosting)"
	@echo "make tutor EMAIL=.. NAME=..  Enable an existing account as tutor in kuusense-test"
	@echo "make import-session DIR=.. CHILD=id  Upload a terminal recording to an existing NNA in kuusense-test"
	@echo "make deploy-rules-test  Publish security rules and indexes to kuusense-test"
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

# Real Firebase project kuusense-test (no emulators).
mobile-test:
	cd apps/mobile && flutter run --dart-define=USE_EMULATORS=false

web-test:
	cd apps/web && flutter run -d chrome --web-port 5050 --dart-define=USE_EMULATORS=false

# Grant web-platform access: make staff EMAIL=a@b.cl [ROLE=researcher] [PASSWORD=x]
staff:
	cd firebase && node admin/set-staff.mjs --project kuusense-test --email $(EMAIL) --role $(or $(ROLE),admin) $(if $(PASSWORD),--password $(PASSWORD),)

# Enable an EXISTING account as tutor (new tutors are created from the web):
#   make tutor EMAIL=a@b.cl NAME="Ana" [TYPE=family|teacher|therapist]
tutor:
	cd firebase && node admin/set-tutor.mjs --project kuusense-test --email $(EMAIL) $(if $(NAME),--name "$(NAME)",) --type $(or $(TYPE),family)

# Build the web platform against kuusense-test and publish it to Firebase Hosting.
deploy-web-test:
	cd apps/web && flutter build web --release --dart-define=USE_EMULATORS=false
	firebase deploy --project test --only hosting

# Upload a recording made with `make record` to kuusense-test, as the app would.
# The NNA must already exist (registered from the apps):
#   make import-session DIR=recordings/<fecha> CHILD=<childId>
import-session:
	$(EMOTIBIT) preview $(abspath $(DIR))
	cd firebase && node admin/import-session.mjs --project kuusense-test --dir $(abspath $(DIR)) --child $(CHILD)

# Publish Firestore/Storage rules and indexes to kuusense-test.
deploy-rules-test:
	firebase deploy --project test --only firestore:rules,firestore:indexes,storage

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
