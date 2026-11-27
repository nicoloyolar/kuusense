import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

/// Round avatar for a person (tutor): their photo when there is one, else
/// their initials on the brand gradient. [photoUrl] resolves the photo's
/// download URL (null = no photo).
class KuuPersonAvatar extends StatelessWidget {
  const KuuPersonAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
    this.shadow = false,
  });
  final String name;
  final Future<String>? photoUrl;
  final double size;
  final bool shadow;

  static String initialsOf(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    final fallback = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KuuColor.brandHighlight, KuuColor.brandPrimary],
        ),
      ),
      child: initials.isEmpty
          ? Icon(
              Icons.person_rounded,
              color: KuuColor.lightSurface,
              size: size * 0.48,
            )
          : Text(
              initials,
              style: TextStyle(
                color: KuuColor.lightSurface,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
                letterSpacing: 0.5,
              ),
            ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: KuuColor.brandPrimary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: photoUrl == null
            ? fallback
            : FutureBuilder<String>(
                future: photoUrl,
                builder: (context, snap) {
                  if (!snap.hasData) return fallback;
                  return Image.network(
                    snap.data!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, _, _) => fallback,
                    frameBuilder: (_, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 250),
                            child: frame == null ? fallback : child,
                          ),
                  );
                },
              ),
      ),
    );
  }
}
