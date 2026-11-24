/// Firestore data model for Kuusense. Plain Dart (no Firebase dependency):
/// times are stored as epoch milliseconds.
///
/// Collections:
///   studies/{studyId}                         Study
///   studies/{studyId}/participants/{code}     Participant (doc id = code)
///   studies/{studyId}/sessions/{sessionId}    RecordingSession
///   studyCodes/{joinCode}                     StudyCode  (join-code lookup)
///
/// Storage:
///   studies/{studyId}/sessions/{sessionId}/{raw,sync,events}.csv
library;

export 'src/models.dart';
