import 'dart:math';

/// Firestore layout (see firebase/firestore.rules for who can do what):
///
/// ```
/// tutors/{uid}                                 Tutor
/// staff/{uid}                                  StaffMember (written by admin tooling only)
/// children/{childId}                           Child          research-visible, pseudonymous
/// children/{childId}/private/profile           ChildProfile   tutors only
/// children/{childId}/sessions/{sessionId}      RecordingSession
/// invites/{code}                               Invite
/// ```
abstract final class Collections {
  static const tutors = 'tutors';
  static const staff = 'staff';
  static const children = 'children';
  static const childPrivate = 'private';
  static const childProfileDoc = 'profile';
  static const sessions = 'sessions';
  static const invites = 'invites';
}

abstract final class StoragePaths {
  static String sessionDir(String childId, String sessionId) =>
      'children/$childId/sessions/$sessionId';

  /// Per-second summary uploaded with each session (see [parseSignalsCsv]).
  static const signalsFile = 'signals.csv';
}

int _ms(Object? v) => (v as num?)?.toInt() ?? 0;

/// Unambiguous characters only (no 0/O, 1/I).
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _randomCode(int length, [Random? rng]) {
  final r = rng ?? Random.secure();
  return List.generate(length, (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)]).join();
}

// ------------------------------------------------------------------ tutors

enum TutorType {
  family,
  teacher,
  therapist;

  String get label => switch (this) {
        TutorType.family => 'Familiar',
        TutorType.teacher => 'Docente',
        TutorType.therapist => 'Terapeuta',
      };
}

/// A caregiver account (family member, teacher or therapist). Email and
/// password live only in Firebase Auth; they are not copied here.
class Tutor {
  Tutor({
    required this.uid,
    required this.displayName,
    required this.type,
    required this.createdAtMs,
  });

  final String uid;

  /// How the tutor wants to be called in the app.
  final String displayName;
  final TutorType type;
  final int createdAtMs;

  factory Tutor.fromMap(String uid, Map<String, dynamic> m) => Tutor(
        uid: uid,
        displayName: m['displayName'] as String? ?? '',
        type: TutorType.values.asNameMap()[m['type']] ?? TutorType.family,
        createdAtMs: _ms(m['createdAtMs']),
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'type': type.name,
        'createdAtMs': createdAtMs,
      };
}

// ------------------------------------------------------------------ staff

enum StaffRole {
  researcher,
  admin;

  String get label => switch (this) {
        StaffRole.researcher => 'Investigador/a',
        StaffRole.admin => 'Administrador/a',
      };
}

/// Research team / KúuSense admin. These docs are created with admin tooling,
/// never from the apps.
class StaffMember {
  StaffMember({required this.uid, required this.role});
  final String uid;
  final StaffRole role;

  factory StaffMember.fromMap(String uid, Map<String, dynamic> m) => StaffMember(
        uid: uid,
        role: StaffRole.values.asNameMap()[m['role']] ?? StaffRole.researcher,
      );

  Map<String, dynamic> toMap() => {'role': role.name};
}

// ------------------------------------------------------------------ children (NNA)

/// Sensory-processing quadrants of Dunn's model.
enum DunnQuadrant {
  seeking,
  avoiding,
  sensitivity,
  registration;

  String get label => switch (this) {
        DunnQuadrant.seeking => 'Búsqueda sensorial',
        DunnQuadrant.avoiding => 'Evitación sensorial',
        DunnQuadrant.sensitivity => 'Sensibilidad sensorial',
        DunnQuadrant.registration => 'Bajo registro',
      };
}

/// The research-visible, pseudonymous part of a child (NNA). It never holds
/// anything that identifies the child; see [ChildProfile] for that.
class Child {
  Child({
    required this.id,
    required this.code,
    required this.birthYear,
    required this.ownerUid,
    required this.tutorUids,
    required this.consentConfirmedAtMs,
    required this.createdAtMs,
    this.dunnQuadrant,
  });

  final String id;

  /// Ids of fictional demo children (firebase/admin/demo-data.mjs).
  static const demoIdPrefix = 'demo-';
  bool get isDemo => id.startsWith(demoIdPrefix);

  /// Pseudonymous code shown to researchers, e.g. `N-4F7Q`.
  final String code;
  final int birthYear;
  final DunnQuadrant? dunnQuadrant;

  /// Tutor who registered the child; the only one who can delete it or
  /// unlink other tutors.
  final String ownerUid;

  /// Every linked tutor, including [ownerUid].
  final List<String> tutorUids;

  /// When the registering tutor confirmed they have the caregiver's consent.
  final int consentConfirmedAtMs;
  final int createdAtMs;

  /// Age in whole years as of [now], from the birth year only (±1 year).
  int approximateAge([DateTime? now]) => (now ?? DateTime.now()).year - birthYear;

  factory Child.fromMap(String id, Map<String, dynamic> m) => Child(
        id: id,
        code: m['code'] as String? ?? '',
        birthYear: _ms(m['birthYear']),
        dunnQuadrant: DunnQuadrant.values.asNameMap()[m['dunnQuadrant']],
        ownerUid: m['ownerUid'] as String? ?? '',
        tutorUids: List<String>.from(m['tutorUids'] as List? ?? const []),
        consentConfirmedAtMs: _ms(m['consentConfirmedAtMs']),
        createdAtMs: _ms(m['createdAtMs']),
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'birthYear': birthYear,
        'dunnQuadrant': dunnQuadrant?.name,
        'ownerUid': ownerUid,
        'tutorUids': tutorUids,
        'consentConfirmedAtMs': consentConfirmedAtMs,
        'createdAtMs': createdAtMs,
      };

  static String generateCode([Random? rng]) => 'N-${_randomCode(4, rng)}';
}

/// The private part of a child, visible only to linked tutors.
class ChildProfile {
  ChildProfile({required this.displayName, required this.avatarId});

  /// Nickname or display name chosen by the tutor.
  final String displayName;

  /// One of the predefined avatars bundled with the app (no photos).
  final String avatarId;

  factory ChildProfile.fromMap(Map<String, dynamic> m) => ChildProfile(
        displayName: m['displayName'] as String? ?? '',
        avatarId: m['avatarId'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'displayName': displayName, 'avatarId': avatarId};
}

// ------------------------------------------------------------------ invites

/// Single-use code a linked tutor shares so another tutor can join a child.
class Invite {
  Invite({
    required this.code,
    required this.childId,
    required this.createdByUid,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  static const validFor = Duration(hours: 48);
  static const codeLength = 6;

  final String code;
  final String childId;
  final String createdByUid;
  final int createdAtMs;
  final int expiresAtMs;

  bool isExpired([DateTime? now]) =>
      (now ?? DateTime.now()).millisecondsSinceEpoch >= expiresAtMs;

  factory Invite.fromMap(String code, Map<String, dynamic> m) => Invite(
        code: code,
        childId: m['childId'] as String? ?? '',
        createdByUid: m['createdByUid'] as String? ?? '',
        createdAtMs: _ms(m['createdAtMs']),
        expiresAtMs: _ms(m['expiresAtMs']),
      );

  Map<String, dynamic> toMap() => {
        'childId': childId,
        'createdByUid': createdByUid,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
      };

  static String generateCode([Random? rng]) => _randomCode(codeLength, rng);

  /// Uppercases and strips anything outside the code alphabet.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp('[^$_codeAlphabet]'), '');
}

// ------------------------------------------------------------------ sessions

enum SessionStatus { recording, uploading, uploaded, failed }

/// Latest values pushed by the phone every few seconds while recording.
class LiveSnapshot {
  LiveSnapshot({
    required this.updatedAtMs,
    this.heartRate,
    this.eda,
    this.temperature,
    this.batteryPercent,
  });

  final int updatedAtMs;
  final double? heartRate;
  final double? eda;
  final double? temperature;
  final double? batteryPercent;

  factory LiveSnapshot.fromMap(Map<String, dynamic> m) => LiveSnapshot(
        updatedAtMs: _ms(m['updatedAtMs']),
        heartRate: (m['heartRate'] as num?)?.toDouble(),
        eda: (m['eda'] as num?)?.toDouble(),
        temperature: (m['temperature'] as num?)?.toDouble(),
        batteryPercent: (m['batteryPercent'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'updatedAtMs': updatedAtMs,
        'heartRate': heartRate,
        'eda': eda,
        'temperature': temperature,
        'batteryPercent': batteryPercent,
      };
}

/// Where a session took place.
enum SessionPlace {
  home,
  school,
  therapy,
  other;

  String get label => switch (this) {
        SessionPlace.home => 'Casa',
        SessionPlace.school => 'Colegio',
        SessionPlace.therapy => 'Terapia',
        SessionPlace.other => 'Otro',
      };
}

/// What the child was mainly doing during a session.
enum SessionActivity {
  freePlay,
  classwork,
  meal,
  transition,
  therapy,
  rest,
  other;

  String get label => switch (this) {
        SessionActivity.freePlay => 'Juego libre',
        SessionActivity.classwork => 'Clase o tarea',
        SessionActivity.meal => 'Comida',
        SessionActivity.transition => 'Transición',
        SessionActivity.therapy => 'Sesión de terapia',
        SessionActivity.rest => 'Descanso',
        SessionActivity.other => 'Otra',
      };
}

/// Context of a session, filled in by the tutor when recording starts. Every
/// field is optional so the tutor can skip it. No personal data: only kinds.
class SessionContext {
  const SessionContext({this.place, this.activity, this.present = const []});

  final SessionPlace? place;
  final SessionActivity? activity;

  /// Kinds of tutors present during the session.
  final List<TutorType> present;

  bool get isEmpty => place == null && activity == null && present.isEmpty;

  factory SessionContext.fromMap(Map<String, dynamic> m) => SessionContext(
        place: SessionPlace.values.asNameMap()[m['place']],
        activity: SessionActivity.values.asNameMap()[m['activity']],
        present: [
          for (final t in (m['present'] as List? ?? const []))
            if (TutorType.values.asNameMap()[t] case final type?) type,
        ],
      );

  Map<String, dynamic> toMap() => {
        'place': place?.name,
        'activity': activity?.name,
        'present': [for (final t in present) t.name],
      };
}

/// A behavior or event the tutor can mark with one tap while recording.
/// These are the labels the AI team trains on.
class BehaviorMarker {
  const BehaviorMarker(this.id, this.label);

  /// Stable identifier stored with the event; never rename an existing id.
  final String id;
  final String label;
}

/// Markers offered in the app.
///
/// PROVISIONAL list until the client's therapists define the official one
/// (open question in docs/REQUISITOS.md). Adding markers is safe; ids already
/// used in recorded sessions must keep their meaning.
abstract final class BehaviorCatalog {
  static const noteId = 'note';

  static const markers = [
    BehaviorMarker('restless', 'Inquietud'),
    BehaviorMarker('coversEars', 'Se tapa los oídos'),
    BehaviorMarker('repetitiveMovement', 'Movimientos repetitivos'),
    BehaviorMarker('crying', 'Llanto'),
    BehaviorMarker('crisisStart', 'Inicio de crisis'),
    BehaviorMarker('crisisEnd', 'Fin de crisis'),
    BehaviorMarker('strategyApplied', 'Se aplicó estrategia'),
    BehaviorMarker('calmed', 'Se calmó'),
  ];

  /// Display label for a stored event kind (unknown ids are shown as is).
  static String labelOf(String id) => id == noteId
      ? 'Nota'
      : markers.firstWhere((m) => m.id == id, orElse: () => BehaviorMarker(id, id)).label;
}

/// One marked event in a session. [atMs] is phone time; the same event is
/// also written to the session's `events.csv` with the device clock for
/// alignment with the signals.
class SessionEvent {
  const SessionEvent({required this.atMs, required this.kind, this.note});

  /// Upper bound kept by the security rules.
  static const maxPerSession = 1000;
  static const maxNoteLength = 280;

  final int atMs;

  /// A [BehaviorMarker.id] or [BehaviorCatalog.noteId].
  final String kind;

  /// Free text, only for notes.
  final String? note;

  String get label => kind == BehaviorCatalog.noteId ? (note ?? '') : BehaviorCatalog.labelOf(kind);

  factory SessionEvent.fromMap(Map<String, dynamic> m) => SessionEvent(
        atMs: _ms(m['atMs']),
        kind: m['kind'] as String? ?? '',
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'atMs': atMs,
        'kind': kind,
        if (note != null) 'note': note,
      };
}

/// One continuous EmotiBit recording of a child. Raw data lives in Cloud
/// Storage; this doc holds metadata only.
class RecordingSession {
  RecordingSession({
    required this.id,
    required this.childId,
    required this.deviceId,
    required this.createdByUid,
    required this.startedAtMs,
    required this.status,
    this.endedAtMs,
    this.packetCount = 0,
    this.streams = const [],
    this.files = const {},
    this.live,
    this.appVersion = '',
    this.context = const SessionContext(),
    this.events = const [],
    this.stats,
  });

  final String id;
  final String childId;
  final String deviceId;

  /// Tutor whose phone recorded the session; only that tutor uploads files.
  final String createdByUid;
  final int startedAtMs;
  final int? endedAtMs;
  final SessionStatus status;
  final int packetCount;

  /// Type tags observed during the session (e.g. EA, PG, HR).
  final List<String> streams;

  /// file name → Storage path.
  final Map<String, String> files;
  final LiveSnapshot? live;
  final String appVersion;
  final SessionContext context;

  /// Behaviors and notes marked during the session, in order.
  final List<SessionEvent> events;

  /// Whole-session figures, written with the files at upload time.
  final SessionStats? stats;

  /// Belongs to a fictional demo child.
  bool get isDemo => childId.startsWith(Child.demoIdPrefix);

  Duration get duration =>
      Duration(milliseconds: (endedAtMs ?? DateTime.now().millisecondsSinceEpoch) - startedAtMs);

  factory RecordingSession.fromMap(String id, Map<String, dynamic> m) => RecordingSession(
        id: id,
        childId: m['childId'] as String? ?? '',
        deviceId: m['deviceId'] as String? ?? '',
        createdByUid: m['createdByUid'] as String? ?? '',
        startedAtMs: _ms(m['startedAtMs']),
        endedAtMs: m['endedAtMs'] == null ? null : _ms(m['endedAtMs']),
        status: SessionStatus.values.asNameMap()[m['status']] ?? SessionStatus.failed,
        packetCount: _ms(m['packetCount']),
        streams: List<String>.from(m['streams'] as List? ?? const []),
        files: Map<String, String>.from(m['files'] as Map? ?? const {}),
        live: m['live'] == null
            ? null
            : LiveSnapshot.fromMap(Map<String, dynamic>.from(m['live'] as Map)),
        appVersion: m['appVersion'] as String? ?? '',
        context: m['context'] == null
            ? const SessionContext()
            : SessionContext.fromMap(Map<String, dynamic>.from(m['context'] as Map)),
        events: [
          for (final e in (m['events'] as List? ?? const []))
            SessionEvent.fromMap(Map<String, dynamic>.from(e as Map)),
        ],
        stats: m['stats'] == null
            ? null
            : SessionStats.fromMap(Map<String, dynamic>.from(m['stats'] as Map)),
      );

  Map<String, dynamic> toMap() => {
        'childId': childId,
        'deviceId': deviceId,
        'createdByUid': createdByUid,
        'startedAtMs': startedAtMs,
        'endedAtMs': endedAtMs,
        'status': status.name,
        'packetCount': packetCount,
        'streams': streams,
        'files': files,
        'live': live?.toMap(),
        'appVersion': appVersion,
        'context': context.toMap(),
        'events': [for (final e in events) e.toMap()],
        if (stats != null) 'stats': stats!.toMap(),
      };
}

/// Min, mean and max of one signal over a session.
class SignalRange {
  const SignalRange({required this.min, required this.mean, required this.max});
  final double min, mean, max;

  static SignalRange? fromMap(Object? m) {
    if (m is! Map) return null;
    double v(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return SignalRange(min: v('min'), mean: v('mean'), max: v('max'));
  }

  Map<String, double> toMap() => {'min': min, 'mean': mean, 'max': max};
}

/// Whole-session figures computed by the recorder (packages/emotibit
/// `SignalPreviewBuilder.statsJson`, same keys).
class SessionStats {
  const SessionStats({
    this.heartRate,
    this.eda,
    this.temperature,
    this.scrCount = 0,
    this.lossPercent = 0,
    this.batteryStart,
    this.batteryEnd,
  });

  final SignalRange? heartRate;
  final SignalRange? eda;
  final SignalRange? temperature;

  /// Skin-conductance responses detected by the device.
  final int scrCount;

  /// Packets numbered by the device that never arrived, in percent.
  final double lossPercent;
  final double? batteryStart;
  final double? batteryEnd;

  factory SessionStats.fromMap(Map<String, dynamic> m) => SessionStats(
        heartRate: SignalRange.fromMap(m['heartRate']),
        eda: SignalRange.fromMap(m['eda']),
        temperature: SignalRange.fromMap(m['temperature']),
        scrCount: _ms(m['scrCount']),
        lossPercent: (m['lossPercent'] as num?)?.toDouble() ?? 0,
        batteryStart: (m['batteryStart'] as num?)?.toDouble(),
        batteryEnd: (m['batteryEnd'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'heartRate': heartRate?.toMap(),
        'eda': eda?.toMap(),
        'temperature': temperature?.toMap(),
        'scrCount': scrCount,
        'lossPercent': lossPercent,
        'batteryStart': batteryStart,
        'batteryEnd': batteryEnd,
      };
}

/// One row of `signals.csv`, the per-second summary of a session.
class SignalPoint {
  const SignalPoint({
    required this.atMs,
    this.heartRate,
    this.eda,
    this.temperature,
    this.motion,
    this.battery,
  });

  final int atMs;
  final double? heartRate, eda, temperature, motion, battery;
}

/// Parses `signals.csv` (header
/// `host_epoch_ms,heart_rate,eda,temperature,motion,battery`, empty = no data).
List<SignalPoint> parseSignalsCsv(String csv) {
  final out = <SignalPoint>[];
  for (final line in csv.split('\n').skip(1)) {
    final p = line.trim().split(',');
    if (p.length < 6) continue;
    final at = int.tryParse(p[0]);
    if (at == null) continue;
    double? d(String s) => s.isEmpty ? null : double.tryParse(s);
    out.add(SignalPoint(
      atMs: at,
      heartRate: d(p[1]),
      eda: d(p[2]),
      temperature: d(p[3]),
      motion: d(p[4]),
      battery: d(p[5]),
    ));
  }
  return out;
}
