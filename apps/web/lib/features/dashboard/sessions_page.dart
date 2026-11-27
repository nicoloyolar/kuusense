import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/data_table.dart';
import '../common/panel.dart';
import 'session_cells.dart';

enum _StateFilter { all, recording, complete, incomplete, failed }

/// Every recorded session in one sortable, filterable table.
class SessionsPage extends StatefulWidget {
  const SessionsPage({
    super.key,
    required this.children,
    required this.sessions,
    required this.profiles,
    required this.childFilter,
    required this.onFilter,
    required this.onOpenSession,
  });

  final List<Child> children;
  final List<RecordingSession> sessions;
  final Map<String, ChildProfile> profiles;
  final String? childFilter;
  final ValueChanged<String?> onFilter;
  final ValueChanged<RecordingSession> onOpenSession;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  _StateFilter _state = _StateFilter.all;
  SessionOutcome? _outcome;
  String _query = '';

  bool _matchesState(RecordingSession s) => switch (_state) {
    _StateFilter.all => true,
    _StateFilter.recording =>
      s.status == SessionStatus.recording ||
          s.status == SessionStatus.uploading,
    _StateFilter.complete =>
      s.status == SessionStatus.uploaded && !s.isIncomplete,
    _StateFilter.incomplete =>
      s.status == SessionStatus.uploaded && s.isIncomplete,
    _StateFilter.failed => s.status == SessionStatus.failed,
  };

  @override
  Widget build(BuildContext context) {
    final codes = {for (final c in widget.children) c.id: c.code};
    final q = _query.trim().toLowerCase();
    final rows = widget.sessions.where((s) {
      if (widget.childFilter != null && s.childId != widget.childFilter) {
        return false;
      }
      if (!_matchesState(s)) return false;
      if (_outcome != null && SessionOutcome.of(s) != _outcome) return false;
      if (q.isNotEmpty) {
        final hay =
            '${codes[s.childId] ?? ''} ${widget.profiles[s.childId]?.displayName ?? ''} ${s.deviceId}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return KuuPageBody(
      children: [
        const KuuPageHeader(
          title: 'Sesiones',
          subtitle:
              'Grabaciones de todos los NNA. Haz clic en una fila para ver sus señales y archivos.',
        ),
        const SizedBox(height: KuuSpacing.lg),
        KuuDataTable<RecordingSession>(
          rows: rows,
          rowKey: (s) => '${s.childId}/${s.id}',
          onRowTap: widget.onOpenSession,
          initialSort: 1,
          initialAscending: false,
          emptyText: 'No hay sesiones con estos filtros.',
          minWidth: 1100,
          toolbar: KuuToolbar(
            children: [
              KuuSearchField(
                hint: 'Buscar por NNA o dispositivo',
                onChanged: (v) => setState(() => _query = v),
              ),
              KuuFilter<String?>(
                label: 'NNA',
                value: widget.childFilter,
                options: [
                  (null, 'Todos'),
                  for (final c in widget.children) (c.id, c.code),
                ],
                onChanged: widget.onFilter,
                width: 160,
              ),
              KuuFilter<_StateFilter>(
                label: 'Estado',
                value: _state,
                options: const [
                  (_StateFilter.all, 'Todos'),
                  (_StateFilter.recording, 'En curso'),
                  (_StateFilter.complete, 'Completas'),
                  (_StateFilter.incomplete, 'Incompletas'),
                  (_StateFilter.failed, 'Fallidas'),
                ],
                onChanged: (v) => setState(() => _state = v),
                width: 160,
              ),
              KuuFilter<SessionOutcome?>(
                label: 'Resultado',
                value: _outcome,
                options: [
                  (null, 'Todos'),
                  for (final o in SessionOutcome.values) (o, o.label),
                ],
                onChanged: (v) => setState(() => _outcome = v),
                width: 180,
              ),
            ],
          ),
          columns: [
            KuuColumn(
              label: 'NNA',
              flex: 3,
              sortBy: (s) =>
                  widget.profiles[s.childId]?.displayName.toLowerCase() ??
                  codes[s.childId] ??
                  '',
              cell: (s) => ChildCell(
                code: codes[s.childId] ?? '—',
                profile: widget.profiles[s.childId],
              ),
            ),
            KuuColumn(
              label: 'Fecha',
              flex: 3,
              sortBy: (s) => s.startedAtMs,
              cell: (s) => SessionWhenCell(s),
            ),
            KuuColumn(
              label: 'Duración',
              flex: 2,
              sortBy: (s) => s.duration.inSeconds,
              cell: (s) => Text(formatDuration(s.duration)),
            ),
            KuuColumn(
              label: 'Lugar',
              flex: 2,
              sortBy: (s) => s.context.place?.label ?? '',
              cell: (s) => s.context.place == null
                  ? const MutedText('—')
                  : Text(s.context.place!.label),
            ),
            KuuColumn(
              label: 'Actividad',
              flex: 2,
              sortBy: (s) => s.context.activity?.label ?? '',
              cell: (s) => s.context.activity == null
                  ? const MutedText('—')
                  : Text(s.context.activity!.label),
            ),
            KuuColumn(
              label: 'Eventos',
              flex: 1,
              alignEnd: true,
              sortBy: (s) => s.events.length,
              cell: (s) => Text('${s.events.length}'),
            ),
            KuuColumn(
              label: 'Resultado',
              flex: 2,
              sortBy: (s) => SessionOutcome.of(s).index,
              cell: (s) => SessionOutcomeBadge(s),
            ),
            KuuColumn(
              label: 'Estado',
              flex: 2,
              sortBy: (s) => sessionState(s).$1,
              cell: (s) => SessionStateBadge(s),
            ),
            KuuColumn(
              label: 'Dispositivo',
              flex: 2,
              sortBy: (s) => s.deviceId,
              cell: (s) => MutedText(s.deviceId.isEmpty ? '—' : s.deviceId),
            ),
          ],
        ),
      ],
    );
  }
}
