import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A single beat's worth of note detection data.
class NoteLogEntry {
  final DateTime timestamp;
  final int setNumber;
  final int lapNumber;
  final int beatNumber;
  final String expectedNote;   // e.g. "E2"
  final String detectedNote;   // e.g. "E3" or "—"
  final double detectedHz;
  final double expectedHz;
  final double centsOff;       // positive = sharp, negative = flat
  final bool wasHit;

  NoteLogEntry({
    required this.timestamp,
    required this.setNumber,
    required this.lapNumber,
    required this.beatNumber,
    required this.expectedNote,
    required this.detectedNote,
    required this.detectedHz,
    required this.expectedHz,
    required this.centsOff,
    required this.wasHit,
  });

  /// Tab-separated row for CSV export.
  String toCsvRow() {
    return [
      timestamp.toIso8601String(),
      setNumber,
      lapNumber,
      beatNumber,
      expectedNote,
      detectedNote,
      detectedHz.toStringAsFixed(2),
      expectedHz.toStringAsFixed(2),
      centsOff.toStringAsFixed(1),
      wasHit ? 'HIT' : 'MISS',
    ].join('\t');
  }

  @override
  String toString() {
    final arrow = wasHit ? '✓' : '✗';
    final centsStr = centsOff == 0
        ? '0 ¢'
        : '${centsOff > 0 ? '+' : ''}${centsOff.toStringAsFixed(1)} ¢';
    return '$arrow  S$setNumber·L$lapNumber·B${beatNumber.toString().padLeft(3)}  '
        'expected=$expectedNote (${expectedHz.toStringAsFixed(1)} Hz)  '
        'detected=$detectedNote (${detectedHz.toStringAsFixed(1)} Hz)  '
        '$centsStr';
  }
}

/// Accumulates per-beat note detection logs for a session and can export them.
class NoteDebugLogger {
  final List<NoteLogEntry> _entries = [];
  bool _enabled;

  NoteDebugLogger({bool enabled = true}) : _enabled = enabled;

  bool get enabled => _enabled;
  set enabled(bool v) => _enabled = v;

  List<NoteLogEntry> get entries => List.unmodifiable(_entries);

  // ── Logging ──────────────────────────────────────────────────────────────

  void log({
    required int set,
    required int lap,
    required int beat,
    required String expectedNote,
    required double expectedHz,
    required double detectedHz,
    required bool wasHit,
  }) {
    if (!_enabled) return;

    final detectedNote = detectedHz > 0
        ? _frequencyToNoteName(detectedHz)
        : '—';

    final centsOff = (detectedHz > 0 && expectedHz > 0)
        ? 1200.0 * (math.log(detectedHz / expectedHz) / _ln2)
        : 0.0;

    final entry = NoteLogEntry(
      timestamp: DateTime.now(),
      setNumber: set,
      lapNumber: lap,
      beatNumber: beat,
      expectedNote: expectedNote,
      detectedNote: detectedNote,
      detectedHz: detectedHz,
      expectedHz: expectedHz,
      centsOff: centsOff,
      wasHit: wasHit,
    );

    _entries.add(entry);

    debugPrint('[NoteLog] ${entry.toString()}');
  }

  void clear() => _entries.clear();

  // ── Analysis helpers ─────────────────────────────────────────────────────

  /// Returns entries where the note name matched but the octave was wrong.
  List<NoteLogEntry> get octaveErrors {
    return _entries.where((e) {
      if (e.detectedNote == '—') return false;
      // Strip octave digit to compare just the pitch class.
      final expClass = e.expectedNote.replaceAll(RegExp(r'\d'), '');
      final detClass = e.detectedNote.replaceAll(RegExp(r'\d'), '');
      return expClass == detClass && e.expectedNote != e.detectedNote;
    }).toList();
  }

  /// Returns entries where a completely wrong note was detected.
  List<NoteLogEntry> get wrongNoteErrors {
    return _entries.where((e) {
      if (e.detectedNote == '—') return false;
      final expClass = e.expectedNote.replaceAll(RegExp(r'\d'), '');
      final detClass = e.detectedNote.replaceAll(RegExp(r'\d'), '');
      return expClass != detClass;
    }).toList();
  }

  /// Returns entries where nothing was detected (silence / below threshold).
  List<NoteLogEntry> get silentBeats {
    return _entries.where((e) => e.detectedNote == '—').toList();
  }

  /// Quick summary string — useful to print at session end.
  String summary() {
    if (_entries.isEmpty) return 'No entries logged.';
    final total = _entries.length;
    final hits = _entries.where((e) => e.wasHit).length;
    final octave = octaveErrors.length;
    final wrong = wrongNoteErrors.length;
    final silent = silentBeats.length;
    final hitPct = (hits / total * 100).toStringAsFixed(1);

    final sb = StringBuffer();
    sb.writeln('══════════ Session Debug Summary ══════════');
    sb.writeln('Total beats   : $total');
    sb.writeln('Hits          : $hits ($hitPct%)');
    sb.writeln('Octave errors : $octave  ← HPS octave confusion');
    sb.writeln('Wrong notes   : $wrong');
    sb.writeln('Silent beats  : $silent  ← nothing detected');
    sb.writeln('');

    if (octave > 0) {
      sb.writeln('── Octave error detail ──');
      final counts = <String, int>{};
      for (final e in octaveErrors) {
        final key = '${e.expectedNote} → ${e.detectedNote}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      counts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..forEach((kv) => sb.writeln('  ${kv.key}  ×${kv.value}'));
    }

    sb.writeln('═══════════════════════════════════════════');
    return sb.toString();
  }

  // ── Export ───────────────────────────────────────────────────────────────

  /// Saves the log as a TSV file in the app's documents directory.
  /// Returns the file path, or null on failure.
  Future<String?> exportTsv({String? filename}) async {
    if (_entries.isEmpty) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = filename ??
          'note_log_${DateTime.now().millisecondsSinceEpoch}.tsv';
      final file = File('${dir.path}/$name');

      final header =
          'timestamp\tset\tlap\tbeat\texpected\tdetected\tdetected_hz\texpected_hz\tcents_off\tresult';
      final rows = _entries.map((e) => e.toCsvRow()).join('\n');
      await file.writeAsString('$header\n$rows\n');

      debugPrint('[NoteLog] Exported ${_entries.length} entries → ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[NoteLog] Export failed: $e');
      return null;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static const double _ln2 = 0.693147180559945;
  static const double _a4 = 440.0;
  static const int _a4Midi = 69;
  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static String _frequencyToNoteName(double freq) {
    if (freq <= 0) return '—';
    final semitones = 12.0 * (math.log(freq / _a4) / _ln2);
    final midi = (_a4Midi + semitones).round();
    final noteIndex = ((midi % 12) + 12) % 12;
    final octave = (midi ~/ 12) - 1;
    return '${_noteNames[noteIndex]}$octave';
  }
}