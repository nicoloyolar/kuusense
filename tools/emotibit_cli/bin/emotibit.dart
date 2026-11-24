import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:emotibit/emotibit.dart';

/// Herramienta de terminal para trabajar con un EmotiBit desde el computador.
///
///   `dart run emotibit_cli:emotibit COMANDO [opciones]`
///   (o `make emotibit ARGS="..."` desde la raíz del repo)
Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('emotibit', 'Herramientas para EmotiBit (KúuSense).')
    ..addCommand(ScanCommand())
    ..addCommand(MonitorCommand())
    ..addCommand(RecordCommand())
    ..addCommand(AnalyzeCommand())
    ..addCommand(SimulateCommand());
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } on EmotiBitException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

String _time() => DateTime.now().toIso8601String().substring(11, 23);
void _log(String line) => stdout.writeln('[${_time()}] $line');

void _addDiscoveryOptions(Command<void> c) {
  c.argParser
    ..addOption('ip', help: 'IP del EmotiBit (si la búsqueda por broadcast no funciona).')
    ..addOption('id', help: 'ID del EmotiBit a usar si hay varios en la red.')
    ..addFlag('verbose', abbr: 'v', help: 'Muestra cada mensaje del protocolo (diagnóstico).');
}

Future<List<DiscoveredEmotiBit>> _discover(Command<void> c) async {
  final ip = c.argResults!['ip'] as String?;
  final verbose = c.argResults!['verbose'] as bool;
  _log(ip == null ? 'Buscando EmotiBits en la red (broadcast)…' : 'Buscando EmotiBit en $ip…');
  return EmotiBitHost.discover(
    targets: ip == null ? null : [InternetAddress(ip)],
    timeout: const Duration(seconds: 3),
    log: verbose ? _log : null,
  );
}

// ---------------------------------------------------------------- scan

class ScanCommand extends Command<void> {
  ScanCommand() {
    _addDiscoveryOptions(this);
  }
  @override
  String get name => 'scan';
  @override
  String get description => 'Busca EmotiBits en la red WiFi.';

  @override
  Future<void> run() async {
    final found = await _discover(this);
    if (found.isEmpty) {
      _log('No se encontró ningún EmotiBit. Revisa docs/EMOTIBIT_PRIMEROS_PASOS.md');
      exitCode = 1;
      return;
    }
    for (final d in found) {
      stdout.writeln('  • ${d.deviceId.padRight(24)} ${d.address.address.padRight(16)} '
          '${d.isAvailable ? 'disponible' : 'EN USO por otro equipo'}');
    }
  }
}

// ---------------------------------------------------------------- monitor / record

class MonitorCommand extends Command<void> {
  MonitorCommand() {
    _addDiscoveryOptions(this);
    argParser
      ..addOption('record', help: 'Carpeta donde grabar la sesión (raw.csv, sync.csv, events.csv, resumen.txt).')
      ..addOption('seconds', help: 'Detenerse después de N segundos (por defecto: hasta Ctrl+C).')
      ..addOption('refresh', defaultsTo: '2', help: 'Segundos entre actualizaciones de la tabla.');
  }

  @override
  String get name => 'monitor';
  @override
  String get description => 'Se conecta y muestra en vivo qué envía el EmotiBit (frecuencias, rangos, pérdidas).';

  String? get recordDir => argResults!['record'] as String?;

  @override
  Future<void> run() async {
    final found = await _discover(this);
    final wantedId = argResults!['id'] as String?;
    final candidates = found.where((d) => wantedId == null || d.deviceId == wantedId).toList();
    if (candidates.isEmpty) {
      throw EmotiBitException(wantedId == null
          ? 'No se encontró ningún EmotiBit.'
          : 'No se encontró el EmotiBit $wantedId (vistos: ${found.map((d) => d.deviceId).join(', ')}).');
    }
    if (candidates.length > 1) {
      _log('Hay ${candidates.length} EmotiBits; usando ${candidates.first.deviceId} (elige otro con --id).');
    }
    final device = candidates.first;
    if (!device.isAvailable) {
      _log('Atención: ${device.deviceId} reporta estar conectado a otro equipo (¿EmotiBit Oscilloscope abierto?).');
    }

    final verbose = argResults!['verbose'] as bool;
    _log('Conectando a ${device.deviceId} (${device.address.address})…');
    final conn = await EmotiBitHost.connect(device, log: verbose ? _log : null);
    _log('Conectado. Ctrl+C para terminar.');

    final stats = EmotiBitStats();
    SessionRecorder? recorder;
    if (recordDir != null) {
      recorder = await SessionRecorder.start(Directory(recordDir!));
      _log('Grabando en ${recorder.directory.absolute.path}');
    }

    final seenTags = <String>{};
    final sub = conn.packets.listen((p) {
      stats.add(p);
      recorder?.add(p);
      if (seenTags.add(p.typeTag) && !TypeTag.sensorStreams.contains(p.typeTag)) {
        _log('Nuevo tipo de paquete: ${p.typeTag} → ${p.toString()}');
      }
    });
    conn.controlMessages.listen((p) => _log('Mensaje de control: $p'));

    final done = Completer<String>();
    final secs = int.tryParse(argResults!['seconds'] as String? ?? '');
    if (secs != null) Timer(Duration(seconds: secs), () => done.complete('tiempo cumplido'));
    final sigint = ProcessSignal.sigint.watch().listen((_) {
      if (!done.isCompleted) done.complete('Ctrl+C');
    });
    conn.statusChanges.listen((s) {
      if (s == EmotiBitConnectionStatus.disconnected && !done.isCompleted) {
        done.complete('el EmotiBit se desconectó');
      }
    });

    final refresh = Duration(seconds: int.tryParse(argResults!['refresh'] as String) ?? 2);
    final ticker = Timer.periodic(refresh, (_) {
      if (!verbose && stdout.hasTerminal) stdout.write('\x1B[2J\x1B[H'); // clear screen
      stdout
        ..writeln('EmotiBit ${device.deviceId} · ${device.address.address}'
            '${recorder != null ? ' · ● grabando' : ''}')
        ..writeln(stats.toTable())
        ..writeln();
    });

    final reason = await done.future;
    ticker.cancel();
    await sigint.cancel();
    await sub.cancel();
    _log('Terminando ($reason)…');
    await conn.close();

    stdout
      ..writeln()
      ..writeln(stats.toTable());
    if (recorder != null) {
      await recorder.stop();
      final summary = File('${recorder.directory.path}/resumen.txt');
      await summary.writeAsString('EmotiBit ${device.deviceId} (${device.address.address})\n'
          'Inicio: ${recorder.startedAt}\nFin: ${recorder.endedAt}\n\n${stats.toTable()}\n');
      _log('Sesión guardada en ${recorder.directory.absolute.path}');
    }
    exit(0);
  }
}

class RecordCommand extends MonitorCommand {
  @override
  String get name => 'record';
  @override
  String get description => 'Igual que monitor, pero grabando en recordings/<fecha-hora>/ por defecto.';

  @override
  String? get recordDir {
    final explicit = argResults!['record'] as String?;
    if (explicit != null) return explicit;
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    return 'recordings/$stamp';
  }
}

// ---------------------------------------------------------------- analyze

class AnalyzeCommand extends Command<void> {
  @override
  String get name => 'analyze';
  @override
  String get description => 'Analiza un raw.csv grabado (o un archivo de la microSD del EmotiBit).';
  @override
  String get invocation => 'emotibit analyze <archivo.csv>';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) usageException('Falta el archivo a analizar.');
    final file = File(rest.first);
    if (!file.existsSync()) throw EmotiBitException('No existe ${file.path}');

    final stats = EmotiBitStats();
    var lines = 0, malformed = 0;
    await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      lines++;
      final p = EmotiBitPacket.tryParse(line);
      p == null ? malformed++ : stats.add(p);
    }
    stdout
      ..writeln('${file.path}: $lines líneas, $malformed no reconocidas')
      ..writeln(stats.toTable());
  }
}

// ---------------------------------------------------------------- simulate

class SimulateCommand extends Command<void> {
  SimulateCommand() {
    argParser
      ..addOption('id', defaultsTo: 'SIM-0001', help: 'ID del dispositivo simulado.')
      ..addOption('hr', defaultsTo: '72', help: 'Frecuencia cardíaca simulada (bpm).')
      ..addOption('port', defaultsTo: '${EmotiBitPorts.advertising}', help: 'Puerto UDP de anuncio.');
  }
  @override
  String get name => 'simulate';
  @override
  String get description => 'Ejecuta un EmotiBit simulado en este computador.';

  @override
  Future<void> run() async {
    final sim = EmotiBitSimulator(
      deviceId: argResults!['id'] as String,
      heartRateBpm: double.parse(argResults!['hr'] as String),
      advertisingPort: int.parse(argResults!['port'] as String),
    );
    sim.log.listen(_log);
    await sim.start();
    final ips = (await NetworkInterface.list(type: InternetAddressType.IPv4))
        .expand((i) => i.addresses)
        .map((a) => a.address);
    _log('IPs de este equipo: ${ips.join(', ')}. Ctrl+C para detener.');
    await ProcessSignal.sigint.watch().first;
    await sim.stop();
    exit(0);
  }
}
