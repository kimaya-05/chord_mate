import 'package:flutter/material.dart';
import 'learn_shared.dart';

class ChordDiagramsPage extends StatelessWidget {
  const ChordDiagramsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleScaffold(
      title:    'How to read chord diagrams',
      accent:   Color(0xFF64B5F6),
      icon:     Icons.grid_view_rounded,
      duration: '4 min read',
      sections: [
        ArticleSection(
          heading: 'What you are looking at',
          body:
              'A chord diagram is a bird\'s-eye view of the guitar neck. '
              'Six vertical lines represent the six strings — leftmost is low E (thickest), rightmost is high e (thinnest). '
              'Horizontal lines are the frets. The thick bar at the very top represents the nut.',
          diagram: DiagramWidget(type: DiagramType.chordGrid),
        ),
        ArticleSection(
          heading: 'Dots and finger numbers',
          body:
              'Filled circles show where to place your fingers. The number inside tells you which finger: '
              '1 = index, 2 = middle, 3 = ring, 4 = pinky. '
              'A dot spanning multiple strings is a barre — press your index finger flat across all of them.',
        ),
        ArticleSection(
          heading: 'X and O symbols',
          body:
              'Above the nut you will see an X or O for each string. '
              'O means play it open — do not fret it. '
              'X means mute it — do not play it, or lightly rest an unused finger against it.',
          callout: ArticleCallout(
            label: 'Common mistake',
            body:  'Strumming an X string is one of the most common causes of a muddy chord. Practice hitting only the intended strings by slowing your strum right down.',
            isWarning: true,
          ),
        ),
        ArticleSection(
          heading: 'Fret position numbers',
          body:
              'When a chord is played higher up the neck, a number appears to the right of the diagram showing which fret the top row represents. '
              '"5fr" means the diagram starts at the 5th fret. The fingering logic is otherwise identical.',
        ),
        ArticleSection(
          heading: 'Barre chords',
          body:
              'A curved line across multiple strings on the same fret indicates a barre. '
              'Press the side of your index finger — not the pad — firmly across all marked strings. '
              'Place it as close to the fret wire as possible to minimise the pressure needed.',
          callout: ArticleCallout(
            label: 'Tip',
            body:  'Barre chords take weeks to build strength for. This is completely normal — everyone struggles with them at first.',
            isWarning: false,
          ),
        ),
      ],
    );
  }
}