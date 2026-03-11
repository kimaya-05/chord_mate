import 'dart:async';

class MetronomeService {
  Timer? _timer;
  bool _isPlaying = false;
  int _currentBpm = 60;
  
  dynamic _player;  // Avoid importing just_audio until needed
  final void Function(int beatNumber) onBeat;

  MetronomeService({required this.onBeat});

  bool get isPlaying => _isPlaying;
  int get currentBpm => _currentBpm;

  void start(int bpm) {
    if (_isPlaying) stop();
    
    _currentBpm = bpm;
    _isPlaying = true;
    
    final intervalMs = (60000 / bpm).round();
    
    // Trigger immediately on start
    _emitBeat(0);
    
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      final beatNumber = timer.tick;
      _emitBeat(beatNumber);
    });
  }

  void _emitBeat(int beatNumber) {
    // Try to play the loaded tick sound (fire and forget)
    _playTickSound();
    
    // Notify listeners immediately
    onBeat(beatNumber);
  }

  void _playTickSound() {
    try {
      // Lazy initialize the player - import just_audio only when needed
      if (_player == null) {
        // Dynamically import to avoid initialization issues
        return;  // For now, skip sound - haptic feedback will be used instead
      }
      
      // Fire and forget - don't block the beat callback
      _player.seek(Duration.zero);
      _player.play().catchError((e) {
        // Silently fail
      });
    } catch (e) {
      // Silently fail
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
  }
  
  void dispose() {
    stop();
    try {
      _player?.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }
  }
}
