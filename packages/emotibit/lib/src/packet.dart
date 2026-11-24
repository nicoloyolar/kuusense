/// One EmotiBit text packet:
/// `timestamp,packetNumber,dataLength,typeTag,protocolVersion,dataReliability[,payload...]\n`
///
/// Note: the device sometimes sends a payload with `dataLength == 0`
/// (e.g. HELLO_HOST), so parsing never trusts `dataLength` to find the payload.
class EmotiBitPacket {
  const EmotiBitPacket({
    required this.timestamp,
    required this.packetNumber,
    required this.typeTag,
    this.payload = const [],
    this.protocolVersion = 1,
    this.dataReliability = 100,
    int? dataLength,
  }) : _dataLength = dataLength;

  /// Device ms since boot.
  final int timestamp;
  final int packetNumber;
  final String typeTag;
  final List<String> payload;
  final int protocolVersion;
  final int dataReliability;
  final int? _dataLength;

  int get dataLength => _dataLength ?? payload.length;

  static const headerLength = 6;
  static const delimiter = ',';
  static const terminator = '\n';

  /// Parses a single packet line (without the trailing newline). Returns null
  /// if the header is malformed.
  static EmotiBitPacket? tryParse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(delimiter);
    if (parts.length < headerLength) return null;
    final ts = int.tryParse(parts[0]);
    final pn = int.tryParse(parts[1]);
    final len = int.tryParse(parts[2]);
    final tag = parts[3];
    final ver = int.tryParse(parts[4]);
    final rel = int.tryParse(parts[5]);
    if (ts == null || pn == null || len == null || ver == null || rel == null) {
      return null;
    }
    if (tag.length != 2) return null;
    return EmotiBitPacket(
      timestamp: ts,
      packetNumber: pn,
      dataLength: len,
      typeTag: tag,
      protocolVersion: ver,
      dataReliability: rel,
      payload: parts.sublist(headerLength),
    );
  }

  /// Splits a datagram / stream chunk into packets (multi-packet datagrams are
  /// possible), silently dropping malformed lines.
  static List<EmotiBitPacket> parseAll(String text) => text
      .split(terminator)
      .map(tryParse)
      .whereType<EmotiBitPacket>()
      .toList();

  /// Payload parsed as doubles (non-numeric entries skipped).
  List<double> get values =>
      payload.map(double.tryParse).whereType<double>().toList();

  /// Reads a keyed value from a payload like `DP,3132,DI,abc` (order-free).
  String? keyedValue(String key) {
    for (var i = 0; i + 1 < payload.length; i += 2) {
      if (payload[i] == key) return payload[i + 1];
    }
    return null;
  }

  String encode() {
    final header = [
      timestamp, packetNumber, dataLength, typeTag, protocolVersion,
      dataReliability,
    ].join(delimiter);
    return payload.isEmpty
        ? '$header$terminator'
        : '$header$delimiter${payload.join(delimiter)}$terminator';
  }

  @override
  String toString() => encode().trim();
}
