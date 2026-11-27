import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

/// Who follows [child]: each tutor's photo (or initials), name and type, the
/// responsible one marked. The responsible tutor can unlink the others;
/// [onInvite] opens the invite flow.
Future<void> showTutorsSheet(
  BuildContext context, {
  required KuusenseRepository repo,
  required Child child,
  required String childName,
  required VoidCallback onInvite,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TutorsSheet(
    repo: repo,
    child: child,
    childName: childName,
    onInvite: onInvite,
  ),
);

class _TutorsSheet extends StatefulWidget {
  const _TutorsSheet({
    required this.repo,
    required this.child,
    required this.childName,
    required this.onInvite,
  });
  final KuusenseRepository repo;
  final Child child;
  final String childName;
  final VoidCallback onInvite;

  @override
  State<_TutorsSheet> createState() => _TutorsSheetState();
}

class _TutorsSheetState extends State<_TutorsSheet> {
  late List<String> _uids = [...widget.child.tutorUids];
  late Future<List<TutorCard>> _cards = widget.repo.tutorCards(_uids);
  final _photoUrls = <String, Future<String>>{};

  KuusenseRepository get repo => widget.repo;
  bool get _isOwner => widget.child.ownerUid == repo.uid;

  Future<String>? _photoUrl(String? path) => path == null
      ? null
      : _photoUrls.putIfAbsent(path, () => repo.downloadUrl(path));

  Future<void> _unlink(String uid, String name) async {
    final ok = await confirmDialog(
      context,
      title: 'Desvincular a $name',
      message:
          '$name dejará de ver a ${widget.childName} en su app. '
          'Podrás volver a invitarle cuando quieras.',
      confirmLabel: 'Desvincular',
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (!ok || !mounted) return;
    final done = await runWithFeedback(
      context,
      () => repo.unlinkTutor(widget.child.id, uid),
    );
    if (done && mounted) {
      setState(() {
        _uids = _uids.where((u) => u != uid).toList();
        _cards = repo.tutorCards(_uids);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KuuSpacing.lg,
          0,
          KuuSpacing.lg,
          KuuSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tutores', style: theme.textTheme.titleLarge),
            const SizedBox(height: KuuSpacing.xs),
            Text(
              'Quienes acompañan a ${widget.childName} y pueden ver sus sesiones.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: KuuSpacing.md),
            FutureBuilder<List<TutorCard>>(
              future: _cards,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    genericErrorMessage,
                    style: TextStyle(color: theme.colorScheme.error),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(KuuSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final byUid = {for (final c in snap.data!) c.uid: c};
                // Responsible first, then me, then the rest.
                final uids = [..._uids]
                  ..sort((a, b) {
                    int rank(String u) => u == widget.child.ownerUid
                        ? 0
                        : (u == repo.uid ? 1 : 2);
                    return rank(a).compareTo(rank(b));
                  });
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: uids.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: KuuSpacing.sm),
                    itemBuilder: (_, i) {
                      final uid = uids[i];
                      final card = byUid[uid];
                      final name = card?.displayName ?? 'Tutor';
                      final canUnlink =
                          _isOwner &&
                          uid != repo.uid &&
                          uid != widget.child.ownerUid;
                      return _TutorRow(
                        name: name,
                        type: card?.type,
                        photoUrl: _photoUrl(card?.photoPath),
                        isMe: uid == repo.uid,
                        isOwner: uid == widget.child.ownerUid,
                        onUnlink: canUnlink ? () => _unlink(uid, name) : null,
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: KuuSpacing.lg),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Invitar a otro tutor'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onInvite();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorRow extends StatelessWidget {
  const _TutorRow({
    required this.name,
    required this.type,
    required this.photoUrl,
    required this.isMe,
    required this.isOwner,
    required this.onUnlink,
  });
  final String name;
  final TutorType? type;
  final Future<String>? photoUrl;
  final bool isMe;
  final bool isOwner;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KuuSpacing.md - 4,
        vertical: KuuSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: isOwner ? scheme.primary.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(KuuRadius.md),
        border: Border.all(
          color: isOwner
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          KuuPersonAvatar(name: name, photoUrl: photoUrl, size: 44),
          const SizedBox(width: KuuSpacing.md - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (tú)' : name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (type != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _typeIcon(type!),
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type!.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isOwner)
            KuuPill(
              icon: Icons.star_rounded,
              text: 'Responsable',
              color: scheme.primary,
            )
          else if (onUnlink != null)
            IconButton(
              tooltip: 'Desvincular',
              icon: Icon(Icons.link_off_rounded, color: scheme.error),
              onPressed: onUnlink,
            ),
        ],
      ),
    );
  }
}

IconData _typeIcon(TutorType t) => switch (t) {
  TutorType.family => Icons.family_restroom_rounded,
  TutorType.teacher => Icons.school_rounded,
  TutorType.therapist => Icons.healing_rounded,
};
