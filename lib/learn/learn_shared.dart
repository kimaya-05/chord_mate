import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ArticleScaffold — shared page wrapper for all Learn articles
// ─────────────────────────────────────────────────────────────────────────────

class ArticleScaffold extends StatelessWidget {
  final String             title;
  final Color              accent;
  final IconData           icon;
  final String             duration;
  final List<ArticleSection> sections;
  final Widget?            customBody;

  const ArticleScaffold({
    super.key,
    required this.title,
    required this.accent,
    required this.icon,
    required this.duration,
    required this.sections,
    this.customBody,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0F),
            elevation: 0,
            floating: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Article header ──────────────────────────────────
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: accent.withOpacity(0.3)),
                        ),
                        child: Text(
                          'BEGINNER',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(duration,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.35))),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: Colors.white.withOpacity(0.07)),
                const SizedBox(height: 24),

                // ── Body ────────────────────────────────────────────
                if (customBody != null)
                  customBody!
                else
                  ...sections.map((s) => ArticleSectionWidget(
                        section: s,
                        accent: accent,
                      )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class ArticleSection {
  final String          heading;
  final String          body;
  final ArticleCallout? callout;
  final DiagramWidget?  diagram;

  const ArticleSection({
    required this.heading,
    required this.body,
    this.callout,
    this.diagram,
  });
}

class ArticleCallout {
  final String label;
  final String body;
  final bool   isWarning;
  const ArticleCallout({
    required this.label,
    required this.body,
    required this.isWarning,
  });
}

class GlossaryEntry {
  final String term;
  final String definition;
  const GlossaryEntry(this.term, this.definition);
}

// ─────────────────────────────────────────────────────────────────────────────
// ArticleSectionWidget
// ─────────────────────────────────────────────────────────────────────────────

class ArticleSectionWidget extends StatelessWidget {
  final ArticleSection section;
  final Color          accent;

  const ArticleSectionWidget({
    super.key,
    required this.section,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading with accent bar
          Row(children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                section.heading,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              height: 1.65,
            ),
          ),
          if (section.diagram != null) ...[
            const SizedBox(height: 16),
            section.diagram!,
          ],
          if (section.callout != null) ...[
            const SizedBox(height: 14),
            CalloutWidget(callout: section.callout!),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CalloutWidget
// ─────────────────────────────────────────────────────────────────────────────

class CalloutWidget extends StatelessWidget {
  final ArticleCallout callout;
  const CalloutWidget({super.key, required this.callout});

  @override
  Widget build(BuildContext context) {
    final color = callout.isWarning ? Colors.orangeAccent : Colors.greenAccent;
    final icon  = callout.isWarning
        ? Icons.warning_amber_rounded
        : Icons.lightbulb_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callout.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  callout.body,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.65),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GlossaryBody
// ─────────────────────────────────────────────────────────────────────────────

class GlossaryBody extends StatelessWidget {
  final List<GlossaryEntry> terms;
  const GlossaryBody({super.key, required this.terms});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: terms.asMap().entries.map((e) {
        final isLast = e.key == terms.length - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.value.term,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    e.value.definition,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.55),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DiagramWidget
// ─────────────────────────────────────────────────────────────────────────────

enum DiagramType { chordGrid, tabLines, hammerPulloff, strumPattern }

class DiagramWidget extends StatelessWidget {
  final DiagramType type;
  const DiagramWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: switch (type) {
        DiagramType.chordGrid     => const _ChordGridDiagram(),
        DiagramType.tabLines      => const _TabLinesDiagram(),
        DiagramType.hammerPulloff => const _HammerPulloffDiagram(),
        DiagramType.strumPattern  => const _StrumPatternDiagram(),
      },
    );
  }
}

// ── Chord grid ────────────────────────────────────────────────────────────────

class _ChordGridDiagram extends StatelessWidget {
  const _ChordGridDiagram();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A Major — x02220',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 160,
            height: 180,
            child: CustomPaint(painter: _ChordGridPainter()),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _DiagramKey(color: Colors.greenAccent, label: 'Fretted note'),
          const SizedBox(width: 16),
          _DiagramKey(color: Colors.white54,     label: 'Open / Muted'),
        ]),
      ],
    );
  }
}

class _ChordGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final nutPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    final openPaint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final mutedPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    const left  = 24.0;
    const top   = 28.0;
    const cellW = 22.0;
    const cellH = 26.0;
    const frets = 4;
    const strs  = 6;
    final gridW = cellW * (strs - 1);
    final gridH = cellH * frets;

    canvas.drawLine(Offset(left, top), Offset(left + gridW, top), nutPaint);

    for (int f = 0; f <= frets; f++) {
      final y = top + f * cellH;
      canvas.drawLine(Offset(left, y), Offset(left + gridW, y), linePaint);
    }
    for (int s = 0; s < strs; s++) {
      final x = left + s * cellW;
      canvas.drawLine(Offset(x, top), Offset(x, top + gridH), linePaint);
    }

    // A Major: x 0 2 2 2 0
    // Muted low E (string 0)
    final mx = left;
    canvas.drawLine(Offset(mx - 6, top - 14), Offset(mx + 6, top - 2), mutedPaint);
    canvas.drawLine(Offset(mx + 6, top - 14), Offset(mx - 6, top - 2), mutedPaint);
    // Open A (string 1)
    canvas.drawCircle(Offset(left + cellW, top - 8), 6, openPaint);
    // Fretted D, G, B (strings 2, 3, 4) at fret 2
    for (final s in [2, 3, 4]) {
      canvas.drawCircle(
          Offset(left + s * cellW, top + 1.5 * cellH), 9, dotPaint);
    }
    // Open high e (string 5)
    canvas.drawCircle(Offset(left + 5 * cellW, top - 8), 6, openPaint);

    // Finger numbers inside dots
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 3; i++) {
      tp.text = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
            color: Color(0xFF0A0A0F),
            fontSize: 11,
            fontWeight: FontWeight.w800),
      );
      tp.layout();
      tp.paint(canvas, Offset(
          left + (i + 2) * cellW - tp.width / 2,
          top + 1.5 * cellH - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Tab lines ─────────────────────────────────────────────────────────────────

class _TabLinesDiagram extends StatelessWidget {
  const _TabLinesDiagram();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opening riff — "Smoke on the Water"',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
        const _TabText(tab:
            'e |---|---|---|---|\n'
            'B |---|---|---|---|\n'
            'G |0--|3--|5--|---|\n'
            'D |0--|3--|5--|---|\n'
            'A |---|---|---|---|\n'
            'E |---|---|---|---|'),
      ],
    );
  }
}

// ── Hammer / pull-off ─────────────────────────────────────────────────────────

class _HammerPulloffDiagram extends StatelessWidget {
  const _HammerPulloffDiagram();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hammer-on (h) and pull-off (p)',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
        const _TabText(tab:
            'e |5h7p5-----------|\n'
            'B |----------8p5---|\n'
            'G |----------------|\n'
            'D |----------------|\n'
            'A |----------------|\n'
            'E |----------------|'),
      ],
    );
  }
}

// ── Strum pattern ─────────────────────────────────────────────────────────────

class _StrumPatternDiagram extends StatelessWidget {
  const _StrumPatternDiagram();

  // (beat label, strum direction or null, is highlighted)
  static const _beats = <(String, String?, bool)>[
    ('1',   '↓', true),
    ('and', null, false),
    ('2',   '↓', true),
    ('and', '↑', true),
    ('3',   null, false),
    ('and', '↑', true),  // wait — pattern 3 is ↓ ↓↑ ↓↑ so:
    ('4',   '↓', true),   // actually: 1↓ 2↓ 2↑ 3— 3↑ (common variant)
    ('and', '↑', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pattern 3  ↓  ↓↑  ↓↑',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.5)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _beats.map((b) {
            final (label, strum, highlighted) = b;
            return Column(
              children: [
                Text(
                  strum ?? '—',
                  style: TextStyle(
                    fontSize: 20,
                    color: highlighted
                        ? Colors.greenAccent
                        : Colors.white12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: highlighted
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white24,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Monospace tab text ────────────────────────────────────────────────────────

class _TabText extends StatelessWidget {
  final String tab;
  const _TabText({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tab,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white70,
          height: 1.7,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Diagram legend key ────────────────────────────────────────────────────────

class _DiagramKey extends StatelessWidget {
  final Color  color;
  final String label;
  const _DiagramKey({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 10, color: Colors.white.withOpacity(0.4))),
    ]);
  }
}