import 'dart:math';
import 'dart:typed_data';

enum NoteType { whole, half, quarter, eighth, sixteenth }

class MusicNote {
  final String name;
  final int position;
  final NoteType type;
  final String lyric;
  final double frequency;

  MusicNote(this.name, this.position, this.type, this.lyric, {this.frequency = 0.0});
}

class AudioAnalyzer {
  static const int sampleRate = 44100;

  static Map<String, dynamic> analyzeChunk(Uint8List chunk, int sensitivity) {
    if (chunk.isEmpty) return {"volume": 0.0, "note": null, "pitch": 0.0};

    final int16Data = Int16List(chunk.length ~/ 2);
    final byteData = chunk.buffer.asByteData(chunk.offsetInBytes, chunk.lengthInBytes);
    double sumSquare = 0;

    for (int i = 0; i < int16Data.length; i++) {
      int16Data[i] = byteData.getInt16(i * 2, Endian.little);
      sumSquare += int16Data[i] * int16Data[i];
    }

    double rms = sqrt(sumSquare / int16Data.length);
    double volume = (rms / 32768.0) * (sensitivity / 20.0);

    if (volume < 0.05) {
      return {"volume": volume, "note": null, "pitch": 0.0};
    }

    double pitch = _detectPitch(int16Data, sampleRate);

    MusicNote? note;
    if (pitch > 80 && pitch < 1200) {
      note = _frequencyToNote(pitch);
    }

    return {
      "volume": volume.clamp(0.0, 1.0),
      "note": note,
      "pitch": pitch
    };
  }

  static double _detectPitch(Int16List buffer, int sampleRate) {
    int maxOffset = sampleRate ~/ 80;
    int minOffset = sampleRate ~/ 1000;

    double maxCorrelation = 0;
    int bestOffset = -1;

    for (int offset = minOffset; offset < maxOffset; offset++) {
      double correlation = 0;
      int limit = min(buffer.length - offset, 512);

      for (int i = 0; i < limit; i++) {
        correlation += buffer[i] * buffer[i + offset];
      }

      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestOffset = offset;
      }
    }

    if (bestOffset > 0) {
      return sampleRate / bestOffset;
    }
    return 0.0;
  }

  static MusicNote _frequencyToNote(double freq) {
    double noteNum = 69 + 12 * (log(freq / 440.0) / log(2.0));
    int midiNote = noteNum.round();

    int relativeIndex = midiNote - 60;

    int position = relativeIndex;

    List<String> names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    String name = names[midiNote % 12];

    return MusicNote(name, position, NoteType.quarter, "", frequency: freq);
  }
}