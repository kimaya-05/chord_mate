import 'package:flutter/material.dart';
import '../models/octave_exercise.dart';

class FretboardWidget extends StatelessWidget {
  final OctaveExercise currentExercise;

  const FretboardWidget({super.key, required this.currentExercise});

  int _getStringIndex(StringPair pair, bool isLowTarget) {
    if (isLowTarget) {
      switch (pair) {
        case StringPair.eAndD: return 5; // Low E (index 5)
        case StringPair.aAndG: return 4; // A
        case StringPair.dAndB: return 3; // D
        case StringPair.gAndHighE: return 2; // G
        case StringPair.mixed: return -1;
      }
    } else {
      switch (pair) {
        case StringPair.eAndD: return 3; // D
        case StringPair.aAndG: return 2; // G
        case StringPair.dAndB: return 1; // B
        case StringPair.gAndHighE: return 0; // High E
        case StringPair.mixed: return -1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int lowString = _getStringIndex(currentExercise.stringPair, true);
    int highString = _getStringIndex(currentExercise.stringPair, false);
    
    // We will show 5 frets around the target note's frets
    int startFret = (currentExercise.fretLow > 0) ? currentExercise.fretLow - 1 : 0;
    int endFret = startFret + 4; // Show exactly 5 frets

    return Column(
      children: [
        Text(
          currentExercise.description,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
           height: 120,
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           decoration: BoxDecoration(
             color: Colors.brown[800],
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.brown[900]!, width: 2),
           ),
           child: CustomPaint(
              painter: _FretboardPainter(
                 lowString: lowString,
                 highString: highString,
                 lowFret: currentExercise.fretLow,
                 highFret: currentExercise.fretHigh,
                 startFret: startFret,
                 endFret: endFret,
              ),
              child: const SizedBox.expand(),
           ),
        ),
      ],
    );
  }
}

class _FretboardPainter extends CustomPainter {
  final int lowString;
  final int highString;
  final int lowFret;
  final int highFret;
  final int startFret;
  final int endFret;

  _FretboardPainter({
    required this.lowString,
    required this.highString,
    required this.lowFret,
    required this.highFret,
    required this.startFret,
    required this.endFret,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintString = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke;

    final paintFret = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    final paintNut = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final paintDot = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final int fretCount = endFret - startFret + 1;
    final double fretWidth = size.width / fretCount;
    final double stringSpacing = size.height / 5;

    // Draw strings (horizontal)
    for (int i = 0; i < 6; i++) {
      paintString.strokeWidth = 1.0 + (i * 0.5); // Thicker for lower strings
      double y = i * stringSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintString);
    }

    // Draw frets (vertical)
    for (int i = 0; i <= fretCount; i++) {
      double x = i * fretWidth;
      
      // If startFret is 0, the very first line is the nut
      if (startFret == 0 && i == 0) {
        canvas.drawLine(Offset(x + 2, 0), Offset(x + 2, size.height), paintNut);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintFret);
      }
    }

    // Draw dots (if lowString or highString are valid)
    if (lowString >= 0 && lowString < 6 && lowFret >= startFret && lowFret <= endFret) {
      // Calculate dot X (middle of fret)
      double centerFret = (lowFret == 0) ? fretWidth / 4 : ((lowFret - startFret) * fretWidth) - (fretWidth / 2);
      if (lowFret == 0) { // Nut case, put it right at 0
        centerFret = 8;
      }
      double y = lowString * stringSpacing;
      
      paintDot.color = Colors.redAccent;
      canvas.drawCircle(Offset(centerFret, y), 8, paintDot);
    }
    
    if (highString >= 0 && highString < 6 && highFret >= startFret && highFret <= endFret) {
      double centerFret = (highFret == 0) ? fretWidth / 4 : ((highFret - startFret) * fretWidth) - (fretWidth / 2);
      if (highFret == 0) { // Nut case
        centerFret = 8;
      }
      double y = highString * stringSpacing;
      
      paintDot.color = Colors.green;
      canvas.drawCircle(Offset(centerFret, y), 8, paintDot);
    }
    
    // Draw text indicators for frets
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < fretCount; i++) {
      int actualFret = startFret + i;
      if (actualFret > 0) {
        textPainter.text = TextSpan(
          text: actualFret.toString(),
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        );
        textPainter.layout();
        double x = (i * fretWidth) + (fretWidth / 2) - (textPainter.width / 2);
        // Draw text below string 6 (i.e. at bottom)
        textPainter.paint(canvas, Offset(x, size.height - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FretboardPainter oldDelegate) {
    return oldDelegate.lowFret != lowFret ||
           oldDelegate.highFret != highFret ||
           oldDelegate.lowString != lowString ||
           oldDelegate.highString != highString ||
           oldDelegate.startFret != startFret;
  }
}
