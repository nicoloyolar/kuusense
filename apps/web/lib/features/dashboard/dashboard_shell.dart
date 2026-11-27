import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../admin/children_admin_page.dart';
import '../admin/researchers_page.dart';
import '../admin/tutors_page.dart';
import '../common/page_title.dart';
import 'home_page.dart';
import 'session_detail_page.dart';
import 'sessions_page.dart';

/// Sections of the platform. The admin group is visible to admins only.
enum _Section {
  home('Inicio', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  sessions(
    'Sesiones',
    Icons.monitor_heart_outlined,
    Icons.monitor_heart_rounded,
  ),
  tutors('Tutores', Icons.group_outlined, Icons.group_rounded),
  children('NNA', Icons.child_care_outlined, Icons.child_care_rounded),
  researchers('Investigadores', Icons.science_outlined, Icons.science_rounded);

  const _Section(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  bool get adminOnly =>
      this == tutors || this == children || this == researchers;
}

/// Signed-in staff layout: a fixed navy sidebar (a drawer on narrow
/// screens) and the current section at full width. Holds the live data
/// streams so every section shares them.
class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.auth,
    required this.repo,
    required this.staff,
  });
  final AuthService auth;
  final KuusenseRepository repo;
  final StaffMember staff;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  late final Stream<List<Child>> _children = widget.repo.watchAllChildren();
  late final Stream<List<RecordingSession>> _sessions = widget.repo
      .watchAllSessions();
  // Names and tutors: admins only (the rules deny them to researchers).
  late final Stream<List<Tutor>> _tutors = _isAdmin
      ? widget.repo.watchAllTutors()
      : Stream.value(const <Tutor>[]);
  late final Stream<Map<String, ChildProfile>> _profiles = _isAdmin
      ? widget.repo.watchAllChildProfiles()
      : Stream.value(const <String, ChildProfile>{});

  bool get _isAdmin => widget.staff.isAdmin;

  _Section _section = _Section.home;

  /// NNA the sessions section is filtered to (null = all).
  String? _childFilter;

  /// Session open in the detail view (null = the section itself).
  RecordingSession? _openSession;

  void _go(_Section s) => setState(() {
    _section = s;
    _openSession = null;
  });

  void _openChildSessions(String childId) => setState(() {
    _childFilter = childId;
    _section = _Section.sessions;
    _openSession = null;
  });

  void _open(RecordingSession s) => setState(() {
    _section = _Section.sessions;
    _openSession = s;
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Child>>(
      stream: _children,
      builder: (context, childSnap) => StreamBuilder<List<RecordingSession>>(
        stream: _sessions,
        builder: (context, sessionSnap) => StreamBuilder<List<Tutor>>(
          stream: _tutors,
          builder: (context, tutorSnap) =>
              StreamBuilder<Map<String, ChildProfile>>(
                stream: _profiles,
                builder: (context, profileSnap) {
                  final error =
                      childSnap.error ??
                      sessionSnap.error ??
                      tutorSnap.error ??
                      profileSnap.error;
                  final loading =
                      !childSnap.hasData ||
                      !sessionSnap.hasData ||
                      !tutorSnap.hasData ||
                      !profileSnap.hasData;
                  final children = childSnap.data ?? const <Child>[];
                  final sessions =
                      sessionSnap.data ?? const <RecordingSession>[];
                  final tutors = tutorSnap.data ?? const <Tutor>[];
                  final profiles =
                      profileSnap.data ?? const <String, ChildProfile>{};
                  final codes = {for (final c in children) c.id: c.code};

                  final Widget body;
                  if (error != null) {
                    body = _Message(
                      icon: Icons.error_outline_rounded,
                      text: 'No se pudieron cargar los datos.\n$error',
                    );
                  } else if (loading) {
                    body = const Center(child: CircularProgressIndicator());
                  } else if (_openSession != null) {
                    final s = _openSession!;
                    body = SessionDetailView(
                      key: ValueKey('${s.childId}/${s.id}'),
                      repo: widget.repo,
                      childId: s.childId,
                      sessionId: s.id,
                      childCode: codes[s.childId] ?? '—',
                      onBack: () => setState(() => _openSession = null),
                    );
                  } else {
                    body = switch (_section) {
                      _Section.home => HomePage(
                        children: children,
                        sessions: sessions,
                        profiles: profiles,
                        onOpenSession: _open,
                        onOpenChild: _openChildSessions,
                        onAllSessions: () => _go(_Section.sessions),
                      ),
                      _Section.sessions => SessionsPage(
                        children: children,
                        sessions: sessions,
                        profiles: profiles,
                        childFilter: _childFilter,
                        onFilter: (id) => setState(() => _childFilter = id),
                        onOpenSession: _open,
                      ),
                      _Section.tutors => TutorsPage(
                        repo: widget.repo,
                        tutors: tutors,
                        children: children,
                      ),
                      _Section.children => ChildrenAdminPage(
                        repo: widget.repo,
                        children: children,
                        profiles: profiles,
                        tutors: tutors,
                        sessions: sessions,
                      ),
                      _Section.researchers => ResearchersPage(
                        repo: widget.repo,
                      ),
                    };
                  }
                  return PageTitle(
                    _openSession != null ? 'Sesión' : _section.label,
                    child: _Frame(
                      staff: widget.staff,
                      email: widget.auth.currentEmail,
                      isAdmin: _isAdmin,
                      section: _section,
                      onSection: _go,
                      onSignOut: widget.auth.signOut,
                      child: body,
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ frame

class _Frame extends StatelessWidget {
  const _Frame({
    required this.staff,
    required this.email,
    required this.isAdmin,
    required this.section,
    required this.onSection,
    required this.onSignOut,
    required this.child,
  });

  final StaffMember staff;
  final String? email;
  final bool isAdmin;
  final _Section section;
  final ValueChanged<_Section> onSection;
  final VoidCallback onSignOut;
  final Widget child;

  static const sidebarWidth = 248.0;
  static const _navy = KuuColor.lightOnSurface;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final theme = Theme.of(context);
    Widget sidebar({VoidCallback? afterTap}) => _Sidebar(
      staff: staff,
      email: email,
      isAdmin: isAdmin,
      section: section,
      onSection: (s) {
        afterTap?.call();
        onSection(s);
      },
      onSignOut: onSignOut,
    );

    if (wide) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: sidebarWidth, child: sidebar()),
            Expanded(
              child: Align(alignment: Alignment.topCenter, child: child),
            ),
          ],
        ),
      );
    }
    return Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: KuuColor.lightSurface,
          title: const KuusenseLogoOnBrand(height: 28, horizontal: true),
          centerTitle: false,
        ),
        drawer: Drawer(
          width: sidebarWidth,
          backgroundColor: _navy,
          shape: const RoundedRectangleBorder(),
          child: Builder(
            builder: (ctx) => sidebar(afterTap: () => Navigator.of(ctx).pop()),
          ),
        ),
        body: child,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.staff,
    required this.email,
    required this.isAdmin,
    required this.section,
    required this.onSection,
    required this.onSignOut,
  });

  final StaffMember staff;
  final String? email;
  final bool isAdmin;
  final _Section section;
  final ValueChanged<_Section> onSection;
  final VoidCallback onSignOut;

  static const _muted = Color(0x99FFFFFF);
  static const _faint = Color(0x66FFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget group(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(
        KuuSpacing.lg,
        KuuSpacing.lg,
        KuuSpacing.lg,
        KuuSpacing.sm,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: _faint,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
    return ColoredBox(
      color: _Frame._navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                KuuSpacing.lg,
                KuuSpacing.lg,
                KuuSpacing.lg,
                KuuSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: KuusenseLogoOnBrand(height: 34, horizontal: true),
              ),
            ),
            group('GENERAL'),
            for (final s in [_Section.home, _Section.sessions])
              _NavItem(
                section: s,
                selected: section == s,
                onTap: () => onSection(s),
              ),
            if (isAdmin) ...[
              group('ADMINISTRACIÓN'),
              for (final s in [
                _Section.tutors,
                _Section.children,
                _Section.researchers,
              ])
                _NavItem(
                  section: s,
                  selected: section == s,
                  onTap: () => onSection(s),
                ),
            ],
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(KuuSpacing.md),
              padding: const EdgeInsets.all(KuuSpacing.sm),
              decoration: BoxDecoration(
                color: KuuColor.lightSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(KuuRadius.md),
              ),
              child: Row(
                children: [
                  KuuPersonAvatar(
                    name: staff.displayName.isNotEmpty
                        ? staff.displayName
                        : email ?? staff.role.label,
                    size: 36,
                  ),
                  const SizedBox(width: KuuSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.displayName.isNotEmpty
                              ? staff.displayName
                              : email ?? 'Equipo KúuSense',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KuuColor.lightSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          staff.role.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: onSignOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: _muted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });
  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? KuuColor.lightSurface : _Sidebar._muted;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KuuSpacing.md,
        vertical: 2,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.sm),
            decoration: BoxDecoration(
              color: selected
                  ? KuuColor.brandHighlight.withValues(alpha: 0.28)
                  : _hover
                  ? KuuColor.lightSurface.withValues(alpha: 0.06)
                  : null,
              borderRadius: BorderRadius.circular(KuuRadius.sm),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: selected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: KuuColor.brandSecondary,
                    borderRadius: BorderRadius.circular(KuuRadius.pill),
                  ),
                ),
                const SizedBox(width: KuuSpacing.sm),
                Icon(
                  selected ? widget.section.selectedIcon : widget.section.icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: KuuSpacing.sm),
                Text(
                  widget.section.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: KuuSpacing.md),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
