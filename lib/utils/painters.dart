import 'package:flutter/material.dart';
import 'audio_analyzer.dart';

class StaffPainter extends CustomPainter {
  final List<MusicNote> notes;
  StaffPainter(this.notes);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = Colors.black87..strokeWidth = 1.5;
    final paintNote = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final paintStem = Paint()..color = Colors.black..strokeWidth = 2;
    
    double startY = size.height / 2 - 40;
    double lineSpacing = 15.0;

    for (int i = 0; i < 5; i++) {
      double y = startY + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintLine);
    }
    
    const TextSpan(text: "𝄞", style: TextStyle(color: Colors.black, fontSize: 60))
        .toPainter()..layout()..paint(canvas, Offset(10, startY - 25));

    double currentX = 80.0;
    for (var note in notes) {
      double noteY = startY + (4 * lineSpacing);
      if (note.name == "C") noteY += lineSpacing;
      else if (note.name == "D") noteY += 0.5 * lineSpacing;
      else if (note.name == "E") noteY += 0;
      else if (note.name == "F") noteY -= 0.5 * lineSpacing;
      else if (note.name == "G") noteY -= 1 * lineSpacing;
      else if (note.name == "A") noteY -= 1.5 * lineSpacing;
      else if (note.name == "B") noteY -= 2 * lineSpacing;

      canvas.drawOval(Rect.fromCenter(center: Offset(currentX, noteY), width: 14, height: 10), paintNote);
      canvas.drawLine(Offset(currentX + 6, noteY), Offset(currentX + 6, noteY - 35), paintStem);
      
      if (note.name == "C") canvas.drawLine(Offset(currentX - 12, noteY), Offset(currentX + 12, noteY), paintLine);
      
      TextPainter(text: TextSpan(text: note.lyric, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)
        ..layout()..paint(canvas, Offset(currentX - 10, startY + 5 * lineSpacing + 5));

      currentX += 50.0;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
extension TextSpanExt on TextSpan { TextPainter toPainter() => TextPainter(text: this, textDirection: TextDirection.ltr); }
