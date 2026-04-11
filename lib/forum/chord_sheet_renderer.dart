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

String transposeChord(String chord, int semitones) {
  if (chord.isEmpty) return chord;
  final match = RegExp(r'^([A-G]#?b?)(.*)$').firstMatch(chord);
  if (match == null) return chord;

  String root   = match.group(1)!;
  String suffix = match.group(2)!;

  const Map<String, String> flatToSharp = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
  };
  root = flatToSharp[root] ?? root;

  final int idx = _chromaticScale.indexOf(root);
  if (idx == -1) return chord;

  final int newIdx = ((idx + semitones) % 12 + 12) % 12;
  return '${_chromaticScale[newIdx]}$suffix';
}

String transposeContent(String content, int semitones) {
  if (semitones == 0) return content;
  return content.split('\n').map((line) {
    if (_isChordLine(line)) {
      return line.replaceAllMapped(
        RegExp(r'[A-G]#?b?(?:m|maj|min|dim|aug|sus|add|M)?(?:\d+)?(?:/[A-G]#?b?)?'),
        (m) => transposeChord(m.group(0)!, semitones),
      );
    }
    return line;
  }).join('\n');
}

bool _isChordLine(String line) {
  if (line.trim().isEmpty) return false;
  if (line.trim().startsWith('[')) return false;
  final tokens = line.trim().split(RegExp(r'\s+'));
  int chordCount = 0;
  for (final t in tokens) {
    if (_chordTokenRegex.hasMatch(t)) chordCount++;
  }
  return tokens.isNotEmpty && chordCount / tokens.length >= 0.5;
}

final _chordTokenRegex = RegExp(
  r'^[A-G]#?b?(?:m|maj|min|dim|aug|sus|add|M)?(?:\d+)?(?:/[A-G]#?b?)?$',
);

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

class ChordSheetRenderer extends StatelessWidget {
  final String content;
  final int    transposeSemitones;
  // Kept for API compatibility — diagrams are always on-demand via tap.
  final bool   showInlineDiagrams;

  const ChordSheetRenderer({
    super.key,
    required this.content,
    this.transposeSemitones = 0,
    this.showInlineDiagrams = true,
  });

  @override
  Widget build(BuildContext context) {
    final String transposed = transposeContent(content, transposeSemitones);
    final lines = _parseContent(transposed);

    final List<Widget> widgets = [];
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      if (line.type == _LineType.section) {
        widgets.add(_SectionHeader(text: line.raw.trim()));
        i++;
      } else if (line.type == _LineType.chord) {
        final String? lyricRaw =
            (i + 1 < lines.length && lines[i + 1].type == _LineType.lyric)
                ? lines[i + 1].raw
                : null;
        widgets.add(_ChordLyricRow(
          chordLine: line.raw,
          lyricLine: lyricRaw,
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

  String get _label {
    final t = text.trim();
    if (t.startsWith('[') && t.endsWith(']')) {
      return t.substring(1, t.length - 1).toUpperCase();
    }
    return t.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.greenAccent,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChordLyricRow
// ─────────────────────────────────────────────────────────────────────────────

class _ChordLyricRow extends StatelessWidget {
  final String  chordLine;
  final String? lyricLine;

  const _ChordLyricRow({
    required this.chordLine,
    required this.lyricLine,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChordChipsRow(chordLine: chordLine),
          if (lyricLine != null) ...[
            const SizedBox(height: 1),
            _LyricLine(text: lyricLine!),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChordChipsRow
// Walks the chord line and emits a chip for every chord token and a
// proportional SizedBox for every whitespace run, preserving horizontal
// alignment with the lyric line underneath.
// ─────────────────────────────────────────────────────────────────────────────

class _ChordChipsRow extends StatelessWidget {
  final String chordLine;

  // Must match the monospace fontSize used in _LyricLine so spacing aligns.
  static const double _charWidth = 8.41; // monospace 14px ≈ 8.41px/char

  const _ChordChipsRow({required this.chordLine});

  @override
  Widget build(BuildContext context) {
    final segments = _tokenise(chordLine);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: segments.map((seg) {
        if (seg.isChord) {
          return _ChordChip(
            label: seg.text,
            onTap: () => _showChordBottomSheet(context, seg.text),
          );
        }
        return SizedBox(width: seg.text.length * _charWidth);
      }).toList(),
    );
  }

  List<({bool isChord, String text})> _tokenise(String line) {
    final result = <({bool isChord, String text})>[];
    final re = RegExp(
      r'([A-G]#?b?(?:m|maj|min|dim|aug|sus|add|M)?(?:\d+)?(?:/[A-G]#?b?)?)|(\s+)',
    );
    int cursor = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > cursor) {
        result.add((isChord: false, text: line.substring(cursor, m.start)));
      }
      if (m.group(1) != null) {
        result.add((isChord: true, text: m.group(1)!));
      } else if (m.group(2) != null) {
        result.add((isChord: false, text: m.group(2)!));
      }
      cursor = m.end;
    }
    if (cursor < line.length) {
      result.add((isChord: false, text: line.substring(cursor)));
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showChordBottomSheet(BuildContext context, String token) {
  PracticeChord? pc;
  try {
    pc = practiceChords.firstWhere(
      (c) => c.displayName.toLowerCase() == token.toLowerCase(),
    );
  } catch (_) {}

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF13131A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => pc != null
        ? _ChordDiagramSheet(chord: pc!)
        : _NoChordSheet(token: token),
  );
}

// ── Full sheet with diagram + voicing switcher ────────────────────────────────

class _ChordDiagramSheet extends StatefulWidget {
  final PracticeChord chord;
  const _ChordDiagramSheet({required this.chord});

  @override
  State<_ChordDiagramSheet> createState() => _ChordDiagramSheetState();
}

class _ChordDiagramSheetState extends State<_ChordDiagramSheet> {
  int _voicingIndex = 0;

  @override
  Widget build(BuildContext context) {
    final voicings = widget.chord.voicings;
    final current  = voicings[_voicingIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Chord name
          Text(
            widget.chord.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current.label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),

          // Diagram
          ChordDiagramWidget(
            chord:    current.data,
            size:     ChordDiagramSize.large,
            showName: false,
          ),

          // Voicing switcher — only shown when multiple voicings exist
          if (voicings.length > 1) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _VoicingNavButton(
                  icon:    Icons.chevron_left_rounded,
                  enabled: _voicingIndex > 0,
                  onTap:   () => setState(() => _voicingIndex--),
                ),
                const SizedBox(width: 16),
                Text(
                  '${_voicingIndex + 1} / ${voicings.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                _VoicingNavButton(
                  icon:    Icons.chevron_right_rounded,
                  enabled: _voicingIndex < voicings.length - 1,
                  onTap:   () => setState(() => _voicingIndex++),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Voicings',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.25),
                letterSpacing: 0.8,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Practice button
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChordDetailPage(chord: widget.chord),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Practice this chord',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.greenAccent,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.greenAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fallback — no diagram available ──────────────────────────────────────────

class _NoChordSheet extends StatelessWidget {
  final String token;
  const _NoChordSheet({required this.token});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            token,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No diagram available for this chord yet.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _VoicingNavButton extends StatelessWidget {
  final IconData     icon;
  final bool         enabled;
  final VoidCallback onTap;
  const _VoicingNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }
}

class _ChordChip extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _ChordChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.greenAccent,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  final String text;
  const _LyricLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withOpacity(0.85),
        fontFamily: 'monospace',
        height: 1.4,
      ),
    );
  }
}