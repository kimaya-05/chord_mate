import 'package:flutter/material.dart';
import 'learn_shared.dart';

class GlossaryPage extends StatelessWidget {
  const GlossaryPage({super.key});

  static const _terms = <GlossaryEntry>[
    GlossaryEntry('Chord',        'Three or more notes played simultaneously. Named by their root note and quality — e.g. C Major, Am.'),
    GlossaryEntry('Root note',    'The note a chord or scale is built on and named after. In a G Major chord, G is the root.'),
    GlossaryEntry('Interval',     'The distance between two notes, measured in semitones. One semitone equals one fret on the guitar.'),
    GlossaryEntry('Scale',        'A sequence of notes arranged by pitch. The major scale (do re mi fa sol la ti) is the most common.'),
    GlossaryEntry('Key',          'The tonal centre of a piece. A song in the key of G major uses notes from the G major scale.'),
    GlossaryEntry('Nut',          'The small piece at the top of the neck where strings pass through before reaching the tuning pegs.'),
    GlossaryEntry('Fret',         'The metal strips along the neck. Pressing a string between two frets raises pitch by one semitone per fret.'),
    GlossaryEntry('Capo',         'A clamp placed across all strings at a chosen fret to raise the key without changing chord shapes.'),
    GlossaryEntry('Open chord',   'A chord using at least one open (unfretted) string. Most beginner chords — C, G, D, Am — are open chords.'),
    GlossaryEntry('Barre chord',  'A chord where the index finger presses all six strings at one fret, acting as a movable nut.'),
    GlossaryEntry('Arpeggio',     'Playing the notes of a chord one at a time rather than strumming them simultaneously.'),
    GlossaryEntry('Tempo',        'The speed of the music, measured in beats per minute (BPM). A metronome keeps you in time.'),
    GlossaryEntry('Time signature','How many beats are in each bar and what note counts as one beat. 4/4 is the most common.'),
    GlossaryEntry('Dynamics',     'Variation in volume — quiet passages (piano) and loud ones (forte). Important for expression and feel.'),
    GlossaryEntry('Vibrato',      'Repeatedly bending a fretted note slightly up and down while it sustains, adding expressiveness.'),
    GlossaryEntry('Sustain',      'How long a note rings out after it is played. Heavier strings and good setup improve sustain.'),
    GlossaryEntry('Action',       'The height of the strings above the fretboard. Low action is easier to play; high action gives more volume.'),
    GlossaryEntry('Intonation',   'Whether the guitar plays in tune all the way up the neck. Poor intonation means chords sound off even when open strings are in tune.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ArticleScaffold(
      title:    'Glossary of terms',
      accent:   Colors.amber,
      icon:     Icons.menu_book_outlined,
      duration: '8 min read',
      sections: const [],
      customBody: GlossaryBody(terms: _terms),
    );
  }
}