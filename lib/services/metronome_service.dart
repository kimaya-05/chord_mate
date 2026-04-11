import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

class MetronomeService {
  Timer? _timer;
  bool _isPlaying = false;
  int _currentBpm = 60;
  int _beatCount = 0;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerReady = false;

  final void Function(int beatNumber) onBeat;

  MetronomeService({required this.onBeat});

  bool get isPlaying => _isPlaying;
  int get currentBpm => _currentBpm;

  // ── Init (call once, e.g. in your State's initState) ──────────────────────

  Future<void> init() async {
    await _player.openPlayer();
    _playerReady = true;
  }

  // ── Start / Stop ───────────────────────────────────────────────────────────

  void start(int bpm) {
    if (_isPlaying) stop();
    _currentBpm = bpm;
    _isPlaying  = true;
    _beatCount  = 0;

    final interval = Duration(milliseconds: (60000 / bpm).round());

    _emitBeat(0); // fire immediately on start
    _timer = Timer.periodic(interval, (t) => _emitBeat(t.tick));
  }

  void stop() {
    _timer?.cancel();
    _timer     = null;
    _isPlaying = false;
    _beatCount = 0;
  }

  Future<void> dispose() async {
    stop();
    if (_playerReady) {
      await _player.closePlayer();
      _playerReady = false;
    }
  }

  // ── Beat emission ──────────────────────────────────────────────────────────

  void _emitBeat(int tick) {
    // Accent every other beat (chord-change downbeat)
    final bool accent = (_beatCount % 2) == 0;
    _beatCount++;

    _playClick(accent: accent); // fire-and-forget
    onBeat(tick);
  }

  // ── PCM click synthesis ────────────────────────────────────────────────────

  static const int    _sampleRate = 22050;
  static const int    _clickMs    = 12;
  static const double _freqNormal = 1000.0;
  static const double _freqAccent = 1400.0;

  Uint8List _buildClick({required bool accent}) {
    final int numSamples = (_sampleRate * _clickMs ~/ 1000);
    final data = Int16List(numSamples);
    final double freq      = accent ? _freqAccent : _freqNormal;
    final double amplitude = accent ? 28000.0 : 20000.0;

    for (int i = 0; i < numSamples; i++) {
      final double t        = i / _sampleRate;
      final double envelope = math.exp(-t * 350.0); // sharp exponential decay
      data[i] = (math.sin(2 * math.pi * freq * t) * envelope * amplitude)
          .round()
          .clamp(-32768, 32767);
    }
    return data.buffer.asUint8List();
  }

  Future<void> _playClick({required bool accent}) async {
    if (!_playerReady) return;
    try {
      final pcm = _buildClick(accent: accent);
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _sampleRate,
        interleaved: true,
        bufferSize: 512,
      );
      await _player.feedFromStream(pcm);
      await Future.delayed(const Duration(milliseconds: _clickMs + 8));
      await _player.stopPlayer();
    } catch (_) {
      // Never let audio errors break the beat timer
    }
  }
}