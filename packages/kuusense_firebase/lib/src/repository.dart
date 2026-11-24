import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kuusense_models/kuusense_models.dart';

/// Why an invite code could not be used.
enum InviteFailureReason { notFound, expired, alreadyLinked }

class InviteFailure implements Exception {
  const InviteFailure(this.reason);
  final InviteFailureReason reason;

  /// User-facing message in Spanish (Chile).
  String get message => switch (reason) {
        InviteFailureReason.notFound => 'El código no existe o ya fue usado.',
        InviteFailureReason.expired => 'El código venció. Pide uno nuevo.',
        InviteFailureReason.alreadyLinked => 'Ya estás vinculado/a a este niño/a.',
      };

  @override
  String toString() => 'InviteFailure($reason)';
}

/// All Firestore / Storage access goes through here, so security-rule
/// assumptions live in one place (see firebase/firestore.rules).
class KuusenseRepository {
  KuusenseRepository({FirebaseFirestore? db, FirebaseAuth? auth, FirebaseStorage? storage})
      : db = db ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final FirebaseStorage storage;

  String get uid => auth.currentUser!.uid;
  int get _now => DateTime.now().millisecondsSinceEpoch;

  CollectionReference<Map<String, dynamic>> get _tutors => db.collection(Collections.tutors);
  CollectionReference<Map<String, dynamic>> get _children => db.collection(Collections.children);
  CollectionReference<Map<String, dynamic>> get _invites => db.collection(Collections.invites);
  DocumentReference<Map<String, dynamic>> _profile(String childId) => _children
      .doc(childId)
      .collection(Collections.childPrivate)
      .doc(Collections.childProfileDoc);
  CollectionReference<Map<String, dynamic>> _sessions(String childId) =>
      _children.doc(childId).collection(Collections.sessions);

  // ------------------------------------------------------------ tutor

  /// The signed-in user's tutor profile, or null until they create it.
  Stream<Tutor?> watchMyTutorProfile() => _tutors
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Tutor.fromMap(d.id, d.data()!) : null);

  Future<void> saveMyTutorProfile({required String displayName, required TutorType type}) async {
    final ref = _tutors.doc(uid);
    final existing = await ref.get();
    final createdAtMs = existing.exists ? Tutor.fromMap(uid, existing.data()!).createdAtMs : _now;
    await ref.set(
      Tutor(uid: uid, displayName: displayName.trim(), type: type, createdAtMs: createdAtMs).toMap(),
    );
  }

  // ------------------------------------------------------------ children (tutor side)

  Stream<List<Child>> watchMyChildren() => _children
      .where('tutorUids', arrayContains: uid)
      .orderBy('createdAtMs', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Child.fromMap(d.id, d.data())).toList());

  Stream<Child?> watchChild(String childId) => _children
      .doc(childId)
      .snapshots()
      .map((d) => d.exists ? Child.fromMap(d.id, d.data()!) : null);

  /// Private profile (nickname, avatar). Only linked tutors can read it.
  Stream<ChildProfile?> watchChildProfile(String childId) => _profile(childId)
      .snapshots()
      .map((d) => d.exists ? ChildProfile.fromMap(d.data()!) : null);

  /// Registers a child with the signed-in tutor as owner. [consentConfirmed]
  /// must be true: the tutor confirms they have the caregiver's consent.
  Future<Child> registerChild({
    required String displayName,
    required String avatarId,
    required int birthYear,
    required bool consentConfirmed,
    DunnQuadrant? dunnQuadrant,
  }) async {
    if (!consentConfirmed) {
      throw ArgumentError.value(consentConfirmed, 'consentConfirmed', 'consent is required');
    }
    final ref = _children.doc();
    final now = _now;
    final child = Child(
      id: ref.id,
      code: Child.generateCode(),
      birthYear: birthYear,
      dunnQuadrant: dunnQuadrant,
      ownerUid: uid,
      tutorUids: [uid],
      consentConfirmedAtMs: now,
      createdAtMs: now,
    );
    final batch = db.batch()
      ..set(ref, child.toMap())
      ..set(_profile(ref.id),
          ChildProfile(displayName: displayName.trim(), avatarId: avatarId).toMap());
    await batch.commit();
    return child;
  }

  Future<void> updateChild(String childId, {required int birthYear, DunnQuadrant? dunnQuadrant}) =>
      _children.doc(childId).update({'birthYear': birthYear, 'dunnQuadrant': dunnQuadrant?.name});

  Future<void> updateChildProfile(String childId, ChildProfile profile) =>
      _profile(childId).set(profile.toMap());

  /// The signed-in tutor stops following a child (not allowed for the owner).
  Future<void> leaveChild(String childId) =>
      _children.doc(childId).update({'tutorUids': FieldValue.arrayRemove([uid])});

  /// Owner only: unlinks another tutor.
  Future<void> unlinkTutor(String childId, String tutorUid) =>
      _children.doc(childId).update({'tutorUids': FieldValue.arrayRemove([tutorUid])});

  /// Owner only. Sessions are research data and stay (pseudonymous) until
  /// the retention policy removes them with admin tooling.
  Future<void> deleteChild(String childId) async {
    final batch = db.batch()
      ..delete(_profile(childId))
      ..delete(_children.doc(childId));
    await batch.commit();
  }

  // ------------------------------------------------------------ invites

  /// Creates a single-use code another tutor can enter to join [childId].
  Future<Invite> createInvite(String childId) async {
    final now = _now;
    // A code collision is rejected by the rules (create never overwrites):
    // retry with a fresh code.
    for (var attempt = 0;; attempt++) {
      final invite = Invite(
        code: Invite.generateCode(),
        childId: childId,
        createdByUid: uid,
        createdAtMs: now,
        expiresAtMs: now + Invite.validFor.inMilliseconds,
      );
      try {
        await _invites.doc(invite.code).set(invite.toMap());
        return invite;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt >= 2) rethrow;
      }
    }
  }

  Future<void> cancelInvite(String code) => _invites.doc(code).delete();

  /// Links the signed-in tutor to the invite's child and consumes the code.
  /// Returns the child id. Throws [InviteFailure] for unknown, expired or
  /// redundant codes.
  Future<String> acceptInvite(String rawCode) async {
    final code = Invite.normalize(rawCode);
    if (code.length != Invite.codeLength) {
      throw const InviteFailure(InviteFailureReason.notFound);
    }
    final snap = await _invites.doc(code).get();
    if (!snap.exists) throw const InviteFailure(InviteFailureReason.notFound);
    final invite = Invite.fromMap(code, snap.data()!);
    if (invite.isExpired()) throw const InviteFailure(InviteFailureReason.expired);

    final batch = db.batch()
      ..update(_children.doc(invite.childId), {
        'tutorUids': FieldValue.arrayUnion([uid]),
        'lastInviteCode': code,
      })
      ..delete(_invites.doc(code));
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // The only legitimate denial left is a tutor who is already linked.
      if (e.code == 'permission-denied') {
        throw const InviteFailure(InviteFailureReason.alreadyLinked);
      }
      rethrow;
    }
    return invite.childId;
  }

  // ------------------------------------------------------------ staff (web)

  /// The signed-in user's staff membership, or null for tutors.
  Stream<StaffMember?> watchMyStaffMembership() => db
      .collection(Collections.staff)
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? StaffMember.fromMap(d.id, d.data()!) : null);

  /// Every child (pseudonymous part only). Staff only.
  Stream<List<Child>> watchAllChildren() => _children
      .orderBy('createdAtMs', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Child.fromMap(d.id, d.data())).toList());

  /// Sessions of every child, newest first. Staff only.
  Stream<List<RecordingSession>> watchAllSessions({int limit = 200}) => db
      .collectionGroup(Collections.sessions)
      .orderBy('startedAtMs', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => RecordingSession.fromMap(d.id, d.data())).toList());

  Future<String> downloadUrl(String storagePath) => storage.ref(storagePath).getDownloadURL();

  // ------------------------------------------------------------ sessions

  Stream<List<RecordingSession>> watchSessions(String childId) => _sessions(childId)
      .orderBy('startedAtMs', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => RecordingSession.fromMap(d.id, d.data())).toList());

  Future<RecordingSession> startSession({
    required String childId,
    required String deviceId,
    String appVersion = '',
  }) async {
    final ref = _sessions(childId).doc();
    final s = RecordingSession(
      id: ref.id,
      childId: childId,
      deviceId: deviceId,
      createdByUid: uid,
      startedAtMs: _now,
      status: SessionStatus.recording,
      appVersion: appVersion,
    );
    await ref.set(s.toMap());
    return s;
  }

  Future<void> pushLive(String childId, String sessionId, LiveSnapshot live) =>
      _sessions(childId).doc(sessionId).update({'live': live.toMap()});

  Future<void> updateSession(String childId, String sessionId, Map<String, Object?> fields) =>
      _sessions(childId).doc(sessionId).update(fields);

  Reference sessionFileRef(String childId, String sessionId, String fileName) =>
      storage.ref('${StoragePaths.sessionDir(childId, sessionId)}/$fileName');
}
