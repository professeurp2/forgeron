import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void generateWav(String filename, double Function(double) freqFunc, double duration, {int sampleRate = 44100}) {
  final numSamples = (sampleRate * duration).toInt();
  final byteData = ByteData(numSamples * 2);

  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double value = freqFunc(t);

    // Apply envelope
    double env = 1.0;
    if (t < 0.01) env = t / 0.01;
    else if (t > duration - 0.01) env = (duration - t) / 0.01;

    int intValue = (value * env * 32767.0).toInt();
    if (intValue > 32767) intValue = 32767;
    if (intValue < -32768) intValue = -32768;

    byteData.setInt16(i * 2, intValue, Endian.little);
  }

  final file = File(filename);
  final raf = file.openSync(mode: FileMode.write);

  // RIFF header
  raf.writeStringSync('RIFF');
  // File size: 36 bytes for headers + data size
  final fileSizeData = ByteData(4)..setUint32(0, 36 + numSamples * 2, Endian.little);
  raf.writeFromSync(fileSizeData.buffer.asUint8List());
  raf.writeStringSync('WAVE');

  // fmt chunk
  raf.writeStringSync('fmt ');
  final fmtChunkSize = ByteData(4)..setUint32(0, 16, Endian.little);
  raf.writeFromSync(fmtChunkSize.buffer.asUint8List());
  
  final fmtChunkData = ByteData(16)..setUint16(0, 1, Endian.little) // PCM
                                  ..setUint16(2, 1, Endian.little) // 1 channel
                                  ..setUint32(4, sampleRate, Endian.little)
                                  ..setUint32(8, sampleRate * 2, Endian.little) // Byte rate
                                  ..setUint16(12, 2, Endian.little) // Block align
                                  ..setUint16(14, 16, Endian.little); // Bits per sample
  raf.writeFromSync(fmtChunkData.buffer.asUint8List());

  // data chunk
  raf.writeStringSync('data');
  final dataChunkData = ByteData(4)..setUint32(0, numSamples * 2, Endian.little);
  raf.writeFromSync(dataChunkData.buffer.asUint8List());

  raf.writeFromSync(byteData.buffer.asUint8List());
  raf.closeSync();
  print('Generated $filename');
}

void main() {
  Directory('assets/audio').createSync(recursive: true);

  // 1. Click
  generateWav('assets/audio/click.wav', (t) => sin(2.0 * pi * 1000.0 * t), 0.05);

  // 2. Nav
  generateWav('assets/audio/nav.wav', (t) => sin(2.0 * pi * 600.0 * t), 0.08);

  // 3. Alert
  generateWav('assets/audio/alert.wav', (t) => (t % 0.2 < 0.1) ? sin(2.0 * pi * 800.0 * t) : 0, 0.4);

  // 4. Alarm
  generateWav('assets/audio/alarm.wav', (t) => sin(2.0 * pi * ((t % 0.4 < 0.2) ? 1000.0 : 1200.0) * t), 1.0);

  // 5. Success
  generateWav('assets/audio/success.wav', (t) {
    if (t < 0.15) return sin(2.0 * pi * 440.0 * t);
    if (t < 0.30) return sin(2.0 * pi * 554.0 * t);
    return sin(2.0 * pi * 659.0 * t);
  }, 0.6);

  // 6. Scan
  generateWav('assets/audio/scan.wav', (t) => sin(2.0 * pi * (400.0 + 800.0 * t) * t), 0.5);
}
