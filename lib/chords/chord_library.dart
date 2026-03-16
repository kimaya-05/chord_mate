// ─────────────────────────────────────────────────────────────────────────────
// chord_data.dart
// All 24 chords (12 major + 12 minor) with fret diagrams and tips.
// ─────────────────────────────────────────────────────────────────────────────

/// Finger placement on a single string.
/// [string] 1=high e, 6=low E
/// [fret]   0=open, -1=muted/not played
/// [finger] 1=index … 4=pinky, 0=open, -1=muted
class StringFingering {
  final int string; // 1–6
  final int fret;   // 0=open, -1=muted
  final int finger; // 0=open, 1-4=finger number, -1=muted

  const StringFingering(this.string, this.fret, this.finger);
}

/// Full chord diagram data.
class ChordData {
  final String name;          // e.g. "A minor"
  final String displayName;   // e.g. "Am"
  final String fullName;      // e.g. "A Minor"
  final bool isMinor;
  final int startFret;        // lowest fret shown (usually 1, higher for barre)
  final List<StringFingering> fingerings; // one entry per string
  final List<String> tips;
  final String mlLabel;       // must match simplifyChordName output exactly

  const ChordData({
    required this.name,
    required this.displayName,
    required this.fullName,
    required this.isMinor,
    required this.startFret,
    required this.fingerings,
    required this.tips,
    required this.mlLabel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// All 24 chords
// Fingerings are for standard open/first-position where possible.
// Barre chords use startFret > 1.
// ─────────────────────────────────────────────────────────────────────────────

const List<ChordData> allChords = [
  // ── MAJOR CHORDS ──────────────────────────────────────────────────────────

  ChordData(
    name: 'C',
    displayName: 'C',
    fullName: 'C Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'C',
    fingerings: [
      StringFingering(6, -1, -1), // low E muted
      StringFingering(5, 3, 3),   // A  → fret 3, ring
      StringFingering(4, 2, 2),   // D  → fret 2, middle
      StringFingering(3, 0, 0),   // G  → open
      StringFingering(2, 1, 1),   // B  → fret 1, index
      StringFingering(1, 0, 0),   // e  → open
    ],
    tips: [
      'Curl your fingers so they don\'t accidentally mute adjacent strings.',
      'Make sure the low E string is fully muted — don\'t let it ring.',
      'Practice the transition from G chord: keep your ring finger anchored.',
    ],
  ),

  ChordData(
    name: 'D',
    displayName: 'D',
    fullName: 'D Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'D',
    fingerings: [
      StringFingering(6, -1, -1),
      StringFingering(5, -1, -1),
      StringFingering(4, 0, 0),
      StringFingering(3, 2, 1),
      StringFingering(2, 3, 3),
      StringFingering(1, 2, 2),
    ],
    tips: [
      'Only strum strings 4–1 (D string down to high e).',
      'Keep your fingers close to the frets for a clean sound.',
      'The D shape is a triangle — once you see it, you\'ll never forget it.',
    ],
  ),

  ChordData(
    name: 'E',
    displayName: 'E',
    fullName: 'E Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'E',
    fingerings: [
      StringFingering(6, 0, 0),
      StringFingering(5, 2, 2),
      StringFingering(4, 2, 3),
      StringFingering(3, 1, 1),
      StringFingering(2, 0, 0),
      StringFingering(1, 0, 0),
    ],
    tips: [
      'All 6 strings ring — strum freely from low E.',
      'This shape is the basis for the F barre chord.',
      'Keep your wrist relaxed and elbow close to your body.',
    ],
  ),

  ChordData(
    name: 'F',
    displayName: 'F',
    fullName: 'F Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'F',
    fingerings: [
      StringFingering(6, 1, 1), // index barre
      StringFingering(5, 3, 3),
      StringFingering(4, 3, 4),
      StringFingering(3, 2, 2),
      StringFingering(2, 1, 1), // barre
      StringFingering(1, 1, 1), // barre
    ],
    tips: [
      'Full barre at fret 1 with your index finger across all 6 strings.',
      'Roll your index finger slightly back (toward the headstock) for a cleaner barre.',
      'Press with the side of your index finger, not the pad.',
    ],
  ),

  ChordData(
    name: 'G',
    displayName: 'G',
    fullName: 'G Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'G',
    fingerings: [
      StringFingering(6, 3, 2),
      StringFingering(5, 2, 1),
      StringFingering(4, 0, 0),
      StringFingering(3, 0, 0),
      StringFingering(2, 0, 0),
      StringFingering(1, 3, 4),
    ],
    tips: [
      'All 6 strings ring — strum freely.',
      'Try the 4-finger G: also fret string 2 at fret 3 for a fuller sound.',
      'Stretch your pinky to reach string 1 without collapsing your wrist.',
    ],
  ),

  ChordData(
    name: 'A',
    displayName: 'A',
    fullName: 'A Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'A',
    fingerings: [
      StringFingering(6, -1, -1),
      StringFingering(5, 0, 0),
      StringFingering(4, 2, 1),
      StringFingering(3, 2, 2),
      StringFingering(2, 2, 3),
      StringFingering(1, 0, 0),
    ],
    tips: [
      'Three fingers on the same fret — keep them upright to avoid muting string 1.',
      'Strum strings 5–1 only (avoid the low E).',
      'Some players barre frets 4-3-2 with one finger for comfort.',
    ],
  ),

  ChordData(
    name: 'B',
    displayName: 'B',
    fullName: 'B Major',
    isMinor: false,
    startFret: 2,
    mlLabel: 'B',
    fingerings: [
      StringFingering(6, -1, -1),
      StringFingering(5, 2, 1), // partial barre from fret 2
      StringFingering(4, 4, 3),
      StringFingering(3, 4, 4),
      StringFingering(2, 4, 4),
      StringFingering(1, 2, 1),
    ],
    tips: [
      'Index finger barres strings 5 and 1 at fret 2.',
      'This is a moveable A-shape barre — mastering it unlocks every major chord.',
      'Avoid the low E string.',
    ],
  ),

  ChordData(
    name: 'C#',
    displayName: 'C#',
    fullName: 'C# Major',
    isMinor: false,
    startFret: 4,
    mlLabel: 'C',
    fingerings: [
      StringFingering(6, 4, 1),
      StringFingering(5, 6, 3),
      StringFingering(4, 6, 4),
      StringFingering(3, 6, 4),
      StringFingering(2, 6, 4),
      StringFingering(1, 4, 1),
    ],
    tips: [
      'Full barre at fret 4 — this is an A-shape barre chord.',
      'Keep your barre finger straight and press firmly near the fret.',
      'Relax your thumb behind the neck to reduce fatigue.',
    ],
  ),

  ChordData(
    name: 'D#',
    displayName: 'D#',
    fullName: 'D# Major',
    isMinor: false,
    startFret: 6,
    mlLabel: 'E',
    fingerings: [
      StringFingering(6, 6, 1),
      StringFingering(5, 8, 3),
      StringFingering(4, 8, 4),
      StringFingering(3, 8, 4),
      StringFingering(2, 8, 4),
      StringFingering(1, 6, 1),
    ],
    tips: [
      'A-shape barre at fret 6.',
      'Same shape as B major, moved up 4 frets.',
      'Focus on a clean barre — the higher positions need firmer pressure.',
    ],
  ),

  ChordData(
    name: 'F#',
    displayName: 'F#',
    fullName: 'F# Major',
    isMinor: false,
    startFret: 2,
    mlLabel: 'G',
    fingerings: [
      StringFingering(6, 2, 1),
      StringFingering(5, 4, 3),
      StringFingering(4, 4, 4),
      StringFingering(3, 3, 2),
      StringFingering(2, 2, 1),
      StringFingering(1, 2, 1),
    ],
    tips: [
      'E-shape barre at fret 2.',
      'Roll your barre finger slightly for cleaner string contact.',
      'Focus on the high strings ringing clearly first.',
    ],
  ),

  ChordData(
    name: 'G#',
    displayName: 'G#',
    fullName: 'G# Major',
    isMinor: false,
    startFret: 4,
    mlLabel: 'A',
    fingerings: [
      StringFingering(6, 4, 1),
      StringFingering(5, 6, 3),
      StringFingering(4, 6, 4),
      StringFingering(3, 5, 2),
      StringFingering(2, 4, 1),
      StringFingering(1, 4, 1),
    ],
    tips: [
      'E-shape barre at fret 4.',
      'Same shape as F major, moved up 3 frets.',
      'Keep your elbow tucked in for better barre leverage.',
    ],
  ),

  ChordData(
    name: 'A#',
    displayName: 'A#',
    fullName: 'A# Major',
    isMinor: false,
    startFret: 1,
    mlLabel: 'B',
    fingerings: [
      StringFingering(6, 1, 1),
      StringFingering(5, 3, 3),
      StringFingering(4, 3, 4),
      StringFingering(3, 3, 4),
      StringFingering(2, 3, 4),
      StringFingering(1, 1, 1),
    ],
    tips: [
      'A-shape barre at fret 1.',
      'Ring or pinky can barre strings 4-3-2 — experiment with what feels better.',
      'Make sure the barre index finger clears the low E.',
    ],
  ),

  // ── MINOR CHORDS ──────────────────────────────────────────────────────────

  ChordData(
    name: 'C minor',
    displayName: 'Cm',
    fullName: 'C Minor',
    isMinor: true,
    startFret: 3,
    mlLabel: 'C minor',
    fingerings: [
      StringFingering(6, 3, 1),
      StringFingering(5, 5, 3),
      StringFingering(4, 5, 4),
      StringFingering(3, 5, 4),
      StringFingering(2, 4, 2),  // note: minor shape
      StringFingering(1, 3, 1),
    ],
    tips: [
      'A-shape minor barre at fret 3.',
      'The minor barre differs from major by one note — practice both back-to-back.',
      'Check each string rings clearly before moving on.',
    ],
  ),

  ChordData(
    name: 'D minor',
    displayName: 'Dm',
    fullName: 'D Minor',
    isMinor: true,
    startFret: 1,
    mlLabel: 'D minor',
    fingerings: [
      StringFingering(6, -1, -1),
      StringFingering(5, -1, -1),
      StringFingering(4, 0, 0),
      StringFingering(3, 2, 2),
      StringFingering(2, 3, 3),
      StringFingering(1, 1, 1),
    ],
    tips: [
      'Strum strings 4–1 only.',
      'Very similar to D major — notice how only one note changes.',
      'Great beginner chord: no barre required.',
    ],
  ),

  ChordData(
    name: 'E minor',
    displayName: 'Em',
    fullName: 'E Minor',
    isMinor: true,
    startFret: 1,
    mlLabel: 'E minor',
    fingerings: [
      StringFingering(6, 0, 0),
      StringFingering(5, 2, 2),
      StringFingering(4, 2, 3),
      StringFingering(3, 0, 0),
      StringFingering(2, 0, 0),
      StringFingering(1, 0, 0),
    ],
    tips: [
      'One of the easiest chords — great for beginners.',
      'All 6 strings ring — strum freely.',
      'E major and E minor differ by just one finger.',
    ],
  ),

  ChordData(
    name: 'F minor',
    displayName: 'Fm',
    fullName: 'F Minor',
    isMinor: true,
    startFret: 1,
    mlLabel: 'F minor',
    fingerings: [
      StringFingering(6, 1, 1),
      StringFingering(5, 3, 3),
      StringFingering(4, 3, 4),
      StringFingering(3, 1, 1),
      StringFingering(2, 1, 1),
      StringFingering(1, 1, 1),
    ],
    tips: [
      'Full barre at fret 1 with an Em-shape on top.',
      'One of the most common minor barre chords.',
      'Keep the barre firm — high e string is easy to accidentally mute.',
    ],
  ),

  ChordData(
    name: 'G minor',
    displayName: 'Gm',
    fullName: 'G Minor',
    isMinor: true,
    startFret: 3,
    mlLabel: 'G minor',
    fingerings: [
      StringFingering(6, 3, 1),
      StringFingering(5, 5, 3),
      StringFingering(4, 5, 4),
      StringFingering(3, 3, 1),
      StringFingering(2, 3, 1),
      StringFingering(1, 3, 1),
    ],
    tips: [
      'Em-shape barre at fret 3.',
      'Barre index firmly across all strings at fret 3.',
      'Used constantly in pop, blues, and rock progressions.',
    ],
  ),

  ChordData(
    name: 'A minor',
    displayName: 'Am',
    fullName: 'A Minor',
    isMinor: true,
    startFret: 1,
    mlLabel: 'A minor',
    fingerings: [
      StringFingering(6, -1, -1),
      StringFingering(5, 0, 0),
      StringFingering(4, 2, 2),
      StringFingering(3, 2, 3),
      StringFingering(2, 1, 1),
      StringFingering(1, 0, 0),
    ],
    tips: [
      'Strum strings 5–1 only.',
      'Compare with A major — the difference is just one finger.',
      'Great pairing with C, G, and F chords for countless songs.',
    ],
  ),

  ChordData(
    name: 'B minor',
    displayName: 'Bm',
    fullName: 'B Minor',
    isMinor: true,
    startFret: 2,
    mlLabel: 'B minor',
    fingerings: [
      StringFingering(6, -1, -1),
      StringFingering(5, 2, 1),
      StringFingering(4, 4, 3),
      StringFingering(3, 4, 4),
      StringFingering(2, 3, 2),
      StringFingering(1, 2, 1),
    ],
    tips: [
      'Am-shape partial barre at fret 2.',
      'Index finger barres strings 5 and 1 at fret 2.',
      'Avoid the low E string.',
    ],
  ),

  ChordData(
    name: 'C# minor',
    displayName: 'C#m',
    fullName: 'C# Minor',
    isMinor: true,
    startFret: 4,
    mlLabel: 'C minor',
    fingerings: [
      StringFingering(6, 4, 1),
      StringFingering(5, 6, 3),
      StringFingering(4, 6, 4),
      StringFingering(3, 6, 4),
      StringFingering(2, 5, 2),
      StringFingering(1, 4, 1),
    ],
    tips: [
      'Am-shape barre at fret 4.',
      'Very common in songs using the key of A or E major.',
      'Focus on a clean barre — press with the side of your finger.',
    ],
  ),

  ChordData(
    name: 'D# minor',
    displayName: 'D#m',
    fullName: 'D# Minor',
    isMinor: true,
    startFret: 6,
    mlLabel: 'E minor',
    fingerings: [
      StringFingering(6, 6, 1),
      StringFingering(5, 8, 3),
      StringFingering(4, 8, 4),
      StringFingering(3, 8, 4),
      StringFingering(2, 7, 2),
      StringFingering(1, 6, 1),
    ],
    tips: [
      'Am-shape barre at fret 6.',
      'Same shape as Bm, moved up 4 frets.',
      'Higher positions need firmer barre pressure.',
    ],
  ),

  ChordData(
    name: 'F# minor',
    displayName: 'F#m',
    fullName: 'F# Minor',
    isMinor: true,
    startFret: 2,
    mlLabel: 'G minor',
    fingerings: [
      StringFingering(6, 2, 1),
      StringFingering(5, 4, 3),
      StringFingering(4, 4, 4),
      StringFingering(3, 2, 1),
      StringFingering(2, 2, 1),
      StringFingering(1, 2, 1),
    ],
    tips: [
      'Em-shape barre at fret 2.',
      'Very common in pop and rock in the key of D or A.',
      'Let all 6 strings ring.',
    ],
  ),

  ChordData(
    name: 'G# minor',
    displayName: 'G#m',
    fullName: 'G# Minor',
    isMinor: true,
    startFret: 4,
    mlLabel: 'A minor',
    fingerings: [
      StringFingering(6, 4, 1),
      StringFingering(5, 6, 3),
      StringFingering(4, 6, 4),
      StringFingering(3, 4, 1),
      StringFingering(2, 4, 1),
      StringFingering(1, 4, 1),
    ],
    tips: [
      'Em-shape barre at fret 4.',
      'Same shape as Fm, moved up 3 frets.',
      'Commonly found in songs in the key of B or E.',
    ],
  ),

  ChordData(
    name: 'A# minor',
    displayName: 'A#m',
    fullName: 'A# Minor',
    isMinor: true,
    startFret: 1,
    mlLabel: 'B minor',
    fingerings: [
      StringFingering(6, 1, 1),
      StringFingering(5, 3, 3),
      StringFingering(4, 3, 4),
      StringFingering(3, 3, 4),
      StringFingering(2, 2, 2),
      StringFingering(1, 1, 1),
    ],
    tips: [
      'Am-shape barre at fret 1.',
      'Sometimes written as Bbm — same chord, different name.',
      'Focus on the minor quality — the flattened third gives it that sad sound.',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Lookup helpers
// ─────────────────────────────────────────────────────────────────────────────

final List<ChordData> majorChords =
    allChords.where((c) => !c.isMinor).toList();

final List<ChordData> minorChords =
    allChords.where((c) => c.isMinor).toList();

/// Find chord by mlLabel — used to match DSPResult against selected chord.
ChordData? chordByLabel(String label) {
  try {
    return allChords.firstWhere(
      (c) => c.mlLabel.toLowerCase() == label.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}