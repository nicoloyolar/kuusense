/// Date, duration and label formatting shared by the apps (Spanish, Chile).
library;

import 'package:kuusense_models/kuusense_models.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// `25-11-2026 14:05` (Chilean order), local time.
String formatDateTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.day)}-${_two(d.month)}-${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

/// `25-11-2026`.
String formatDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.day)}-${_two(d.month)}-${d.year}';
}

/// `1 h 05 min`, `12 min 30 s`, `45 s`.
String formatDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours} h ${_two(d.inMinutes % 60)} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min ${_two(d.inSeconds % 60)} s';
  return '${d.inSeconds} s';
}

/// Offset from the session start, `mm:ss` (or `h:mm:ss`).
String formatOffset(Duration d) {
  final base = '${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';
  return d.inHours > 0 ? '${d.inHours}:$base' : base;
}

String sessionStatusLabel(SessionStatus s) => switch (s) {
  SessionStatus.recording => 'Grabando',
  SessionStatus.uploading => 'Subiendo',
  SessionStatus.uploaded => 'Completa',
  SessionStatus.failed => 'Con error',
};

String sessionEndReasonLabel(SessionEndReason? r) => switch (r) {
  null => 'Sin información de cierre',
  SessionEndReason.stopped => 'Detenida por el tutor',
  SessionEndReason.deviceLost => 'Se cerró sola: el EmotiBit no volvió a conectarse',
  SessionEndReason.appClosed => 'Se cerró sola: la app se cerró durante la grabación',
};

/// Total time without data, e.g. `2 cortes · 1:35 sin datos`.
String sessionGapsSummary(List<SessionGap> gaps) {
  final total = gaps.fold(Duration.zero, (a, g) => a + g.duration);
  final n = gaps.length == 1 ? '1 corte' : '${gaps.length} cortes';
  return '$n · ${formatOffset(total)} sin datos';
}

/// `Colegio · Clase o tarea`, or `Sin contexto`.
String contextSummary(SessionContext c) {
  final parts = [?c.place?.label, ?c.activity?.label];
  return parts.isEmpty ? 'Sin contexto' : parts.join(' · ');
}

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// `Hoy`, `Ayer` or `lunes 23 de noviembre`.
String formatDayHeading(DateTime day, [DateTime? now]) {
  final today = DateTime(
    (now ?? DateTime.now()).year,
    (now ?? DateTime.now()).month,
    (now ?? DateTime.now()).day,
  );
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';
}

/// `14:05`.
String formatTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.hour)}:${_two(d.minute)}';
}
