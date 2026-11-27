import 'package:flutter/material.dart';
import 'generated/tokens.g.dart';

/// Predefined child avatars (no photos). Placeholder art built from icons and
/// brand colors until the client provides illustrations; the ids are what is
/// stored, so the artwork can change without migrating data.
class KuuAvatar {
  const KuuAvatar(this.id, this.icon, this.color);
  final String id;
  final IconData icon;
  final Color color;

  static const all = [
    KuuAvatar('pet', Icons.pets_rounded, KuuColor.brandSecondary),
    KuuAvatar('rabbit', Icons.cruelty_free_rounded, KuuColor.brandAccent),
    KuuAvatar('bird', Icons.flutter_dash_rounded, KuuColor.feedbackInfo),
    KuuAvatar('bee', Icons.emoji_nature_rounded, KuuColor.stateAlert),
    KuuAvatar('star', Icons.star_rounded, KuuColor.brandHighlight),
    KuuAvatar('rocket', Icons.rocket_launch_rounded, KuuColor.brandPrimary),
    KuuAvatar('sun', Icons.wb_sunny_rounded, KuuColor.stateAlert),
    KuuAvatar('music', Icons.music_note_rounded, KuuColor.stateStable),
  ];

  static KuuAvatar byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.avatarId, this.size = 48});
  final String avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = KuuAvatar.byId(avatarId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: a.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(a.icon, color: a.color, size: size * 0.55),
    );
  }
}

/// Symmetric grid (always [columns] per row) to choose an avatar.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });
  final String? selectedId;
  final ValueChanged<String> onChanged;

  /// 8 avatars → two even rows of four.
  static const columns = 4;

  @override
  Widget build(BuildContext context) {
    final all = KuuAvatar.all;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Each cell gets an equal share of the width; the avatar fits inside
        // it (selection ring included) without growing past 56 px.
        final cell = constraints.maxWidth / columns;
        final size = (cell - KuuSpacing.sm - 12).clamp(32.0, 56.0);
        return Column(
          children: [
            for (var start = 0; start < all.length; start += columns)
              Padding(
                padding: EdgeInsets.only(top: start == 0 ? 0 : KuuSpacing.sm),
                child: Row(
                  children: [
                    for (var i = start; i < start + columns; i++)
                      Expanded(
                        child: Center(
                          child: i < all.length
                              ? _option(context, all[i], size)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _option(BuildContext context, KuuAvatar a, double size) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: a.id == selectedId,
      label: 'Avatar ${a.id}',
      child: InkWell(
        key: ValueKey('avatar-${a.id}'),
        customBorder: const CircleBorder(),
        onTap: () => onChanged(a.id),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: 3,
              color: a.id == selectedId ? scheme.primary : Colors.transparent,
            ),
          ),
          child: ChildAvatar(avatarId: a.id, size: size),
        ),
      ),
    );
  }
}
