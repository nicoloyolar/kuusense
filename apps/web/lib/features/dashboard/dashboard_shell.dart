import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../admin/children_admin_page.dart';
import '../admin/tutors_page.dart';
import '../common/page_title.dart';

import 'children_page.dart';
import 'sessions_page.dart';

/// Sections of the platform. The last two are admin-only maintainers.
enum _Section {
  home('Inicio', Icons.space_dashboard_outlined),
  sessions('Sesiones', Icons.monitor_heart_outlined),
  tutors('Tutores', Icons.group_outlined),
  children('NNA', Icons.child_care_rounded);

  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;

  bool get adminOnly => this == tutors || this == children;
}

/// Signed-in staff layout: header, section navigation (rail on wide screens,
/// bottom bar on narrow ones) and the sections. Holds the live data streams
/// so every section shares them.
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
  late final List<_Section> _sections = [
    for (final s in _Section.values)
      if (_isAdmin || !s.adminOnly) s,
  ];

  _Section _section = _Section.home;

  /// NNA the sessions section is filtered to (null = all).
  String? _childFilter;

  void _openChildSessions(String childId) => setState(() {
    _childFilter = childId;
    _section = _Section.sessions;
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

                  final Widget body;
                  if (error != null) {
                    body = _Message(
                      icon: Icons.error_outline_rounded,
                      text: 'No se pudieron cargar los datos.\n$error',
                    );
                  } else if (loading) {
                    body = const Center(child: CircularProgressIndicator());
                  } else {
                    body = switch (_section) {
                      _Section.home => ChildrenPage(
                        children: children,
                        sessions: sessions,
                        onOpen: _openChildSessions,
                      ),
                      _Section.sessions => SessionsPage(
                        repo: widget.repo,
                        children: children,
                        sessions: sessions,
                        childFilter: _childFilter,
                        onFilter: (id) => setState(() => _childFilter = id),
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
                    };
                  }
                  return PageTitle(
                    _section.label,
                    child: _Frame(
                      staff: widget.staff,
                      onSignOut: widget.auth.signOut,
                      sections: _sections,
                      section: _sections.indexOf(_section),
                      onSection: (i) => setState(() => _section = _sections[i]),
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

class _Frame extends StatelessWidget {
  const _Frame({
    required this.staff,
    required this.onSignOut,
    required this.sections,
    required this.section,
    required this.onSection,
    required this.child,
  });

  final StaffMember staff;
  final VoidCallback onSignOut;
  final List<_Section> sections;
  final int section;
  final ValueChanged<int> onSection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final appBar = AppBar(
      toolbarHeight: 64,
      titleSpacing: KuuSpacing.md,
      title: const KuusenseLogo(height: 34, horizontal: true),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.sm),
          child: Chip(
            avatar: const Icon(Icons.verified_user_outlined, size: 18),
            label: Text(staff.role.label),
            visualDensity: VisualDensity.compact,
          ),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: KuuSpacing.sm),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: theme.colorScheme.outline),
      ),
    );

    if (!wide) {
      return Scaffold(
        appBar: appBar,
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: section,
          onDestinationSelected: onSection,
          destinations: [
            for (final d in sections)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: section,
            onDestinationSelected: onSection,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in sections)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: theme.colorScheme.outline),
          Expanded(child: child),
        ],
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
