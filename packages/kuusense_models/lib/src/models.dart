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
      };
}
