import 'dart:typed_data';

enum NoteType { whole, half, quarter, eighth, sixteenth }

class MusicNote {
  final String name;
  final int position;
  final NoteType type;
  final String lyric;
  MusicNote(this.name, this.position, this.type, this.lyric);
}

class AudioAnalyzer {
  static Map<String, dynamic> analyzeChunk(Uint8List chunk, int threshold) {
    int zeroCrossings = 0;
    int lastSign = 0;
    int sum = 0;

    for (int i = 0; i < chunk.length; i += 2) {
      if (i + 1 < chunk.length) {
        int val = chunk[i] | (chunk[i + 1] << 8);
        if (val > 32767) val -= 65536;
        
        sum += val.abs();
        int sign = val >= 0 ? 1 : -1;
        if (lastSign != 0 && sign != lastSign) zeroCrossings++;
        lastSign = sign;
      }
    }

    double volume = (sum / (chunk.length / 2)) / 10000.0;
    volume = volume.clamp(0.0, 1.0);

    MusicNote? note;
    int realThreshold = 100 + (threshold * 50); 
    
    if (sum > realThreshold * (chunk.length / 50)) {
       int rawPitch = zeroCrossings % 7;
       String name = _getNoteName(rawPitch);
       note = MusicNote(name, rawPitch, NoteType.quarter, "");
    }

    return {
      "volume": volume,
      "note": note
    };
  }

  static String _getNoteName(int index) {
    switch (index) {
      case 0: return "C"; case 1: return "D"; case 2: return "E";
      case 3: return "F"; case 4: return "G"; case 5: return "A";
      case 6: return "B"; default: return "C";
    }
  }
}
