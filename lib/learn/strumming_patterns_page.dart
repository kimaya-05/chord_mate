import 'package:flutter/material.dart';
import 'learn_shared.dart';

class StrummingPatternsPage extends StatelessWidget {
  const StrummingPatternsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleScaffold(
      title:    'Strumming patterns',
      accent:   Colors.orangeAccent,
      icon:     Icons.music_note_outlined,
      duration: '4 min read',
      sections: [
        ArticleSection(
          heading: 'Down and up strokes',
          body:
              'Every strumming pattern is built from two moves: a downstroke (↓) toward the floor and an upstroke (↑) toward the ceiling. '
              'The key is keeping your strumming arm moving in a constant pendulum motion — whether or not you hit the strings on every beat.',
        ),
        ArticleSection(
          heading: 'Counting beats',
          body:
              'In 4/4 time there are four beats per bar. Each beat subdivides into two eighth-notes: '
              'the beat itself ("1", "2", "3", "4") and the "and" between beats. '
              'Downstrokes fall on the number; upstrokes fall on the "and".',
          diagram: DiagramWidget(type: DiagramType.strumPattern),
        ),
        ArticleSection(
          heading: 'Pattern 1 — all down',
          body:
              '↓  ↓  ↓  ↓\n'
              'One downstroke per beat. The simplest pattern and the right starting point. '
              'Focus on keeping time. Count out loud: 1 — 2 — 3 — 4.',
        ),
        ArticleSection(
          heading: 'Pattern 2 — down up',
          body:
              '↓ ↑ ↓ ↑ ↓ ↑ ↓ ↑\n'
              'Alternating down and up on every eighth-note. Count: 1-and-2-and-3-and-4-and. '
              'Keep your arm moving continuously even when you intentionally miss a strum.',
        ),
        ArticleSection(
          heading: 'Pattern 3 — most common beginner pattern',
          body:
              '↓  ↓ ↑  ↓ ↑\n'
              'Count: 1 — 2-and — 3-and. This pattern appears in hundreds of popular songs. '
              'Practice switching chords on beat 1 — that is where the chord change always lands.',
          callout: ArticleCallout(
            label: 'Tip',
            body:  'Say the pattern out loud while you play: "down, down-up, down-up". Your body learns rhythm through sound as much as through your hands.',
            isWarning: false,
          ),
        ),
        ArticleSection(
          heading: 'Pattern 4 — syncopated',
          body:
              '↓  ↓ ↑  ↑ ↓ ↑\n'
              'Count: 1 — 2-and — and-4-and. The skipped downstroke on beat 3 creates a syncopated feel '
              'common in pop, folk and country. Great to learn once Pattern 3 is solid.',
        ),
        ArticleSection(
          heading: 'Building your own patterns',
          body:
              'Once you can play the above cleanly, make your own. Start with the constant eighth-note arm movement '
              'and choose which strokes to skip. Always use a metronome — even at 60 BPM.',
          callout: ArticleCallout(
            label: 'Common mistake',
            body:  'Stopping your arm on rests. It should keep moving at all times — you just ghost over the strings without contact on the silent beats.',
            isWarning: true,
          ),
        ),
      ],
    );
  }
}