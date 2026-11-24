/// EmotiBit 2-character type tags.
///
/// Source: EmotiBit_XPlat_Utils `src/EmotiBitPacket.cpp` (master).
abstract final class TypeTag {
  // --- Sensor data ---
  static const eda = 'EA';
  static const edl = 'EL';
  static const edr = 'ER';
  static const ppgInfrared = 'PI';
  static const ppgRed = 'PR';
  static const ppgGreen = 'PG';
  static const spo2 = 'O2';
  static const temperature0 = 'T0';
  static const temperature1 = 'T1';
  static const thermopile = 'TH';
  static const humidity0 = 'H0';
  static const accelX = 'AX';
  static const accelY = 'AY';
  static const accelZ = 'AZ';
  static const gyroX = 'GX';
  static const gyroY = 'GY';
  static const gyroZ = 'GZ';
  static const magX = 'MX';
  static const magY = 'MY';
  static const magZ = 'MZ';

  // --- Device info ---
  static const batteryVoltage = 'BV';
  static const batteryPercent = 'B%';
  static const buttonShort = 'BS';
  static const buttonLong = 'BL';
  static const dataClipping = 'DC';
  static const dataOverflow = 'DO';
  static const sdCardPercent = 'SD';
  static const reset = 'RS';
  static const debug = 'DB';
  static const mode = 'EM';
  static const info = 'EI';
  static const timestampEmotibit = 'TE';

  // --- Derived (aperiodic) ---
  static const heartRate = 'HR';
  static const interBeatInterval = 'BI';
  static const scrAmplitude = 'SA';
  static const scrFrequency = 'SF';
  static const scrRiseTime = 'SR';

  // --- Host -> EmotiBit ---
  static const userNote = 'UN';
  static const lslMarker = 'LM';
  static const timestampLocal = 'TL';
  static const timestampUtc = 'TU';
  static const timestampCross = 'TX';

  // --- Control ---
  static const recordBegin = 'RB';
  static const recordEnd = 'RE';
  static const modeNormalPower = 'MN';
  static const modeLowPower = 'ML';
  static const modeMaxLowPower = 'MM';
  static const modeWirelessOff = 'MO';
  static const modeHibernate = 'MH';
  static const emotibitDisconnect = 'ED';

  // --- Advertising (UDP 3131) ---
  static const ping = 'PN';
  static const pong = 'PO';
  static const helloEmotibit = 'HE';
  static const helloHost = 'HH';
  static const emotibitConnect = 'EC';

  // --- General ---
  static const ack = 'AK';
  static const nack = 'NK';
  static const requestData = 'RD';

  /// Periodic physiological streams worth recording/plotting.
  static const sensorStreams = {
    eda, edl, edr, ppgInfrared, ppgRed, ppgGreen, spo2, temperature0,
    temperature1, thermopile, humidity0, accelX, accelY, accelZ, gyroX,
    gyroY, gyroZ, magX, magY, magZ,
  };

  /// Derived metrics computed on-device (one value per event).
  static const derived = {
    heartRate, interBeatInterval, scrAmplitude, scrFrequency, scrRiseTime,
  };

  /// Human-readable labels for UI.
  static const labels = {
    eda: 'EDA (µS)',
    ppgInfrared: 'PPG infrarrojo',
    ppgRed: 'PPG rojo',
    ppgGreen: 'PPG verde',
    temperature0: 'Temperatura (°C)',
    thermopile: 'Termopila (°C)',
    accelX: 'Acel. X', accelY: 'Acel. Y', accelZ: 'Acel. Z',
    gyroX: 'Giro X', gyroY: 'Giro Y', gyroZ: 'Giro Z',
    magX: 'Mag X', magY: 'Mag Y', magZ: 'Mag Z',
    heartRate: 'Frec. cardíaca (bpm)',
    interBeatInterval: 'IBI (ms)',
    scrAmplitude: 'SCR amplitud',
    scrFrequency: 'SCR frecuencia',
    scrRiseTime: 'SCR tiempo subida',
    batteryPercent: 'Batería (%)',
  };
}

/// Keys used inside key/value payloads (e.g. `DP,3132,DI,MD-V5-...`).
abstract final class PayloadLabel {
  static const controlPort = 'CP';
  static const dataPort = 'DP';
  static const deviceId = 'DI';
  static const recordingStatus = 'RS';
  static const powerStatus = 'PS';
}

abstract final class EmotiBitPorts {
  /// UDP port the device listens on for HE / EC / PN.
  static const advertising = 3131;
}
