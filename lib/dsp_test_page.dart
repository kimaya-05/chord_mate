import 'package:flutter/material.dart';
import 'services/audio_service.dart';
// import 'dsp/dsp_engine.dart';

// ─── Entry point (run this file directly to test) ───────────────────────────
void main() => runApp(const MaterialApp(home: DspTestPage()));

// ─── DSP Test Page ──────────────────────────────────────────────────────────

class DspTestPage extends StatefulWidget {
  const DspTestPage({super.key});

  @override
  State<DspTestPage> createState() => _DspTestPageState();
}

class _DspTestPageState extends State<DspTestPage> {
  // Audio Service
  final AudioService _audioService = AudioService();

  // Mic stream
  bool _isListening = false;
  String _statusMessage = 'Tap the mic button to start';

  // Live results
  String _detectedChord = '';
  String _detectedNote = '';
  String _mlPrediction = '';
  double _fundamentalFreq = 0;
  double _rmsLevel = 0;
  double _confidence = 0;
  int _framesProcessed = 0;
  double _latencyMs = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    // 1. Reset DSP state
    _audioService.resetDSP();

    // 2. Start audio service with DSP results
    final success = await _audioService.startWithDSP(_onDSPResult);

    if (success) {
      setState(() {
        _isListening = true;
        _statusMessage = '🎙️ Listening…';
      });
    } else {
      setState(() => _statusMessage = '❌ Failed to start audio service');
    }
  }

  Future<void> _stopListening() async {
    await _audioService.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Stopped. Tap to restart.';
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      if (mounted) {
        setState(() => _statusMessage = 'Starting…');
      }
      await _startListening();
    }
  }

  // ── Audio processing callback ───────────────────────────────────────────

  void _onDSPResult(DSPResult result) {
    if (!mounted) return;

    // Update UI on every result – stability / flicker prevention is now
    // handled entirely inside the DSP engine (candidate + committed filter).
    setState(() {
      _rmsLevel = result.rmsLevel;
      _fundamentalFreq = result.fundamentalFreq;
      _detectedNote = result.note;
      _detectedChord = result.chord;
      _mlPrediction = result.mlPrediction;
      _confidence = result.confidence;
      _framesProcessed = result.framesProcessed;
      _latencyMs = result.latencyMs;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DSP Engine Test')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Text(_statusMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // Live level bar
            _buildLabeledRow('RMS Level', _buildLevelBar()),
            const SizedBox(height: 16),

            // Frequency
            _buildLabeledRow(
              'Frequency',
              Text(
                _fundamentalFreq > 0
                    ? '${_fundamentalFreq.toStringAsFixed(1)} Hz'
                    : '—',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            _buildLabeledRow(
              'Note',
              Text(_detectedNote,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            // Chord
            _buildLabeledRow(
              'DSP Chord',
              Text(_detectedChord,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            const SizedBox(height: 12),

             // ML Chord
            _buildLabeledRow(
              'ML Chord',
              Text(_mlPrediction,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            const SizedBox(height: 12),

            // Confidence
            _buildLabeledRow(
              'Confidence',
              Text('${(_confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),

            // Frames processed
            _buildLabeledRow(
              'Frames',
              Text('$_framesProcessed',
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),

            // Latency
            _buildLabeledRow(
              'Latency',
              Text('${_latencyMs.toStringAsFixed(1)} ms',
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),

            const Spacer(),

            // Start / stop button
            SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _toggleListening,
                icon: Icon(_isListening ? Icons.stop : Icons.mic),
                label: Text(_isListening ? 'Stop' : 'Start Listening'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledRow(String label, Widget value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        Expanded(child: value),
      ],
    );
  }

  Widget _buildLevelBar() {
    // Clamp RMS to [0, 0.5] for visual bar
    double level = (_rmsLevel / 0.5).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: level,
        minHeight: 14,
        backgroundColor: Colors.grey[300],
        color: level > 0.8
            ? Colors.red
            : level > 0.4
                ? Colors.orange
                : Colors.green,
      ),
    );
  }
}
