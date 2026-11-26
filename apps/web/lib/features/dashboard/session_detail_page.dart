import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/page_title.dart';
import 'dash_page.dart';
import 'signals_card.dart';

/// One session: header with outcome, key figures, signal charts, marked
/// events on a timeline, context and raw files. Updates live while still recording.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.repo,
    required this.childId,
    required this.sessionId,
    required this.childCode,
  });

  final KuusenseRepository repo;
  final String childId;
  final String sessionId;
  final String childCode;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late final Stream<RecordingSession?> _session = widget.repo.watchSession(
    widget.childId,
    widget.sessionId,
  );

  @override
  Widget build(BuildContext context) {
    return PageTitle(
      'Sesión ${widget.childCode}',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Volver a sesiones'),
          titleTextStyle: Theme.of(context).textTheme.titleMedium,
        ),
        body: StreamBuilder<RecordingSession?>(
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
            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1000;
                final side = [
                  _ContextCard(session: s),
                  if (s.status == SessionStatus.recording && s.live != null)
                    _LiveCard(live: s.live!),
                  _Files(repo: widget.repo, session: s),
                ];
                return DashPage(
                  children: [
                    _Header(session: s, childCode: widget.childCode),
                    const SizedBox(height: KuuSpacing.lg),
                    _Figures(session: s),
                    const SizedBox(height: KuuSpacing.lg),
                    if (SignalsCard.hasContent(s)) ...[
                      SignalsCard(repo: widget.repo, session: s),
                      const SizedBox(height: KuuSpacing.lg),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _Events(session: s)),
                          const SizedBox(width: KuuSpacing.lg),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                for (final w in side)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: KuuSpacing.lg,
                                    ),
                                    child: w,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _Events(session: s),
                      for (final w in side)
                        Padding(
                          padding: const EdgeInsets.only(top: KuuSpacing.lg),
                          child: w,
                        ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header & figures

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.childCode});
  final RecordingSession session;
  final String childCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    final day = DateTime.fromMillisecondsSinceEpoch(s.startedAtMs);
    final heading = formatDayHeading(day);
    return Wrap(
      spacing: KuuSpacing.lg,
      runSpacing: KuuSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KuuIconTile(
              icon: kuuPlaceIcon(s.context.place),
              color: KuuColor.brandPrimary,
              size: 64,
              round: true,
            ),
            const SizedBox(width: KuuSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sesión de $childCode',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (s.isDemo) ...[
                      const SizedBox(width: KuuSpacing.sm),
                      const KuuDemoBadge(),
                    ],
                  ],
                ),
                Text(
                  '${heading[0].toUpperCase()}${heading.substring(1)} · ${formatTime(s.startedAtMs)}'
                  '${s.endedAtMs == null ? '' : ' a ${formatTime(s.endedAtMs!)}'}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                KuuDataGapsNote(session: s),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KuuOutcomeBadge(outcome: SessionOutcome.of(s)),
            const SizedBox(width: KuuSpacing.sm),
            if (s.status != SessionStatus.uploaded)
              KuuPill(
                icon: s.status == SessionStatus.recording
                    ? Icons.fiber_manual_record
                    : Icons.cloud_off_rounded,
                text: sessionStatusLabel(s.status),
                color: theme.colorScheme.error,
              ),
          ],
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final crises = s.events.where((e) => e.kind == 'crisisStart').length;
    final items = [
      (
        Icons.timer_outlined,
        formatDuration(s.duration),
        'Duración',
        KuuColor.brandPrimary,
      ),
      (
        Icons.flag_rounded,
        '${s.events.length}',
        'Eventos marcados',
        KuuColor.brandHighlight,
      ),
      (Icons.bolt_rounded, '$crises', 'Crisis', KuuColor.statePreCrisis),
      (
        Icons.local_activity_outlined,
        s.context.activity?.label ?? '—',
        'Actividad',
        KuuColor.brandSecondary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : 2;
        final w = (c.maxWidth - KuuSpacing.lg * (cols - 1)) / cols;
        return Wrap(
          spacing: KuuSpacing.lg,
          runSpacing: KuuSpacing.lg,
          children: [
            for (final (icon, value, label, color) in items)
              SizedBox(
                width: w,
                child: KuuSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(KuuSpacing.lg),
                    child: Row(
                      children: [
                        KuuIconTile(icon: icon, color: color, size: 48),
                        const SizedBox(width: KuuSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                label,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ cards

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: KuuSpacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KuuSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: KuuSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final ctx = s.context;
    return _Card(
      title: 'Contexto',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field('Lugar', ctx.place?.label ?? 'Sin registrar'),
          _Field('Actividad', ctx.activity?.label ?? 'Sin registrar'),
          _Field(
            'Presentes',
            ctx.present.isEmpty
                ? 'Sin registrar'
                : ctx.present.map((t) => t.label).join(', '),
          ),
          _Field('Dispositivo', s.deviceId.isEmpty ? '—' : s.deviceId),
          _Field(
            'Paquetes',
            s.status == SessionStatus.recording
                ? 'En curso'
                : '${s.packetCount}',
          ),
          _Field(
            'Señales',
            s.streams.isEmpty ? '—' : '${s.streams.length} canales',
          ),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live});
  final LiveSnapshot live;

  @override
  Widget build(BuildContext context) {
    String num(double? v, int d, String unit) =>
        v == null ? '—' : '${v.toStringAsFixed(d)} $unit';
    return _Card(
      title: 'En vivo',
      icon: Icons.sensors_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field('Actualizado', formatTime(live.updatedAtMs)),
          _Field('Frec. cardíaca', num(live.heartRate, 0, 'bpm')),
          _Field('EDA', num(live.eda, 2, 'µS')),
          _Field('Temperatura', num(live.temperature, 1, '°C')),
          _Field('Batería', num(live.batteryPercent, 0, '%')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ events

class _Events extends StatelessWidget {
  const _Events({required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Línea de tiempo',
      icon: Icons.timeline_rounded,
      child: KuuEventTimeline(session: session),
    );
  }
}

// ------------------------------------------------------------------ files

class _Files extends StatelessWidget {
  const _Files({required this.repo, required this.session});
  final KuusenseRepository repo;
  final RecordingSession session;

  static const _descriptions = {
    'raw.csv': 'Señales del EmotiBit (formato de la tarjeta SD)',
    'sync.csv': 'Sincronización de relojes teléfono–dispositivo',
    'events.csv': 'Eventos con la hora del dispositivo',
    'signals.csv': 'Resumen por segundo (para gráficos)',
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
    final theme = Theme.of(context);
    final files = session.files.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final String emptyText;
    if (session.isDemo) {
      emptyText = 'Sesión de demostración: no tiene archivos de señales.';
    } else if (session.status == SessionStatus.uploaded) {
      emptyText = 'La sesión no tiene archivos.';
    } else {
      emptyText =
          'Los archivos aparecen cuando el teléfono termina de subir la sesión.';
    }
    return _Card(
      title: 'Archivos',
      icon: Icons.folder_outlined,
      child: files.isEmpty
          ? Text(
              emptyText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final f in files)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const KuuIconTile(
                      icon: Icons.description_outlined,
                      color: KuuColor.brandPrimary,
                      size: 36,
                    ),
                    title: Text(f.key),
                    subtitle: Text(_descriptions[f.key] ?? ''),
                    trailing: IconButton(
                      tooltip: 'Descargar',
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => _download(context, f.value),
                    ),
                  ),
              ],
            ),
    );
  }
}
