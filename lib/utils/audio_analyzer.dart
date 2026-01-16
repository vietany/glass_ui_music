import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

enum NoteType { whole, half, quarter, eighth, sixteenth }

class MusicNote {
  final String name;
  final double position;
  NoteType type;
  String lyric;
  final Duration startTime;
  Duration duration;

  MusicNote(this.name, this.position, this.type, this.lyric, this.startTime, {this.duration = const Duration(milliseconds: 500)});
}

class AudioAnalyzer {
  static final List<String> NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

  static Map<String, dynamic> analyzeChunk(Uint8List chunk, int sensitivity) {
    double volume = 0;
    List<double> samples = [];

    // 1. Chuyển đổi PCM 16-bit sang Double
    for (int i = 0; i < chunk.length; i += 2) {
      if (i + 1 >= chunk.length) break;
      int byte1 = chunk[i];
      int byte2 = chunk[i + 1];
      int shortVal = (byte2 << 8) | byte1;
      if (shortVal > 32767) shortVal -= 65536;
      double sample = shortVal / 32768.0;
      samples.add(sample);
      volume += sample * sample;
    }
    volume = sqrt(volume / samples.length);

    double pitch = 0;
    MusicNote? note;

    // 2. Phân tích Pitch (chỉ khi có âm thanh đủ lớn)
    if (volume > 0.05 && samples.isNotEmpty) {
      // FFT yêu cầu kích thước mảng là lũy thừa của 2 (Power of 2)
      int n = 1;
      while (n * 2 <= samples.length) {
        n *= 2;
      }

      if (n >= 64) {
        // Cắt mảng samples cho đúng kích thước n
        final fftInput = samples.sublist(0, n);

        // Thực hiện FFT
        final fft = FFT(n);
        final freq = fft.realFft(fftInput);

        double maxMag = 0;
        int maxIdx = 0;

        // Tìm tần số có biên độ lớn nhất (Bỏ qua tần số thấp nhiễu < 1)
        for (int i = 1; i < freq.length; i++) {
          // Tính biên độ (Magnitude) từ số phức: sqrt(real^2 + imag^2)
          // freq[i].x là phần thực, freq[i].y là phần ảo
          double mag = freq[i].x * freq[i].x + freq[i].y * freq[i].y;
          if (mag > maxMag) {
            maxMag = mag;
            maxIdx = i;
          }
        }

        double sampleRate = 44100;
        pitch = maxIdx * sampleRate / n;

        // Lọc nhiễu: Chỉ lấy pitch trong quãng giọng người (80Hz - 1000Hz)
        if (pitch > 80 && pitch < 1000) {
          note = _frequencyToNote(pitch);
        }
      }
    }

    return {
      "volume": volume,
      "pitch": pitch,
      "note": note
    };
  }

  static MusicNote _frequencyToNote(double freq) {
    if (freq == 0) return MusicNote("C", 0, NoteType.quarter, "", Duration.zero);

    // Công thức MIDI: 69 + 12 * log2(freq / 440)
    int midi = (69 + 12 * (log(freq / 440) / log(2))).round();
    int noteIndex = midi % 12;
    // SỬA LỖI Ở ĐÂY: Dùng ~/ để chia lấy phần nguyên
    int octave = (midi ~/ 12) - 1;

    String name = NOTE_NAMES[noteIndex];

    // Tính vị trí nốt nhạc so với C4
    double position = 0;
    if (name == "C") position = 0;
    else if (name == "D") position = 1;
    else if (name == "E") position = 2;
    else if (name == "F") position = 3;
    else if (name == "G") position = 4;
    else if (name == "A") position = 5;
    else if (name == "B") position = 6;

    position += (octave - 4) * 7;

    return MusicNote(name, position, NoteType.quarter, "", Duration.zero);
  }
}