import 'package:flutter/material.dart';
import '../chords/chord_voicings.dart';
import '../chords/chord_detail_page.dart';
import '../chords/chord_diagram_widget.dart';
import '../chords/chord_library.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transposition helper
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _chromaticScale = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

/// Transposes a single chord name by [semitones] steps.
/// Handles major, minor, 7th, sus etc. by splitting root from suffix.
String transposeChord(String chord, int semitones) {
  if (chord.isEmpty) return chord;
  // Match root note (e.g. C, C#, Db)
  final match = RegExp(r'^([A-G]#?b?)(.*)$').firstMatch(chord);
  if (match == null) return chord;

  String root   = match.group(1)!;
  String suffix = match.group(2)!;

  // Normalise flats to sharps
  const Map<String, String> flatToSharp = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
  };
  root = flatToSharp[root] ?? root;

  final int idx = _chromaticScale.indexOf(root);
  if (idx == -1) return chord;

  final int newIdx = ((idx + semitones) % 12 + 12) % 12;
  return '${_chromaticScale[newIdx]}$suffix';
}

/// Transposes every chord token in a full chord sheet content string.
String transposeContent(String content, int semitones) {
  if (semitones == 0) return content;
  final lines = content.split('\n');
  return lines.map((line) {
    if (_isChordLine(line)) {
      // Replace each chord token on the line
      return line.replaceAllMapped(
        RegExp(r'[A-G]#?b?(?:m|maj|min|dim|aug|sus|add|M)?(?:\d+)?(?:/[A-G]#?b?)?'),
        (m) => transposeChord(m.group(0)!, semitones),
      );
    }
    return line;
  }).join('\n');
}

/// A line is a chord line if it contains chord-like tokens and no long words.
bool _isChordLine(String line) {
  if (line.trim().isEmpty) return false;
  if (line.trim().startsWith('[')) return false; // section header
  final tokens = line.trim().split(RegExp(r'\s+'));
  int chordCount = 0;
  for (final t in tokens) {
    if (RegExp(r'^[A-G]#?b?(?:m|maj|min|dim|aug|sus|add|M)?(?:\d+)?(?:/[A-G]#?b?)?$')
        .hasMatch(t)) {
      chordCount++;
    }
  }
  // If more than half the tokens look like chords, treat as chord line
  return tokens.isNotEmpty && chordCount / tokens.length >= 0.5;
}

// ─────────────────────────────────────────────────────────────────────────────
// Line types
// ─────────────────────────────────────────────────────────────────────────────

enum _LineType { section, chord, lyric, blank }

class _ParsedLine {
  final _LineType type;
  final String    raw;
  const _ParsedLine(this.type, this.raw);
}

List<_ParsedLine> _parseContent(String content) {
  return content.split('\n').map((line) {
    if (line.trim().isEmpty) return _ParsedLine(_LineType.blank, line);
    if (line.trim().startsWith('[') && line.trim().endsWith(']')) {
      return _ParsedLine(_LineType.section, line);
    }
    if (_isChordLine(line)) return _ParsedLine(_LineType.chord, line);
    return _ParsedLine(_LineType.lyric, line);
  }).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// ChordSheetRenderer
// ─────────────────────────────────────────────────────────────────────────────

class ChordSheetRenderer extends StatelessWidget {
  final String content;
  final int    transposeSemitones;
  final bool   showInlineDiagrams;

  const ChordSheetRenderer({
    super.key,
    required this.content,
    this.transposeSemitones = 0,
    this.showInlineDiagrams = true,
  });

  @override
  Widget build(BuildContext context) {
    final String transposed =
        transposeContent(content, transposeSemitones);
    final lines = _parseContent(transposed);

    // Group chord + lyric pairs
    final List<Widget> widgets = [];
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      if (line.type == _LineType.section) {
        widgets.add(_SectionHeader(text: line.raw.trim()));
        i++;
      } else if (line.type == _LineType.chord) {
        // Check if next line is a lyric to pair them
        final String? lyricRaw =
            (i + 1 < lines.length && lines[i + 1].type == _LineType.lyric)
                ? lines[i + 1].raw
                : null;
        widgets.add(_ChordLyricRow(
          chordLine:          line.raw,
          lyricLine:          lyricRaw,
          showInlineDiagrams: showInlineDiagrams,
        ));
        i += lyricRaw != null ? 2 : 1;
      } else if (line.type == _LineType.lyric) {
        widgets.add(_LyricLine(text: line.raw));
        i++;
      } else {
        widgets.add(const SizedBox(height: 8));
        i++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.greenAccent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChordLyricRow — chord tokens above the lyric line
// ─────────────────────────────────────────────────────────────────────────────

class _ChordLyricRow extends StatelessWidget {
  final String  chordLine;
  final String? lyricLine;
  final bool    showInlineDiagrams;

  const _ChordLyricRow({
    required this.chordLine,
    required this.lyricLine,
    required this.showInlineDiagrams,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chord line
          Text(
            chordLine,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
          // Lyric line (if any)
          if (lyricLine != null)
            Text(
              lyricLine!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          // Inline chord diagrams
          if (showInlineDiagrams) _buildInlineDiagrams(context),
        ],
      ),
    );
  }

  Widget _buildInlineDiagrams(BuildContext context) {
    // Extract unique chord tokens from the chord line
    final tokens = chordLine
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) =>
            RegExp(r'^[A-G]#?b?(?:m|maj|min|dim|aug|sus|add|M)?(?:\d+)?(?:/[A-G]#?b?)?$')
                .hasMatch(t))
        .toSet()
        .toList();

    if (tokens.isEmpty) return const SizedBox.shrink();

    // Find matching PracticeChord or ChordData for each token
    final List<Widget> diagrams = [];
    for (final token in tokens) {
      // Try to find in practiceChords first
      PracticeChord? pc;
      try {
        pc = practiceChords.firstWhere(
          (c) => c.displayName.toLowerCase() == token.toLowerCase(),
        );
      } catch (_) {}

      if (pc != null) {
        diagrams.add(
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChordDetailPage(chord: pc!),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  ChordDiagramWidget(
                    chord:    pc.voicings.first.data,
                    size:     ChordDiagramSize.small,
                    showName: true,
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // Just show the chord name as a badge if no diagram available
        diagrams.add(
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: Colors.greenAccent.withOpacity(0.2)),
            ),
            child: Text(
              token,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }

    if (diagrams.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: diagrams),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LyricLine
// ─────────────────────────────────────────────────────────────────────────────

class _LyricLine extends StatelessWidget {
  final String text;
  const _LyricLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white.withOpacity(0.85),
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }
}