// ─────────────────────────────────────────────────────────────────────────────
// chord_voicings.dart
// 14 practice chords (A Am B Bm C Cm D Dm E Em F Fm G Gm),
// each with 2–3 voicings (open position + barre alternatives).
//
// Reuses StringFingering and ChordData from chord_library.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'chord_library.dart';

// A single voicing variant for a chord.
class ChordVoicing {
  final String label;       // e.g. "Open", "Barre (5th fret)"
  final ChordData data;

  const ChordVoicing({required this.label, required this.data});
}

// A practice entry: one chord with all its voicings.
class PracticeChord {
  final String displayName; // e.g. "Am"
  final String fullName;    // e.g. "A Minor"
  final String mlLabel;     // matches simplifyChordName output
  final bool isMinor;
  final List<ChordVoicing> voicings;

  const PracticeChord({
    required this.displayName,
    required this.fullName,
    required this.mlLabel,
    required this.isMinor,
    required this.voicings,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Voicing definitions
// ─────────────────────────────────────────────────────────────────────────────

const List<PracticeChord> practiceChords = [

  // ── A Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'A',
    fullName: 'A Major',
    mlLabel: 'A',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'A', displayName: 'A', fullName: 'A Major',
          isMinor: false, startFret: 1, mlLabel: 'A',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  0,  0),
            StringFingering(4,  2,  1),
            StringFingering(3,  2,  2),
            StringFingering(2,  2,  3),
            StringFingering(1,  0,  0),
          ],
          tips: ['Keep fingers upright to avoid muting string 1.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (5th fret)',
        data: ChordData(
          name: 'A', displayName: 'A', fullName: 'A Major',
          isMinor: false, startFret: 5, mlLabel: 'A',
          fingerings: [
            StringFingering(6,  5, 1),
            StringFingering(5,  7, 3),
            StringFingering(4,  7, 4),
            StringFingering(3,  6, 2),
            StringFingering(2,  5, 1),
            StringFingering(1,  5, 1),
          ],
          tips: ['E-shape barre at fret 5.'],
        ),
      ),
    ],
  ),

  // ── A Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Am',
    fullName: 'A Minor',
    mlLabel: 'A minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'Am', displayName: 'Am', fullName: 'A Minor',
          isMinor: true, startFret: 1, mlLabel: 'A minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  0,  0),
            StringFingering(4,  2,  2),
            StringFingering(3,  2,  3),
            StringFingering(2,  1,  1),
            StringFingering(1,  0,  0),
          ],
          tips: ['Compare with A major — only one finger changes.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (5th fret)',
        data: ChordData(
          name: 'Am', displayName: 'Am', fullName: 'A Minor',
          isMinor: true, startFret: 5, mlLabel: 'A minor',
          fingerings: [
            StringFingering(6,  5, 1),
            StringFingering(5,  7, 3),
            StringFingering(4,  7, 4),
            StringFingering(3,  5, 1),
            StringFingering(2,  5, 1),
            StringFingering(1,  5, 1),
          ],
          tips: ['Em-shape barre at fret 5.'],
        ),
      ),
    ],
  ),

  // ── B Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'B',
    fullName: 'B Major',
    mlLabel: 'B',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Barre (2nd fret)',
        data: ChordData(
          name: 'B', displayName: 'B', fullName: 'B Major',
          isMinor: false, startFret: 2, mlLabel: 'B',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  2,  1),
            StringFingering(4,  4,  3),
            StringFingering(3,  4,  4),
            StringFingering(2,  4,  4),
            StringFingering(1,  2,  1),
          ],
          tips: ['A-shape partial barre. Index covers strings 5 and 1.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (7th fret)',
        data: ChordData(
          name: 'B', displayName: 'B', fullName: 'B Major',
          isMinor: false, startFret: 7, mlLabel: 'B',
          fingerings: [
            StringFingering(6,  7, 1),
            StringFingering(5,  9, 3),
            StringFingering(4,  9, 4),
            StringFingering(3,  8, 2),
            StringFingering(2,  7, 1),
            StringFingering(1,  7, 1),
          ],
          tips: ['E-shape barre at fret 7.'],
        ),
      ),
    ],
  ),

  // ── B Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Bm',
    fullName: 'B Minor',
    mlLabel: 'B minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Barre (2nd fret)',
        data: ChordData(
          name: 'Bm', displayName: 'Bm', fullName: 'B Minor',
          isMinor: true, startFret: 2, mlLabel: 'B minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  2,  1),
            StringFingering(4,  4,  3),
            StringFingering(3,  4,  4),
            StringFingering(2,  3,  2),
            StringFingering(1,  2,  1),
          ],
          tips: ['Am-shape barre. Very common in pop and rock.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (7th fret)',
        data: ChordData(
          name: 'Bm', displayName: 'Bm', fullName: 'B Minor',
          isMinor: true, startFret: 7, mlLabel: 'B minor',
          fingerings: [
            StringFingering(6,  7, 1),
            StringFingering(5,  9, 3),
            StringFingering(4,  9, 4),
            StringFingering(3,  7, 1),
            StringFingering(2,  7, 1),
            StringFingering(1,  7, 1),
          ],
          tips: ['Em-shape barre at fret 7.'],
        ),
      ),
    ],
  ),

  // ── C Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'C',
    fullName: 'C Major',
    mlLabel: 'C',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'C', displayName: 'C', fullName: 'C Major',
          isMinor: false, startFret: 1, mlLabel: 'C',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  3,  3),
            StringFingering(4,  2,  2),
            StringFingering(3,  0,  0),
            StringFingering(2,  1,  1),
            StringFingering(1,  0,  0),
          ],
          tips: ['Curl fingers to avoid muting adjacent strings.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (3rd fret)',
        data: ChordData(
          name: 'C', displayName: 'C', fullName: 'C Major',
          isMinor: false, startFret: 3, mlLabel: 'C',
          fingerings: [
            StringFingering(6,  3, 1),
            StringFingering(5,  5, 3),
            StringFingering(4,  5, 4),
            StringFingering(3,  5, 4),
            StringFingering(2,  5, 4),
            StringFingering(1,  3, 1),
          ],
          tips: ['A-shape barre at fret 3.'],
        ),
      ),
    ],
  ),

  // ── C Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Cm',
    fullName: 'C Minor',
    mlLabel: 'C minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Barre (3rd fret)',
        data: ChordData(
          name: 'Cm', displayName: 'Cm', fullName: 'C Minor',
          isMinor: true, startFret: 3, mlLabel: 'C minor',
          fingerings: [
            StringFingering(6,  3, 1),
            StringFingering(5,  5, 3),
            StringFingering(4,  5, 4),
            StringFingering(3,  5, 4),
            StringFingering(2,  4, 2),
            StringFingering(1,  3, 1),
          ],
          tips: ['Am-shape barre at fret 3.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (8th fret)',
        data: ChordData(
          name: 'Cm', displayName: 'Cm', fullName: 'C Minor',
          isMinor: true, startFret: 8, mlLabel: 'C minor',
          fingerings: [
            StringFingering(6,  8, 1),
            StringFingering(5, 10, 3),
            StringFingering(4, 10, 4),
            StringFingering(3,  8, 1),
            StringFingering(2,  8, 1),
            StringFingering(1,  8, 1),
          ],
          tips: ['Em-shape barre at fret 8.'],
        ),
      ),
    ],
  ),

  // ── D Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'D',
    fullName: 'D Major',
    mlLabel: 'D',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'D', displayName: 'D', fullName: 'D Major',
          isMinor: false, startFret: 1, mlLabel: 'D',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5, -1, -1),
            StringFingering(4,  0,  0),
            StringFingering(3,  2,  1),
            StringFingering(2,  3,  3),
            StringFingering(1,  2,  2),
          ],
          tips: ['Strum strings 4–1 only. The D shape is a triangle.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (5th fret)',
        data: ChordData(
          name: 'D', displayName: 'D', fullName: 'D Major',
          isMinor: false, startFret: 5, mlLabel: 'D',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  5,  1),
            StringFingering(4,  7,  3),
            StringFingering(3,  7,  4),
            StringFingering(2,  7,  4),
            StringFingering(1,  5,  1),
          ],
          tips: ['A-shape barre at fret 5.'],
        ),
      ),
    ],
  ),

  // ── D Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Dm',
    fullName: 'D Minor',
    mlLabel: 'D minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'Dm', displayName: 'Dm', fullName: 'D Minor',
          isMinor: true, startFret: 1, mlLabel: 'D minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5, -1, -1),
            StringFingering(4,  0,  0),
            StringFingering(3,  2,  2),
            StringFingering(2,  3,  3),
            StringFingering(1,  1,  1),
          ],
          tips: ['Strum strings 4–1 only. No barre required.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (5th fret)',
        data: ChordData(
          name: 'Dm', displayName: 'Dm', fullName: 'D Minor',
          isMinor: true, startFret: 5, mlLabel: 'D minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  5,  1),
            StringFingering(4,  7,  3),
            StringFingering(3,  7,  4),
            StringFingering(2,  6,  2),
            StringFingering(1,  5,  1),
          ],
          tips: ['Am-shape barre at fret 5.'],
        ),
      ),
    ],
  ),

  // ── E Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'E',
    fullName: 'E Major',
    mlLabel: 'E',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'E', displayName: 'E', fullName: 'E Major',
          isMinor: false, startFret: 1, mlLabel: 'E',
          fingerings: [
            StringFingering(6,  0,  0),
            StringFingering(5,  2,  2),
            StringFingering(4,  2,  3),
            StringFingering(3,  1,  1),
            StringFingering(2,  0,  0),
            StringFingering(1,  0,  0),
          ],
          tips: ['All 6 strings ring. The basis for the F barre chord.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (7th fret)',
        data: ChordData(
          name: 'E', displayName: 'E', fullName: 'E Major',
          isMinor: false, startFret: 7, mlLabel: 'E',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  7,  1),
            StringFingering(4,  9,  3),
            StringFingering(3,  9,  4),
            StringFingering(2,  9,  4),
            StringFingering(1,  7,  1),
          ],
          tips: ['A-shape barre at fret 7.'],
        ),
      ),
    ],
  ),

  // ── E Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Em',
    fullName: 'E Minor',
    mlLabel: 'E minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'Em', displayName: 'Em', fullName: 'E Minor',
          isMinor: true, startFret: 1, mlLabel: 'E minor',
          fingerings: [
            StringFingering(6,  0,  0),
            StringFingering(5,  2,  2),
            StringFingering(4,  2,  3),
            StringFingering(3,  0,  0),
            StringFingering(2,  0,  0),
            StringFingering(1,  0,  0),
          ],
          tips: ['One of the easiest chords. All 6 strings ring.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (7th fret)',
        data: ChordData(
          name: 'Em', displayName: 'Em', fullName: 'E Minor',
          isMinor: true, startFret: 7, mlLabel: 'E minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  7,  1),
            StringFingering(4,  9,  3),
            StringFingering(3,  9,  4),
            StringFingering(2,  7,  1),
            StringFingering(1,  7,  1),
          ],
          tips: ['Am-shape barre at fret 7.'],
        ),
      ),
    ],
  ),

  // ── F Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'F',
    fullName: 'F Major',
    mlLabel: 'F',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Barre (1st fret)',
        data: ChordData(
          name: 'F', displayName: 'F', fullName: 'F Major',
          isMinor: false, startFret: 1, mlLabel: 'F',
          fingerings: [
            StringFingering(6,  1,  1),
            StringFingering(5,  3,  3),
            StringFingering(4,  3,  4),
            StringFingering(3,  2,  2),
            StringFingering(2,  1,  1),
            StringFingering(1,  1,  1),
          ],
          tips: ['Full barre at fret 1. Roll your index slightly back.'],
        ),
      ),
      ChordVoicing(
        label: 'Mini F (no low E)',
        data: ChordData(
          name: 'F', displayName: 'F', fullName: 'F Major',
          isMinor: false, startFret: 1, mlLabel: 'F',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5, -1, -1),
            StringFingering(4,  3,  3),
            StringFingering(3,  2,  2),
            StringFingering(2,  1,  1),
            StringFingering(1,  1,  1),
          ],
          tips: ['Easier version — omit the two bass strings until barre is solid.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (8th fret)',
        data: ChordData(
          name: 'F', displayName: 'F', fullName: 'F Major',
          isMinor: false, startFret: 8, mlLabel: 'F',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  8,  1),
            StringFingering(4, 10,  3),
            StringFingering(3, 10,  4),
            StringFingering(2, 10,  4),
            StringFingering(1,  8,  1),
          ],
          tips: ['A-shape barre at fret 8.'],
        ),
      ),
    ],
  ),

  // ── F Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Fm',
    fullName: 'F Minor',
    mlLabel: 'F minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Barre (1st fret)',
        data: ChordData(
          name: 'Fm', displayName: 'Fm', fullName: 'F Minor',
          isMinor: true, startFret: 1, mlLabel: 'F minor',
          fingerings: [
            StringFingering(6,  1,  1),
            StringFingering(5,  3,  3),
            StringFingering(4,  3,  4),
            StringFingering(3,  1,  1),
            StringFingering(2,  1,  1),
            StringFingering(1,  1,  1),
          ],
          tips: ['Full barre at fret 1 with Em-shape on top.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (8th fret)',
        data: ChordData(
          name: 'Fm', displayName: 'Fm', fullName: 'F Minor',
          isMinor: true, startFret: 8, mlLabel: 'F minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5,  8,  1),
            StringFingering(4, 10,  3),
            StringFingering(3, 10,  4),
            StringFingering(2,  9,  2),
            StringFingering(1,  8,  1),
          ],
          tips: ['Am-shape barre at fret 8.'],
        ),
      ),
    ],
  ),

  // ── G Major ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'G',
    fullName: 'G Major',
    mlLabel: 'G',
    isMinor: false,
    voicings: [
      ChordVoicing(
        label: 'Open',
        data: ChordData(
          name: 'G', displayName: 'G', fullName: 'G Major',
          isMinor: false, startFret: 1, mlLabel: 'G',
          fingerings: [
            StringFingering(6,  3,  2),
            StringFingering(5,  2,  1),
            StringFingering(4,  0,  0),
            StringFingering(3,  0,  0),
            StringFingering(2,  0,  0),
            StringFingering(1,  3,  4),
          ],
          tips: ['All 6 strings ring. Stretch pinky to string 1.'],
        ),
      ),
      ChordVoicing(
        label: 'Open (4-finger)',
        data: ChordData(
          name: 'G', displayName: 'G', fullName: 'G Major',
          isMinor: false, startFret: 1, mlLabel: 'G',
          fingerings: [
            StringFingering(6,  3,  2),
            StringFingering(5,  2,  1),
            StringFingering(4,  0,  0),
            StringFingering(3,  0,  0),
            StringFingering(2,  3,  3),
            StringFingering(1,  3,  4),
          ],
          tips: ['4-finger G — fuller sound. Great for strumming.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (3rd fret)',
        data: ChordData(
          name: 'G', displayName: 'G', fullName: 'G Major',
          isMinor: false, startFret: 3, mlLabel: 'G',
          fingerings: [
            StringFingering(6,  3,  1),
            StringFingering(5,  5,  3),
            StringFingering(4,  5,  4),
            StringFingering(3,  4,  2),
            StringFingering(2,  3,  1),
            StringFingering(1,  3,  1),
          ],
          tips: ['E-shape barre at fret 3.'],
        ),
      ),
    ],
  ),

  // ── G Minor ────────────────────────────────────────────────────────────────
  PracticeChord(
    displayName: 'Gm',
    fullName: 'G Minor',
    mlLabel: 'G minor',
    isMinor: true,
    voicings: [
      ChordVoicing(
        label: 'Barre (3rd fret)',
        data: ChordData(
          name: 'Gm', displayName: 'Gm', fullName: 'G Minor',
          isMinor: true, startFret: 3, mlLabel: 'G minor',
          fingerings: [
            StringFingering(6,  3,  1),
            StringFingering(5,  5,  3),
            StringFingering(4,  5,  4),
            StringFingering(3,  3,  1),
            StringFingering(2,  3,  1),
            StringFingering(1,  3,  1),
          ],
          tips: ['Em-shape barre at fret 3. Used often in pop and blues.'],
        ),
      ),
      ChordVoicing(
        label: 'Barre (10th fret)',
        data: ChordData(
          name: 'Gm', displayName: 'Gm', fullName: 'G Minor',
          isMinor: true, startFret: 10, mlLabel: 'G minor',
          fingerings: [
            StringFingering(6, -1, -1),
            StringFingering(5, 10,  1),
            StringFingering(4, 12,  3),
            StringFingering(3, 12,  4),
            StringFingering(2, 11,  2),
            StringFingering(1, 10,  1),
          ],
          tips: ['Am-shape barre at fret 10.'],
        ),
      ),
    ],
  ),
];