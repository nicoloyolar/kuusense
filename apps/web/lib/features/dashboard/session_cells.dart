import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/panel.dart';

/// Cells and labels shared by every session table, so they read the same
/// on Inicio, Sesiones and NNA.

/// Recording state as one word: grabando, subiendo, fallida, incompleta o completa.
(String, Color) sessionState(RecordingSession s) => switch (s.status) {
  SessionStatus.recording => ('Grabando', KuuColor.statePreCrisis),
  SessionStatus.uploading => ('Subiendo', KuuColor.feedbackInfo),
  SessionStatus.failed => ('Fallida', KuuColor.feedbackError),
  SessionStatus.uploaded =>
    s.isIncomplete
        ? ('Incompleta', KuuColor.stateAlert)
        : ('Completa', KuuColor.stateStable),
};

class SessionStateBadge extends StatelessWidget {
  const SessionStateBadge(this.session, {super.key});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final (text, color) = sessionState(session);
    return KuuStatusBadge(text, color: color);
  }
}

class SessionOutcomeBadge extends StatelessWidget {
  const SessionOutcomeBadge(this.session, {super.key});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final o = SessionOutcome.of(session);
    return KuuStatusBadge(o.label, color: o.color(context));
  }
}

/// Date on top, time range below.
class SessionWhenCell extends StatelessWidget {
  const SessionWhenCell(this.session, {super.key});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatDate(s.startedAtMs),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${formatTime(s.startedAtMs)}${s.endedAtMs == null ? '' : ' – ${formatTime(s.endedAtMs!)}'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// NNA nickname in bold with its code below (admins); researchers, who
/// never see nicknames, get the code alone.
class ChildCell extends StatelessWidget {
  const ChildCell({super.key, required this.code, this.profile});
  final String code;
  final ChildProfile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (profile != null) ...[
          ChildAvatar(avatarId: profile!.avatarId, size: 32),
          const SizedBox(width: KuuSpacing.sm),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile?.displayName ?? code,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (profile != null)
                Text(
                  code,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Muted text for empty or secondary values.
class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}
