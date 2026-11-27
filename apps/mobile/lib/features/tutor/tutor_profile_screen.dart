import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

/// The tutor edits their own name, type and photo. The account and email
/// are managed by an admin on the web platform, so they are read-only here.
class TutorProfileScreen extends StatefulWidget {
  const TutorProfileScreen({
    super.key,
    required this.onSave,
    this.initialName,
    this.initialType,
    this.email,
    this.tutor,
    this.photoUrl,
    this.onSetPhoto,
    this.onRemovePhoto,
  });

  final Future<void> Function(String name, TutorType type) onSave;
  final String? initialName;
  final TutorType? initialType;
  final String? email;

  /// Live profile, to show the current photo (null hides photo editing).
  final Stream<Tutor?>? tutor;
  final Future<String> Function(String path)? photoUrl;
  final Future<void> Function(Uint8List bytes, String? previousPath)?
  onSetPhoto;
  final Future<void> Function(String path)? onRemovePhoto;

  @override
  State<TutorProfileScreen> createState() => _TutorProfileScreenState();
}

class _TutorProfileScreenState extends State<TutorProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late TutorType? _type = widget.initialType;
  bool _showTypeError = false;
  bool _busy = false;
  bool _photoBusy = false;

  /// Download URL per photo path, so rebuilds do not fetch it again.
  final _urls = <String, Future<String>>{};
  Future<String>? _urlFor(String? path) =>
      path == null || widget.photoUrl == null
      ? null
      : _urls.putIfAbsent(path, () => widget.photoUrl!(path));

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {})); // live preview in the header
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showTypeError = _type == null);
    if (!valid || _type == null) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => widget.onSave(_name.text.trim(), _type!),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _photoMenu(String? currentPath) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KuuSpacing.lg,
              0,
              KuuSpacing.lg,
              KuuSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Foto de perfil',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: KuuSpacing.xs),
                Text(
                  'Solo la ven tú y el equipo de KúuSense.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: KuuSpacing.md),
                _SheetOption(
                  icon: Icons.photo_camera_outlined,
                  label: 'Tomar una foto',
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                _SheetOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Elegir de la galería',
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
                if (currentPath != null)
                  _SheetOption(
                    icon: Icons.delete_outline_rounded,
                    label: 'Quitar foto',
                    danger: true,
                    onTap: () => Navigator.pop(ctx, 'remove'),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;

    if (action == 'remove') {
      setState(() => _photoBusy = true);
      await runWithFeedback(context, () => widget.onRemovePhoto!(currentPath!));
      if (mounted) setState(() => _photoBusy = false);
      return;
    }

    final camera = action == 'camera';
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('pickImage failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              camera
                  ? 'No se pudo abrir la cámara. Revisa el permiso en Ajustes.'
                  : 'No se pudo abrir la galería. Revisa el permiso en Ajustes.',
            ),
          ),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _photoBusy = true);
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    await runWithFeedback(
      context,
      () => widget.onSetPhoto!(bytes, currentPath),
    );
    if (mounted) setState(() => _photoBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _name.text.trim();
    final photoEditable = widget.tutor != null && widget.onSetPhoto != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  KuuSpacing.lg,
                  KuuSpacing.sm,
                  KuuSpacing.lg,
                  KuuSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -------------------------------------------- header
                    Center(
                      child: StreamBuilder<Tutor?>(
                        stream: widget.tutor,
                        builder: (context, snap) {
                          final path = snap.data?.photoPath;
                          return _PhotoAvatar(
                            name: name,
                            photoUrl: _urlFor(path),
                            busy: _photoBusy,
                            onTap: photoEditable && !_photoBusy
                                ? () => _photoMenu(path)
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: KuuSpacing.md),
                    Text(
                      name.isEmpty ? 'Tu nombre' : name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_type != null) ...[
                      const SizedBox(height: KuuSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tutorTypeIcon(_type!),
                            size: 18,
                            color: KuuColor.brandSecondary,
                          ),
                          const SizedBox(width: KuuSpacing.xs),
                          Text(
                            _type!.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: KuuSpacing.lg),

                    // -------------------------------------------- account (read-only)
                    if (widget.email != null && widget.email!.isNotEmpty) ...[
                      _Section(
                        title: 'Cuenta',
                        child: Row(
                          children: [
                            const KuuIconTile(
                              icon: Icons.mail_outline_rounded,
                              color: KuuColor.brandHighlight,
                              size: 40,
                            ),
                            const SizedBox(width: KuuSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.email!,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    'Lo administra el equipo de KúuSense',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KuuSpacing.md),
                    ],

                    // -------------------------------------------- name
                    _Section(
                      title: '¿Cómo quieres que te llamen?',
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          hintText: 'Tu nombre',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          counterText: '',
                        ),
                        validator: (v) =>
                            KuuValidators.required(v, 'tu nombre'),
                      ),
                    ),
                    const SizedBox(height: KuuSpacing.md),

                    // -------------------------------------------- type
                    _Section(
                      title: 'Soy…',
                      subtitle: 'Los demás tutores lo ven junto a tu nombre.',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final (i, t)
                                  in TutorType.values.indexed) ...[
                                if (i > 0) const SizedBox(width: KuuSpacing.sm),
                                Expanded(
                                  child: _TypeTile(
                                    type: t,
                                    selected: _type == t,
                                    onTap: () => setState(() {
                                      _type = t;
                                      _showTypeError = false;
                                    }),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_showTypeError)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: KuuSpacing.sm,
                              ),
                              child: Text(
                                'Elige una opción',
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KuuSpacing.lg),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big round avatar (photo or initials) with a camera badge to change it.
class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({
    required this.name,
    required this.photoUrl,
    required this.busy,
    required this.onTap,
  });
  final String name;
  final Future<String>? photoUrl;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: 'Cambiar foto de perfil',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            children: [
              KuuPersonAvatar(
                name: name,
                photoUrl: photoUrl,
                size: 112,
                shadow: true,
              ),
              if (busy)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KuuColor.lightOnSurface.withValues(alpha: 0.35),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: KuuColor.lightSurface,
                    ),
                  ),
                ),
              if (onTap != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 3),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 18,
                      color: KuuColor.lightSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One option of the photo bottom sheet.
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? KuuColor.feedbackError : KuuColor.brandPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: KuuSpacing.sm),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(KuuRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KuuRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KuuSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: KuuSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: danger ? color : null,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White card with a small title, grouping one part of the profile.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(KuuSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(KuuRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: KuuSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// One selectable tutor type: icon in a tinted circle and its label.
class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final TutorType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.07)
            : scheme.surface,
        borderRadius: BorderRadius.circular(KuuRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KuuRadius.md),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              vertical: KuuSpacing.md,
              horizontal: KuuSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KuuRadius.md),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    KuuIconTile(
                      icon: tutorTypeIcon(type),
                      color: selected
                          ? KuuColor.brandPrimary
                          : KuuColor.brandHighlight,
                      size: 48,
                      round: true,
                    ),
                    if (selected)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: KuuSpacing.sm),
                Text(
                  type.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData tutorTypeIcon(TutorType t) => switch (t) {
  TutorType.family => Icons.family_restroom_rounded,
  TutorType.teacher => Icons.school_rounded,
  TutorType.therapist => Icons.psychology_rounded,
};
