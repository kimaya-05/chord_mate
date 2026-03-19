import 'package:flutter/material.dart';
import 'learn_shared.dart';

class HowToHoldPage extends StatelessWidget {
  const HowToHoldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleScaffold(
      title:    'How to hold a guitar',
      accent:   Colors.greenAccent,
      icon:     Icons.music_note_outlined,
      duration: '5 min read',
      sections: [
        ArticleSection(
          heading: 'Sitting position',
          body:
              'Sit upright on a chair without armrests. Rest the waist of the guitar on your right thigh (or left if you play left-handed). '
              'The back of the guitar should be flat against your stomach — not tilted away from you. '
              'Resist the temptation to tilt the neck downward to see the fretboard; keep it roughly level or slightly angled upward.',
        ),
        ArticleSection(
          heading: 'Fretting hand (left hand)',
          body:
              'Curl your fingers naturally, as if holding a tennis ball. Your thumb rests on the back of the neck — not hooked over the top. '
              'The pad of your thumb sits roughly behind your middle finger. This keeps your fingers arched and able to press cleanly without muting adjacent strings.',
          callout: ArticleCallout(
            label:     'Common mistake',
            body:      'Wrapping your thumb over the top of the neck feels natural at first but limits reach and causes buzzing. Keep it behind the neck.',
            isWarning: true,
          ),
        ),
        ArticleSection(
          heading: 'Picking hand (right hand)',
          body:
              'Rest your forearm on the upper bout of the body — not your elbow. This gives your wrist freedom to move. '
              'Keep your wrist relaxed and slightly rounded. Tension is the enemy of speed and tone.',
        ),
        ArticleSection(
          heading: 'Holding a pick',
          body:
              'Pinch the pick between the pad of your index finger and the flat of your thumb. '
              'About one third of the pick should stick out. A medium-gauge pick (0.73 mm) is the best starting point.',
          callout: ArticleCallout(
            label:     'Tip',
            body:      'If you keep dropping your pick, try one with a textured or matte surface — they grip far better than smooth celluloid.',
            isWarning: false,
          ),
        ),
        ArticleSection(
          heading: 'Strap height',
          body:
              'Set your strap so the guitar sits at the same height standing as when seated. '
              'Many beginners wear it too low — it looks cool but increases wrist strain and makes chord shapes harder to reach.',
        ),
      ],
    );
  }
}