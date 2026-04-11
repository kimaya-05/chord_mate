import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chords/chord_library.dart';
import 'drill_screen.dart';
import '../services/pb_service.dart'; 

 
// ─────────────────────────────────────────────────────────────────────────────
// Constants & Data
// ─────────────────────────────────────────────────────────────────────────────
 
/// The 14 practice chords (A–G major and minor, no sharps).
final List<ChordData> _practiceChords = allChords
    .where((c) => !c.name.contains('#'))
    .toList();
 
/// Suggested pairs grouped by difficulty.
/// Each entry: (chordA_mlLabel, chordB_mlLabel, description)
const List<_SuggestedPair> _suggestedPairs = [
  // Beginner
  _SuggestedPair('A minor', 'C',       'Am → C',   Difficulty.beginner),
  _SuggestedPair('A minor', 'E minor', 'Am → Em',  Difficulty.beginner),
  _SuggestedPair('C',       'G',       'C → G',    Difficulty.beginner),
  _SuggestedPair('G',       'D',       'G → D',    Difficulty.beginner),
  _SuggestedPair('E',       'A',       'E → A',    Difficulty.beginner),
  // Intermediate
  _SuggestedPair('C',       'F',       'C → F',    Difficulty.intermediate),
  _SuggestedPair('G',       'E minor', 'G → Em',   Difficulty.intermediate),
  _SuggestedPair('D',       'A',       'D → A',    Difficulty.intermediate),
  _SuggestedPair('B minor', 'G',       'Bm → G',   Difficulty.intermediate),
  _SuggestedPair('D',       'B minor', 'D → Bm',   Difficulty.intermediate),
  // Advanced
  _SuggestedPair('F',       'B minor', 'F → Bm',   Difficulty.advanced),
  _SuggestedPair('D minor', 'F',       'Dm → F',   Difficulty.advanced),
  _SuggestedPair('B',       'E',       'B → E',    Difficulty.advanced),
  _SuggestedPair('A minor', 'D minor', 'Am → Dm',  Difficulty.advanced),
];
 
enum Difficulty { beginner, intermediate, advanced }
 
class _SuggestedPair {
  final String labelA;
  final String labelB;
  final String display;
  final Difficulty difficulty;
  const _SuggestedPair(this.labelA, this.labelB, this.display, this.difficulty);
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Entry point — Setup Screen
// ─────────────────────────────────────────────────────────────────────────────
 
class TransitionDrillPage extends StatefulWidget {
  const TransitionDrillPage({super.key});
 
  @override
  State<TransitionDrillPage> createState() => _TransitionDrillPageState();
}
 
class _TransitionDrillPageState extends State<TransitionDrillPage> {
  // Chord pair selection
  ChordData? _chordA;
  ChordData? _chordB;
  bool _freestyleMode = false;
 
  // Session config
  final _targetCtrl = TextEditingController(text: '10');
  bool _useTransitionCount = true; // true = # transitions, false = duration
  int _bpm = 60;
 
  Difficulty? _diffFilter; 

  PersonalBest? _loadedPb;
  bool _pbLoading = false;

  Widget _buildPbBadge() {
      if (_chordA == null || _chordB == null) return const SizedBox.shrink();
      if (_pbLoading) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.greenAccent.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text('Loading personal best…',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
          ]),
        );
      }
      if (_loadedPb == null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('No personal best yet — be the first!',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
        );
      }
      final pct = (_loadedPb!.accuracy * 100).toStringAsFixed(0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded, size: 15, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Personal best: ${_loadedPb!.correct}/${_loadedPb!.total}  •  $pct% accuracy',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber),
            ),
          ]),
        ),
      );
    }
 
  bool get _canStart =>
      _chordA != null && _chordB != null && _chordA != _chordB;
 
  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPb() async {
    if (_chordA == null || _chordB == null) {
      setState(() => _loadedPb = null);
      return;
    }
    setState(() => _pbLoading = true);
    final pb = await PbService.load(_chordA!.mlLabel, _chordB!.mlLabel);
    if (mounted) setState(() { _loadedPb = pb; _pbLoading = false; });
  }
 
  void _selectSuggestedPair(_SuggestedPair pair) {
    final a = _practiceChords.firstWhere((c) => c.mlLabel == pair.labelA);
    final b = _practiceChords.firstWhere((c) => c.mlLabel == pair.labelB);
    setState(() {
      _chordA = a;
      _chordB = b;
      _freestyleMode = false;
    });
    _loadPb();
  }
 
  void _startDrill() {
    if (!_canStart) return;
    final target = int.tryParse(_targetCtrl.text) ?? 10;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DrillScreen(
        chordA: _chordA!,
        chordB: _chordB!,
        bpm: _bpm,
        targetCount: _useTransitionCount ? target : null,
        targetSeconds: _useTransitionCount ? null : target,
      ),
    ));
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transition Drill',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroCard(),
            const SizedBox(height: 24),
            _buildSuggestedPairsSection(),
            const SizedBox(height: 24),
            _buildFreestylePicker(),
            const SizedBox(height: 24),
            _buildSessionConfig(),
            const SizedBox(height: 28),
            _buildPbBadge(),
            _buildStartButton(),
          ],
        ),
      ),
    );
  }
 
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.swap_horiz_rounded,
              color: Colors.greenAccent.withOpacity(0.8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pick two chords. The metronome ticks — on each beat, switch. '
              'The app listens and scores how cleanly you land each transition.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.55),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
 
 
  Widget _buildSuggestedPairsSection() {
    final filtered = _diffFilter == null
        ? _suggestedPairs
        : _suggestedPairs.where((p) => p.difficulty == _diffFilter).toList();
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Suggested Pairs'),
        const SizedBox(height: 10),
        // Difficulty filter chips
        Row(
          children: [
            _filterChip('All', null),
            const SizedBox(width: 8),
            _filterChip('Beginner', Difficulty.beginner),
            const SizedBox(width: 8),
            _filterChip('Intermediate', Difficulty.intermediate),
            const SizedBox(width: 8),
            _filterChip('Advanced', Difficulty.advanced),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map((pair) {
            final isSelected = _chordA?.mlLabel == pair.labelA &&
                _chordB?.mlLabel == pair.labelB;
            return GestureDetector(
              onTap: () => _selectSuggestedPair(pair),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.greenAccent.withOpacity(0.15)
                      : const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.greenAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_outline,
                          size: 13, color: Colors.greenAccent),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      pair.display,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.greenAccent
                            : Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _diffDot(pair.difficulty),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
 
  Widget _filterChip(String label, Difficulty? value) {
    final selected = _diffFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _diffFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11,
              color: selected
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.4),
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    );
  }
 
  Widget _diffDot(Difficulty d) {
    final color = switch (d) {
      Difficulty.beginner     => Colors.greenAccent,
      Difficulty.intermediate => Colors.amber,
      Difficulty.advanced     => Colors.redAccent,
    };
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
 
 
  Widget _buildFreestylePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel('Custom Pair'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _freestyleMode = !_freestyleMode;
                if (!_freestyleMode) {
                  _chordA = null;
                  _chordB = null;
                }
                _loadPb();
              }),
              child: Text(
                _freestyleMode ? 'Cancel' : 'Pick manually',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (_freestyleMode) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _chordPicker(
                  label: 'Chord A',
                  selected: _chordA,
                  exclude: _chordB,
                  onSelected: (c) {
                    setState(() => _chordA = c);
                    _loadPb(); 
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.swap_horiz,
                    color: Colors.white.withOpacity(0.3), size: 22),
              ),
              Expanded(
                child: _chordPicker(
                  label: 'Chord B',
                  selected: _chordB,
                  exclude: _chordA,
                  onSelected: (c) {
                    setState(() => _chordB = c);
                    _loadPb(); 
                  },                              
                ),
              ),
            ],
          ),
        ] else if (_chordA != null && _chordB != null) ...[
          const SizedBox(height: 10),
          _buildSelectedPairPreview(),
        ],
      ],
    );
  }
 
  Widget _buildSelectedPairPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.greenAccent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, size: 14, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Text(
            'Selected: ',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.4)),
          ),
          Text(
            '${_chordA!.displayName}  →  ${_chordB!.displayName}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _chordA = null;
                _chordB = null;
              });
              _loadPb(); 
            },
            child: Icon(Icons.close,
                size: 16, color: Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
 
  Widget _chordPicker({
    required String label,
    required ChordData? selected,
    required ChordData? exclude,
    required ValueChanged<ChordData> onSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<ChordData>(
          context: context,
          backgroundColor: const Color(0xFF13131A),
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _ChordPickerSheet(
              exclude: exclude, practiceChords: _practiceChords),
        );
        if (result != null) onSelected(result);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected != null
                ? Colors.greenAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              selected?.displayName ?? 'Tap to choose',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected != null
                    ? Colors.white
                    : Colors.white.withOpacity(0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
 
  Widget _buildSessionConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Session Settings'),
        const SizedBox(height: 12),
 
        // BPM slider
        Row(
          children: [
            Text('BPM',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.6))),
            const SizedBox(width: 12),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.greenAccent,
                  inactiveTrackColor: Colors.white.withOpacity(0.08),
                  thumbColor: Colors.greenAccent,
                  overlayColor: Colors.greenAccent.withOpacity(0.1),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _bpm.toDouble(),
                  min: 40,
                  max: 160,
                  divisions: 120,
                  onChanged: (v) => setState(() => _bpm = v.round()),
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '$_bpm',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent),
              ),
            ),
          ],
        ),
 
        const SizedBox(height: 16),
 
        Row(
          children: [
            _toggleOption(
              label: 'Transitions',
              icon: Icons.swap_horiz,
              selected: _useTransitionCount,
              onTap: () => setState(() => _useTransitionCount = true),
            ),
            const SizedBox(width: 10),
            _toggleOption(
              label: 'Seconds',
              icon: Icons.timer_outlined,
              selected: !_useTransitionCount,
              onTap: () => setState(() => _useTransitionCount = false),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _targetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF13131A),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Colors.greenAccent, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _useTransitionCount ? 'transitions' : 'seconds',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.35)),
            ),
          ],
        ),
      ],
    );
  }
 
  Widget _toggleOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.greenAccent.withOpacity(0.12)
              : const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? Colors.greenAccent
                    : Colors.white.withOpacity(0.4)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.greenAccent
                    : Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  
 
  Widget _buildStartButton() {
    return AnimatedOpacity(
      opacity: _canStart ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 250),
      child: ElevatedButton(
        onPressed: _canStart ? _startDrill : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              _canStart
                  ? 'Start Drill  •  ${_chordA!.displayName} ↔ ${_chordB!.displayName}'
                  : 'Choose two chords to start',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 1.4),
      );
}
 

class _ChordPickerSheet extends StatelessWidget {
  final ChordData? exclude;
  final List<ChordData> practiceChords;
 
  const _ChordPickerSheet(
      {required this.exclude, required this.practiceChords});
 
  @override
  Widget build(BuildContext context) {
    final available =
        practiceChords.where((c) => c != exclude).toList();
 
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a chord',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available
                .map((c) => GestureDetector(
                      onTap: () => Navigator.pop(context, c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          c.displayName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

