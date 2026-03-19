import 'package:flutter/material.dart';
import 'learn_shared.dart';

class ReadingTabsPage extends StatelessWidget {
  const ReadingTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleScaffold(
      title:    'How to read tabs',
      accent:   Color(0xFF7E8CE0),
      icon:     Icons.linear_scale_rounded,
      duration: '5 min read',
      sections: [
        ArticleSection(
          heading: 'The six lines',
          body:
              'Tab uses six horizontal lines, one per string. '
              'Unlike chord diagrams, the bottom line is the low E string and the top line is the high e string. '
              'Numbers on each line tell you which fret to press. A 0 means play that string open.',
          diagram: DiagramWidget(type: DiagramType.tabLines),
        ),
        ArticleSection(
          heading: 'Reading left to right',
          body:
              'Read tab exactly like text — left to right. '
              'Numbers stacked vertically are played at the same time (a chord). '
              'Numbers in sequence are played one after another (a melody or riff).',
        ),
        ArticleSection(
          heading: 'Hammer-ons and pull-offs',
          body:
              'A hammer-on is written as h between two numbers — e.g. 5h7. '
              'Pick the first note, then hammer your finger onto the second fret without picking again. '
              'A pull-off is written as p — e.g. 7p5. Pick the higher note then pull your finger off to sound the lower one.',
          diagram: DiagramWidget(type: DiagramType.hammerPulloff),
        ),
        ArticleSection(
          heading: 'Slides',
          body:
              'A forward slash / means slide up — pick the first note and slide your finger up to the second fret without releasing pressure. '
              'A backslash \\ means slide down. Some tabs write s between the numbers instead.',
        ),
        ArticleSection(
          heading: 'Bends',
          body:
              'A bend is written as b — e.g. 7b9 means fret 7 and bend until it sounds like fret 9. '
              'A full bend equals two frets; a half bend equals one. '
              'br or r means release the bend back to the original pitch.',
          callout: ArticleCallout(
            label: 'Tip',
            body:  'Support bends with multiple fingers — ring finger frets the note while index and middle fingers push from behind.',
            isWarning: false,
          ),
        ),
        ArticleSection(
          heading: 'Vibrato and muting',
          body:
              'A tilde ~ after a number means apply vibrato — wobble the string up and down slightly while the note sustains. '
              'An x on a string means mute it and strike it for a percussive click, widely used in funk and rhythm playing.',
        ),
      ],
    );
  }
}