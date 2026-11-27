import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/data_table.dart';
import '../common/panel.dart';
import 'session_cells.dart';
import 'signals_card.dart';

/// One session inside the panel: key figures, signal charts, marked events,
/// details and raw files. Updates live while still recording.
class SessionDetailView extends StatefulWidget {
  const SessionDetailView({
    super.key,
    required this.repo,
    required this.childId,
    required this.sessionId,
    required this.childCode,
    required this.onBack,
  });

  final KuusenseRepository repo;
  final String childId;
  final String sessionId;
  final String childCode;
  final VoidCallback onBack;

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView> {
  late final Stream<RecordingSession?> _session = widget.repo.watchSession(
    widget.childId,
    widget.sessionId,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RecordingSession?>(
      stream: _session,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('No se pudo cargar la sesión.\n${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return snap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text('La sesión no existe.'));
        }
        final s = snap.data!;
        final day = formatDayHeading(
          DateTime.fromMillisecondsSinceEpoch(s.startedAtMs),
        );
        final details = _Details(session: s);
        final files = _Files(repo: widget.repo, session: s);
        return KuuPageBody(
          children: [
            KuuPageHeader(
              breadcrumbs: [('Sesiones', widget.onBack)],
              title: 'Sesión ${widget.childCode}',
              subtitle:
                  '${day[0].toUpperCase()}${day.substring(1)} · ${formatTime(s.startedAtMs)}'
                  '${s.endedAtMs == null ? '' : ' a ${formatTime(s.endedAtMs!)}'}',
              actions: [
                SessionOutcomeBadge(s),
                SessionStateBadge(s),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Volver'),
                ),
              ],
            ),
            if (s.gaps.isNotEmpty || s.isIncomplete) ...[
              const SizedBox(height: KuuSpacing.sm),
              KuuDataGapsNote(session: s),
            ],
            const SizedBox(height: KuuSpacing.lg),
            _Figures(session: s),
            const SizedBox(height: KuuSpacing.md),
            if (SignalsCard.hasContent(s)) ...[
              SignalsCard(repo: widget.repo, session: s),
              const SizedBox(height: KuuSpacing.md),
            ],
            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 1100
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _Events(session: s)),
                        const SizedBox(width: KuuSpacing.md),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              details,
                              const SizedBox(height: KuuSpacing.md),
                              files,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _Events(session: s),
                        const SizedBox(height: KuuSpacing.md),
                        details,
                        const SizedBox(height: KuuSpacing.md),
                        files,
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ figures

class _Figures extends StatelessWidget {
  const _Figures({required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final st = s.stats;
    final live = s.status == SessionStatus.recording ? s.live : null;
    String n(double? v, int d) => v == null ? '—' : v.toStringAsFixed(d);
    final battery = st?.batteryStart != null && st?.batteryEnd != null
        ? '${n(st!.batteryStart, 0)}→${n(st.batteryEnd, 0)}'
        : n(live?.batteryPercent, 0);
    return KuuGrid(
      minItemWidth: 200,
      maxColumns: 6,
      children: [
        KuuStatCard(
          label: 'Duración',
          value: formatDuration(s.duration),
          icon: Icons.timer_outlined,
          color: KuuColor.brandPrimary,
        ),
        KuuStatCard(
          label: live != null ? 'Pulso ahora' : 'Pulso medio',
          value: live != null
              ? n(live.heartRate, 0)
              : n(st?.heartRate?.mean, 0),
          hint: 'lpm',
          icon: Icons.favorite_rounded,
          color: KuuColor.statePreCrisis,
        ),
        KuuStatCard(
          label: live != null ? 'EDA ahora' : 'EDA media',
          value: live != null ? n(live.eda, 2) : n(st?.eda?.mean, 2),
          hint: 'µS',
          icon: Icons.water_drop_outlined,
          color: KuuColor.brandHighlight,
        ),
        KuuStatCard(
          label: 'Eventos',
          value: '${s.events.length}',
          icon: Icons.flag_rounded,
          color: KuuColor.brandSecondary,
        ),
        KuuStatCard(
          label: 'Pérdida de datos',
          value: st == null ? '—' : '${st.lossPercent.toStringAsFixed(1)} %',
          icon: Icons.signal_cellular_alt_rounded,
          color: KuuColor.feedbackInfo,
        ),
        KuuStatCard(
          label: 'Batería',
          value: battery,
          hint: '%',
          icon: Icons.battery_5_bar_rounded,
          color: KuuColor.stateAlert,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ events

class _Events extends StatelessWidget {
  const _Events({required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final events = [...s.events]..sort((a, b) => a.atMs.compareTo(b.atMs));
    return KuuPanel(
      title: 'Eventos marcados',
      padding: EdgeInsets.zero,
      child: KuuDataTable<SessionEvent>(
        embedded: true,
        minWidth: 520,
        rows: events,
        emptyText: 'No se marcaron eventos en esta sesión.',
        columns: [
          KuuColumn(
            label: 'Hora',
            flex: 2,
            cell: (e) => Text(formatTime(e.atMs)),
          ),
          KuuColumn(
            label: 'Minuto',
            flex: 2,
            cell: (e) => MutedText(
              formatOffset(Duration(milliseconds: e.atMs - s.startedAtMs)),
            ),
          ),
          KuuColumn(
            label: 'Evento',
            flex: 4,
            cell: (e) => Row(
              children: [
                Icon(
                  kuuEventIcon(e.kind),
                  size: 18,
                  color: kuuEventColor(context, e.kind),
                ),
                const SizedBox(width: KuuSpacing.sm),
                Flexible(
                  child: Text(
                    e.kind == BehaviorCatalog.noteId ? 'Nota' : e.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          KuuColumn(
            label: 'Nota',
            flex: 4,
            cell: (e) =>
                e.kind == BehaviorCatalog.noteId && (e.note ?? '').isNotEmpty
                ? Tooltip(message: e.note!, child: Text(e.note!))
                : const MutedText('—'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ details

class _Details extends StatelessWidget {
  const _Details({required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final ctx = s.context;
    final rows = <(String, String)>[
      ('Lugar', ctx.place?.label ?? 'Sin registrar'),
      ('Actividad', ctx.activity?.label ?? 'Sin registrar'),
      (
        'Presentes',
        ctx.present.isEmpty
            ? 'Sin registrar'
            : ctx.present.map((t) => t.label).join(', '),
      ),
      if ((ctx.comment ?? '').isNotEmpty) ('Comentarios', ctx.comment!),
      ('Término', sessionEndReasonLabel(s.endReason)),
      ('Dispositivo', s.deviceId.isEmpty ? '—' : s.deviceId),
      (
        'Paquetes',
        s.status == SessionStatus.recording ? 'En curso' : '${s.packetCount}',
      ),
      ('Señales', s.streams.isEmpty ? '—' : '${s.streams.length} canales'),
      ('Versión app', s.appVersion.isEmpty ? '—' : s.appVersion),
    ];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return KuuPanel(
      title: 'Detalles',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, (label, value)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KuuSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.6),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ files

class _Files extends StatelessWidget {
  const _Files({required this.repo, required this.session});
  final KuusenseRepository repo;
  final RecordingSession session;

  static const _descriptions = {
    'raw.csv': 'Señales del EmotiBit (formato SD)',
    'sync.csv': 'Sincronización de relojes',
    'events.csv': 'Eventos con hora del dispositivo',
    'signals.csv': 'Resumen por segundo',
  };

  Future<void> _download(BuildContext context, String path) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await repo.downloadUrl(path);
      await launchUrl(Uri.parse(url));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo descargar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = session.files.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return KuuPanel(
      title: 'Archivos',
      padding: EdgeInsets.zero,
      child: KuuDataTable<MapEntry<String, String>>(
        embedded: true,
        minWidth: 360,
        rows: files,
        emptyText: session.status == SessionStatus.uploaded
            ? 'La sesión no tiene archivos.'
            : 'Los archivos aparecen cuando el teléfono termina de subir la sesión.',
        columns: [
          KuuColumn(
            label: 'Archivo',
            flex: 2,
            cell: (f) => Text(
              f.key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          KuuColumn(
            label: 'Contenido',
            flex: 3,
            cell: (f) => MutedText(_descriptions[f.key] ?? ''),
          ),
          KuuColumn(
            label: '',
            width: 64,
            alignEnd: true,
            cell: (f) => IconButton(
              tooltip: 'Descargar',
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: () => _download(context, f.value),
            ),
          ),
        ],
      ),
    );
  }
}
