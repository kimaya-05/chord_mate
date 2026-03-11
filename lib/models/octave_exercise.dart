import 'dart:math';

enum ExerciseMode {
  stringLocked,
  positionLocked,
  fullRange,
  targetNote,
}

enum StringPair {
  eAndD,
  aAndG,
  dAndB,
  gAndHighE,
  mixed // For non-standard or generic
}

/// Represents a single note in a scale with both lower and upper octave variants
class ScaleNote {
  final String noteName; // e.g., "E", "F#", "G"
  final String targetLow;  // e.g., "E2"
  final String targetHigh; // e.g., "E3"

  const ScaleNote({
    required this.noteName,
    required this.targetLow,
    required this.targetHigh,
  });

  /// Returns the note with its octave based on the current traversal direction.
  /// [highOctave] should come from [TraversalSequence.isHighOctave].
  /// - Ascending (low→high): use targetLow
  /// - Descending (high→low): use targetHigh
  String noteWithOctave({bool highOctave = false}) =>
      highOctave ? targetHigh : targetLow;
}

/// Manages traversal of a diatonic major scale (forward and backward)
class TraversalSequence {
  final List<ScaleNote> _notes;
  int _currentIndex = 0;
  bool _ascending = true;

  TraversalSequence({required List<ScaleNote> notes}) : _notes = List.from(notes);

  ScaleNote get current => _notes[_currentIndex];
  int get currentIndex => _currentIndex;
  bool get isAscending => _ascending;
  int get length => _notes.length;

  /// Whether the sequence is currently in the high-octave (descending) phase.
  /// Use this to pass into [ScaleNote.noteWithOctave] so pitch detection
  /// targets the correct octave for the player's position on the neck.
  ///
  /// - Ascending pass (low→high): player is on the lower-octave string → false
  /// - Descending pass (high→low): player is on the higher-octave string → true
  bool get isHighOctave => !_ascending;

  /// Advances to the next note in the traversal.
  /// Returns true if a lap boundary is crossed.
  bool advanceNote() {
    if (_ascending) {
      if (_currentIndex < _notes.length - 1) {
        _currentIndex++;
        return false;
      } else {
        // Reached the top — start descending into the high-octave pass
        _ascending = false;
        _currentIndex--;
        return true; // Lap boundary crossed
      }
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
        return false;
      } else {
        // Reached the bottom — start ascending into the low-octave pass
        _ascending = true;
        _currentIndex++;
        return true; // Lap boundary crossed
      }
    }
  }

  /// Reset to beginning of traversal (low-octave ascending pass)
  void reset() {
    _currentIndex = 0;
    _ascending = true;
  }

  /// Get a human-readable position (e.g., "1/7 ascending")
  String getPositionString() {
    final direction = _ascending ? 'ascending' : 'descending';
    return '${_currentIndex + 1}/${_notes.length} $direction';
  }
}

class OctaveExercise {
  final String targetLow;
  final String targetHigh;
  final String noteName;
  final int fretLow;
  final int fretHigh;
  final StringPair stringPair;

  const OctaveExercise({
    required this.targetLow,
    required this.targetHigh,
    required this.noteName,
    required this.fretLow,
    required this.fretHigh,
    required this.stringPair,
  });

  String get description {
    switch (stringPair) {
      case StringPair.eAndD:
        return 'Low E & D strings';
      case StringPair.aAndG:
        return 'A & G strings';
      case StringPair.dAndB:
        return 'D & B strings';
      case StringPair.gAndHighE:
        return 'G & High E strings';
      case StringPair.mixed:
        return 'Mixed strings';
    }
  }

  /// Generates a 7-note diatonic major scale traversal sequence
  /// between the target low and target high notes
  TraversalSequence generateDiatonicMajorScale() {
    final rootNote = _parseNoteName(targetLow);
    final octaveLow = _parseOctave(targetLow);
    final octaveHigh = _parseOctave(targetHigh);

    // Diatonic major scale intervals (semitones from root)
    const majorScaleIntervals = [0, 2, 4, 5, 7, 9, 11]; // W W H W W W H

    final notes = <ScaleNote>[];
    for (int i = 0; i < majorScaleIntervals.length; i++) {
      final semitoneOffset = majorScaleIntervals[i];
      final noteNameResult = _transposeNote(rootNote, semitoneOffset);

      final lowOctave = (semitoneOffset <= 0) ? octaveLow : octaveLow + (semitoneOffset ~/ 12);
      final highOctave = (semitoneOffset <= 0) ? octaveHigh : octaveHigh + (semitoneOffset ~/ 12);

      notes.add(ScaleNote(
        noteName: noteNameResult,
        targetLow: '$noteNameResult$lowOctave',
        targetHigh: '$noteNameResult$highOctave',
      ));
    }

    return TraversalSequence(notes: notes);
  }

  static int _parseOctave(String noteString) {
    final match = RegExp(r'(\d+)$').firstMatch(noteString);
    if (match != null) return int.parse(match.group(1)!);
    return 4;
  }

  static String _parseNoteName(String noteString) {
    final match = RegExp(r'^([A-G]#?)').firstMatch(noteString);
    if (match != null) return match.group(1)!;
    return 'C';
  }

  static String _transposeNote(String noteName, int semitones) {
    const noteSequence = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    int currentIndex = noteSequence.indexOf(noteName);
    if (currentIndex == -1) currentIndex = 0;
    int newIndex = (currentIndex + semitones) % 12;
    if (newIndex < 0) newIndex += 12;
    return noteSequence[newIndex];
  }
}

class StandardOctaves {
  static const List<OctaveExercise> eAndDStrings = [
    OctaveExercise(targetLow: 'E2', targetHigh: 'E3', noteName: 'E', fretLow: 0, fretHigh: 2, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'F2', targetHigh: 'F3', noteName: 'F', fretLow: 1, fretHigh: 3, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'F#2', targetHigh: 'F#3', noteName: 'F#', fretLow: 2, fretHigh: 4, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'G2', targetHigh: 'G3', noteName: 'G', fretLow: 3, fretHigh: 5, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'G#2', targetHigh: 'G#3', noteName: 'G#', fretLow: 4, fretHigh: 6, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'A2', targetHigh: 'A3', noteName: 'A', fretLow: 5, fretHigh: 7, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'A#2', targetHigh: 'A#3', noteName: 'A#', fretLow: 6, fretHigh: 8, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'B2', targetHigh: 'B3', noteName: 'B', fretLow: 7, fretHigh: 9, stringPair: StringPair.eAndD),
    OctaveExercise(targetLow: 'C3', targetHigh: 'C4', noteName: 'C', fretLow: 8, fretHigh: 10, stringPair: StringPair.eAndD),
  ];

  static const List<OctaveExercise> aAndGStrings = [
    OctaveExercise(targetLow: 'A2', targetHigh: 'A3', noteName: 'A', fretLow: 0, fretHigh: 2, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'A#2', targetHigh: 'A#3', noteName: 'A#', fretLow: 1, fretHigh: 3, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'B2', targetHigh: 'B3', noteName: 'B', fretLow: 2, fretHigh: 4, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'C3', targetHigh: 'C4', noteName: 'C', fretLow: 3, fretHigh: 5, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'C#3', targetHigh: 'C#4', noteName: 'C#', fretLow: 4, fretHigh: 6, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'D3', targetHigh: 'D4', noteName: 'D', fretLow: 5, fretHigh: 7, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'D#3', targetHigh: 'D#4', noteName: 'D#', fretLow: 6, fretHigh: 8, stringPair: StringPair.aAndG),
    OctaveExercise(targetLow: 'E3', targetHigh: 'E4', noteName: 'E', fretLow: 7, fretHigh: 9, stringPair: StringPair.aAndG),
  ];

  static const List<OctaveExercise> dAndBStrings = [
    OctaveExercise(targetLow: 'D3', targetHigh: 'D4', noteName: 'D', fretLow: 0, fretHigh: 3, stringPair: StringPair.dAndB),
    OctaveExercise(targetLow: 'D#3', targetHigh: 'D#4', noteName: 'D#', fretLow: 1, fretHigh: 4, stringPair: StringPair.dAndB),
    OctaveExercise(targetLow: 'E3', targetHigh: 'E4', noteName: 'E', fretLow: 2, fretHigh: 5, stringPair: StringPair.dAndB),
    OctaveExercise(targetLow: 'F3', targetHigh: 'F4', noteName: 'F', fretLow: 3, fretHigh: 6, stringPair: StringPair.dAndB),
    OctaveExercise(targetLow: 'F#3', targetHigh: 'F#4', noteName: 'F#', fretLow: 4, fretHigh: 7, stringPair: StringPair.dAndB),
    OctaveExercise(targetLow: 'G3', targetHigh: 'G4', noteName: 'G', fretLow: 5, fretHigh: 8, stringPair: StringPair.dAndB),
    OctaveExercise(targetLow: 'G#3', targetHigh: 'G#4', noteName: 'G#', fretLow: 6, fretHigh: 9, stringPair: StringPair.dAndB),
  ];

  static const List<OctaveExercise> gAndHighEStrings = [
    OctaveExercise(targetLow: 'G3', targetHigh: 'G4', noteName: 'G', fretLow: 0, fretHigh: 3, stringPair: StringPair.gAndHighE),
    OctaveExercise(targetLow: 'G#3', targetHigh: 'G#4', noteName: 'G#', fretLow: 1, fretHigh: 4, stringPair: StringPair.gAndHighE),
    OctaveExercise(targetLow: 'A3', targetHigh: 'A4', noteName: 'A', fretLow: 2, fretHigh: 5, stringPair: StringPair.gAndHighE),
    OctaveExercise(targetLow: 'A#3', targetHigh: 'A#4', noteName: 'A#', fretLow: 3, fretHigh: 6, stringPair: StringPair.gAndHighE),
    OctaveExercise(targetLow: 'B3', targetHigh: 'B4', noteName: 'B', fretLow: 4, fretHigh: 7, stringPair: StringPair.gAndHighE),
    OctaveExercise(targetLow: 'C4', targetHigh: 'C5', noteName: 'C', fretLow: 5, fretHigh: 8, stringPair: StringPair.gAndHighE),
  ];

  static List<OctaveExercise> getAll() {
    return [
      ...eAndDStrings,
      ...aAndGStrings,
      ...dAndBStrings,
      ...gAndHighEStrings,
    ];
  }

  static List<OctaveExercise> generateExerciseList(
    ExerciseMode mode, {
    String? targetNoteName,
    int positionStart = 0,
    int positionEnd = 5,
    StringPair? lockedStringPair,
  }) {
    List<OctaveExercise> all = getAll();
    List<OctaveExercise> filtered;

    switch (mode) {
      case ExerciseMode.stringLocked:
        lockedStringPair ??= StringPair.eAndD;
        filtered = all.where((e) => e.stringPair == lockedStringPair).toList();
        break;
      case ExerciseMode.positionLocked:
        filtered = all.where((e) => e.fretLow >= positionStart && e.fretLow <= positionEnd).toList();
        break;
      case ExerciseMode.targetNote:
        targetNoteName ??= 'A';
        filtered = all.where((e) => e.noteName == targetNoteName).toList();
        break;
      case ExerciseMode.fullRange:
        filtered = List.from(all);
        break;
    }

    filtered.shuffle(Random());
    return filtered;
  }
}