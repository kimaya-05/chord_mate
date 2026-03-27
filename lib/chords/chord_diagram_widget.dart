import 'package:flutter/material.dart';
import 'chord_library.dart';

enum ChordDiagramSize { small, medium, large }

class ChordDiagramWidget extends StatelessWidget {
  final ChordData chord;
  final ChordDiagramSize size;
  final bool showName;
  final bool showBeginner;

  const ChordDiagramWidget({
    super.key,
    required this.chord,
    this.size = ChordDiagramSize.medium,
    this.showName = true,
    this.showBeginner = false,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _DiagramConfig.forSize(size);
    final fingerings = showBeginner && chord.beginnerFingerings != null
      ? chord.beginnerFingerings!
      : chord.fingerings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showName) ...[
          Text(
            chord.displayName,
            style: TextStyle(
              fontSize: cfg.nameFontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: cfg.nameGap),
        ],
        CustomPaint(
          size: Size(cfg.totalWidth, cfg.totalHeight),
          painter: _DiagramPainter(
        chord: chord,
        cfg: cfg,
        fingerings: fingerings,  
      ),
        ),
      ],
    );
  }
}

class _DiagramConfig {
  final double cellW;
  final double cellH;
  final double dotR;
  final double nutW;
  final double stringW;
  final double fretW;
  final double sidePad;
  final double topPad;
  final double nameFontSize;
  final double nameGap;
  final double labelFontSize;
  final double baseFretFontSize;
  final List<StringFingering> fingerings;

  static const int numStrings = 6;
  static const int numFrets = 4;

  double get totalWidth => sidePad * 2 + cellW * (numStrings - 1);
  double get totalHeight => topPad + cellH * numFrets;

  const _DiagramConfig({
    required this.cellW,
    required this.cellH,
    required this.dotR,
    required this.nutW,
    required this.stringW,
    required this.fretW,
    required this.sidePad,
    required this.topPad,
    required this.nameFontSize,
    required this.nameGap,
    required this.labelFontSize,
    required this.baseFretFontSize,
      this.fingerings = const [],
  });

  factory _DiagramConfig.forSize(ChordDiagramSize s) {
    switch (s) {
      case ChordDiagramSize.small:
        return const _DiagramConfig(
          cellW: 18, cellH: 18, dotR: 6, nutW: 3,
          stringW: 1, fretW: 1, sidePad: 12, topPad: 16,
          nameFontSize: 16, nameGap: 4, labelFontSize: 7,
          baseFretFontSize: 8,
        );
      case ChordDiagramSize.medium:
        return const _DiagramConfig(
          cellW: 26, cellH: 26, dotR: 9, nutW: 4,
          stringW: 1.5, fretW: 1.5, sidePad: 16, topPad: 22,
          nameFontSize: 22, nameGap: 6, labelFontSize: 10,
          baseFretFontSize: 10,
        );
      case ChordDiagramSize.large:
        return const _DiagramConfig(
          cellW: 38, cellH: 38, dotR: 13, nutW: 5,
          stringW: 2, fretW: 2, sidePad: 22, topPad: 32,
          nameFontSize: 30, nameGap: 8, labelFontSize: 13,
          baseFretFontSize: 13,
        );
    }
  }

  // StringFingering.string is 1-based: 1=high e (right), 6=low E (left)
  // Column 0 = low E, column 5 = high e  →  col = 6 - fp.string
  double stringX(int col) => sidePad + col * cellW;
  double fretY(int f) => topPad + f * cellH;
}

class _DiagramPainter extends CustomPainter {
  final ChordData chord;
  final _DiagramConfig cfg;
  final List<StringFingering> fingerings;

  _DiagramPainter({required this.chord, required this.cfg, required this.fingerings});

  static const Color _nutColor      = Color(0xFFD4C9A8);
  static const Color _fretColor     = Color(0xFF4A4A5A);
  static const Color _stringColor   = Color(0xFF6A6A7A);
  static const Color _dotColor      = Color(0xFF4FC3F7);
  static const Color _openColor     = Color(0xFF4FC3F7);
  static const Color _muteColor     = Color(0xFFEF5350);
  static const Color _labelColor    = Colors.white;
  static const Color _baseFretColor = Color(0xFFAAAAAA);

  @override
  void paint(Canvas canvas, Size size) {
    _drawFrets(canvas);
    _drawStrings(canvas);
    _drawNut(canvas);
    _drawOpenMuteMarkers(canvas);
    _drawFingerDots(canvas);
    if (chord.startFret > 1) _drawBaseFret(canvas); // ← was chord.baseFret
  }

  void _drawFrets(Canvas canvas) {
    final p = Paint()
      ..color = _fretColor
      ..strokeWidth = cfg.fretW
      ..style = PaintingStyle.stroke;
    for (int f = 0; f <= _DiagramConfig.numFrets; f++) {
      final y = cfg.fretY(f);
      canvas.drawLine(
        Offset(cfg.sidePad, y),
        Offset(cfg.sidePad + cfg.cellW * (_DiagramConfig.numStrings - 1), y),
        p,
      );
    }
  }

  void _drawStrings(Canvas canvas) {
    final p = Paint()
      ..color = _stringColor
      ..strokeWidth = cfg.stringW
      ..style = PaintingStyle.stroke;
    for (int s = 0; s < _DiagramConfig.numStrings; s++) {
      final x = cfg.stringX(s);
      canvas.drawLine(
        Offset(x, cfg.fretY(0)),
        Offset(x, cfg.fretY(_DiagramConfig.numFrets)),
        p,
      );
    }
  }

  void _drawNut(Canvas canvas) {
    if (chord.startFret > 1) return; // ← was chord.baseFret
    final p = Paint()
      ..color = _nutColor
      ..strokeWidth = cfg.nutW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cfg.sidePad, cfg.fretY(0)),
      Offset(cfg.sidePad + cfg.cellW * (_DiagramConfig.numStrings - 1),
          cfg.fretY(0)),
      p,
    );
  }

  void _drawOpenMuteMarkers(Canvas canvas) {
    // Was: chord.frets[i] — now we iterate chord.fingerings (List<StringFingering>)
    for (final fp in fingerings) {
      // col = 6 - fp.string so that string 6 (low E) → col 0 (leftmost)
      final col = _DiagramConfig.numStrings - fp.string;
      final x   = cfg.stringX(col);
      final y   = cfg.fretY(0) - cfg.topPad / 2;

      if (fp.fret == -1) {
        _drawX(canvas, x, y, cfg.dotR * 0.6, _muteColor);
      } else if (fp.fret == 0) {
        canvas.drawCircle(
          Offset(x, y),
          cfg.dotR * 0.6,
          Paint()
            ..color = _openColor
            ..strokeWidth = cfg.stringW + 0.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _drawX(Canvas canvas, double cx, double cy, double r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = cfg.stringW + 0.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), p);
    canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), p);
  }

  void _drawFingerDots(Canvas canvas) {
    final dotPaint = Paint()
      ..color = _dotColor
      ..style = PaintingStyle.fill;

    // Detect barre: two or more fingerings share the same fret with finger == 1
    final barreGroups = <int, List<StringFingering>>{};
    for (final fp in fingerings) {
      if (fp.finger == 1 && fp.fret > 0) {
        barreGroups.putIfAbsent(fp.fret, () => []).add(fp);
      }
    }

    // Draw barre bars first (behind individual dots)
    for (final entry in barreGroups.entries) {
      if (entry.value.length < 2) continue;
      final relativeFret = entry.key - chord.startFret + 1; // ← was chord.baseFret
      if (relativeFret < 1 || relativeFret > _DiagramConfig.numFrets) continue;

      final y    = cfg.fretY(relativeFret) - cfg.cellH / 2;
      final cols = entry.value
          .map((fp) => _DiagramConfig.numStrings - fp.string)
          .toList()..sort();
      final x1 = cfg.stringX(cols.first);
      final x2 = cfg.stringX(cols.last);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
              x1 - cfg.dotR, y - cfg.dotR, x2 + cfg.dotR, y + cfg.dotR),
          Radius.circular(cfg.dotR),
        ),
        dotPaint,
      );
    }

    // Draw individual dots
    // Was: for (final fp in chord.fingers) — now chord.fingerings
    for (final fp in fingerings) {
      if (fp.fret <= 0) continue; // open/muted handled above

      final relativeFret = fp.fret - chord.startFret + 1; // ← was chord.baseFret
      if (relativeFret < 1 || relativeFret > _DiagramConfig.numFrets) continue;

      // Was: final stringIdx = fp.string - 1  (wrong for our left=low E layout)
      final col = _DiagramConfig.numStrings - fp.string;
      final x   = cfg.stringX(col);
      final y   = cfg.fretY(relativeFret) - cfg.cellH / 2;

      // Skip individual dot if it's part of a barre bar
      final isPartOfBarre = (barreGroups[fp.fret]?.length ?? 0) >= 2;
      if (!isPartOfBarre) {
        canvas.drawCircle(Offset(x, y), cfg.dotR, dotPaint);
      }

      if (fp.finger > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${fp.finger}',
            style: TextStyle(
              color: _labelColor,
              fontSize: cfg.labelFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  }

  void _drawBaseFret(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: '${chord.startFret}fr', // ← was chord.baseFret
        style: TextStyle(
          color: _baseFretColor,
          fontSize: cfg.baseFretFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        cfg.sidePad + cfg.cellW * (_DiagramConfig.numStrings - 1) + 4,
        cfg.fretY(1) - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter old) =>
      old.chord != chord || old.cfg != cfg || old.fingerings != fingerings;
}