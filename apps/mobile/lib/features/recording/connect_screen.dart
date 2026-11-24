import 'package:emotibit/emotibit.dart';
import 'package:flutter/material.dart';

import 'recording_controller.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.controller});
  final RecordingController controller;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _manualIp = TextEditingController();
  List<DiscoveredEmotiBit> _devices = [];
  bool _scanning = false;
  String? _connectingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      _devices = await widget.controller.scan(manualIp: _manualIp.text);
    } catch (e) {
      _error = 'Error al buscar: $e';
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect(DiscoveredEmotiBit d) async {
    setState(() {
      _connectingId = d.deviceId;
      _error = null;
    });
    try {
      await widget.controller.connect(d);
    } catch (e) {
      _error = 'No se pudo conectar: $e';
    }
    if (mounted) setState(() => _connectingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar EmotiBit'),
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Grabando para ${c.childLabel ?? ''}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Enciende el EmotiBit y conecta el teléfono a la misma red WiFi.'),
            if (c.deviceLostMessage != null) ...[
              const SizedBox(height: 12),
              Text(c.deviceLostMessage!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Dispositivos', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (_scanning)
                  const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(onPressed: _scan, icon: const Icon(Icons.refresh), tooltip: 'Buscar de nuevo'),
              ],
            ),
            if (!_scanning && _devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No se encontraron EmotiBits. Revisa la red o ingresa la IP abajo.'),
              ),
            for (final d in _devices)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.watch),
                  title: Text(d.deviceId),
                  subtitle: Text(d.isAvailable ? d.address.address : '${d.address.address} · en uso por otro equipo'),
                  trailing: _connectingId == d.deviceId
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  enabled: d.isAvailable && _connectingId == null,
                  onTap: () => _connect(d),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('Conectar por IP'),
              subtitle: const Text('Si la búsqueda automática no funciona (p. ej. en iPhone)'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualIp,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '192.168.1.50'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: _scan, child: const Text('Buscar')),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
