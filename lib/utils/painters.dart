import 'package:flutter/material.dart';
import 'audio_analyzer.dart';

// --- PAINTER 1: Vẽ Khuông Nhạc & Nốt Nhạc ---
class StaffPainter extends CustomPainter {
  final List<MusicNote> notes;
  final Duration playbackPosition;
  final bool isPlaying;

  StaffPainter(this.notes, this.playbackPosition, {this.isPlaying = false});

  static const double NOTE_SPACING = 60.0;
  static const double START_OFFSET = 50.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = Colors.white38..strokeWidth = 1.0;
    final paintNote = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final paintStem = Paint()..color = Colors.white..strokeWidth = 2;
    final paintPlayCursor = Paint()..color = Colors.redAccent..strokeWidth = 2;

    double centerY = size.height / 2;
    double lineSpacing = 12.0;
    double staffStartY = centerY - (2 * lineSpacing);

    // 1. Vẽ 5 dòng kẻ
    for (int i = 0; i < 5; i++) {
      double y = staffStartY + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintLine);
    }

    const TextSpan(text: "𝄞", style: TextStyle(color: Colors.white, fontSize: 50))
        .toPainter()..layout()..paint(canvas, Offset(10, staffStartY - 15));

    // 2. Vẽ Nốt nhạc
    for (int i = 0; i < notes.length; i++) {
      MusicNote note = notes[i];
      double x = START_OFFSET + (i * NOTE_SPACING);
      double noteY = staffStartY + (4 * lineSpacing) - (note.position * lineSpacing / 2);

      // Vẽ đầu nốt
      if (note.type == NoteType.whole) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, noteY), width: 16, height: 12), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, noteY), width: 16, height: 12), paintNote);
      }

      // Vẽ đuôi nốt
      if (note.type != NoteType.whole) {
        double stemHeight = 35.0;
        canvas.drawLine(Offset(x + 7, noteY), Offset(x + 7, noteY - stemHeight), paintStem);
        if (note.type == NoteType.eighth || note.type == NoteType.sixteenth) {
          _drawFlag(canvas, x + 7, noteY - stemHeight, 1);
        }
        if (note.type == NoteType.sixteenth) {
          _drawFlag(canvas, x + 7, noteY - stemHeight + 8, 2);
        }
      }

      // Vẽ dòng kẻ phụ cho nốt C
      if (note.name == "C" && (note.position % 7 == 0)) {
        canvas.drawLine(Offset(x - 12, noteY), Offset(x + 12, noteY), paintLine);
      }

      // Vẽ lời bài hát
      TextPainter(
          text: TextSpan(
              text: note.lyric.isEmpty ? "?" : note.lyric,
              style: TextStyle(
                  color: (isPlaying && _isNoteActive(note)) ? Colors.redAccent : Colors.cyanAccent,
                  fontWeight: FontWeight.bold, fontSize: 12
              )
          ),
          textDirection: TextDirection.ltr
      )..layout()..paint(canvas, Offset(x - 10, staffStartY + 5 * lineSpacing + 10));
    }

    // 3. Vẽ Thanh Playback
    if (isPlaying) {
      double cursorX = _calculateCursorX();
      canvas.drawLine(Offset(cursorX, 0), Offset(cursorX, size.height), paintPlayCursor);
    }
  }

  void _drawFlag(Canvas canvas, double x, double y, int index) {
    Path path = Path();
    path.moveTo(x, y);
    path.quadraticBezierTo(x + 10, y + 10, x, y + 20);
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  bool _isNoteActive(MusicNote note) {
    return playbackPosition >= note.startTime && playbackPosition < note.startTime + note.duration;
  }

  double _calculateCursorX() {
    for (int i = 0; i < notes.length; i++) {
      if (playbackPosition < notes[i].startTime) {
        double prevX = (i == 0) ? START_OFFSET : START_OFFSET + ((i - 1) * NOTE_SPACING);
        Duration prevTime = (i == 0) ? Duration.zero : notes[i-1].startTime;
        double progress = (playbackPosition - prevTime).inMilliseconds / (notes[i].startTime - prevTime).inMilliseconds;
        return prevX + (progress * NOTE_SPACING).clamp(0, NOTE_SPACING);
      }
    }
    return START_OFFSET + (notes.length * NOTE_SPACING);
  }

  @override
  bool shouldRepaint(covariant StaffPainter oldDelegate) => true;
}

// --- PAINTER 2: Vẽ Biểu đồ Pitch (Visualizer) ---
class PitchGraphPainter extends CustomPainter {
  final List<double> pitches;
  PitchGraphPainter(this.pitches);

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()
      ..shader = const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Paint glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..style = PaintingStyle.stroke;

    if (pitches.isEmpty) return;

    Path path = Path();
    double minFreq = 80;
    double maxFreq = 1000;
    double stepX = size.width / 100;

    for (int i = 0; i < pitches.length; i++) {
      double freq = pitches[i];
      double x = i * stepX;
      double y = size.height;
      if (freq > 0) {
        double normalizedY = 1.0 - ((freq - minFreq) / (maxFreq - minFreq)).clamp(0.0, 1.0);
        y = normalizedY * size.height;
      }

      if (i == 0) path.moveTo(x, y); else {
        double prevX = (i - 1) * stepX;
        path.quadraticBezierTo(prevX, y, x, y);
      }
    }
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension TextSpanExt on TextSpan { TextPainter toPainter() => TextPainter(text: this, textDirection: TextDirection.ltr); }