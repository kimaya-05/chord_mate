import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../dsp/dsp_engine.dart';

/// Callback function for processing audio samples
typedef AudioCallback = void Function(List<double> samples);

/// Callback for chord detection results
typedef ChordCallback = void Function(MultiNoteDetectionResult chord);

/// Result of processing an audio frame
class DSPResult {
  final double rmsLevel;
  final double fundamentalFreq;
  final String note;
  final String chord;
  final double confidence;
  final int framesProcessed;

  DSPResult({
    required this.rmsLevel,
    required this.fundamentalFreq,
    required this.note,
    required this.chord,
    required this.confidence,
    required this.framesProcessed,
  });
}

/// Callback for detailed DSP results
typedef DSPCallback = void Function(DSPResult result);

/// Audio service for capturing microphone input and processing audio
class AudioService {
  final DSPEngine _dsp = DSPEngine();
  final StreamingAudioState _audioState = StreamingAudioState(frameSize: 2048, hopSize: 512);
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<Uint8List> _recorderController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _recorderSubscription;
  bool _isInitialized = false;
  bool _isRecording = false;
  int _framesProcessed = 0;
  
  // Configuration
  static const int sampleRate = 44100;

  AudioService();

  /// Initialize audio service and request permissions
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _log('Microphone permission denied');
        return false;
      }

      await _recorder.openRecorder();

      _isInitialized = true;
      _log('Audio service initialized (flutter_sound)');
      return true;
    } catch (e) {
      _log('Error initializing audio service: $e');
      return false;
    }
  }

  /// Start recording with audio callback
  Future<bool> start(AudioCallback onAudio) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) return false;
    }

    if (_isRecording) {
      _log('Already recording');
      return false;
    }

    try {
      _audioState.reset();

      if (!_recorder.isRecording) {
        await _recorder.startRecorder(
          toStream: _recorderController.sink,
          codec: Codec.pcm16,
          sampleRate: sampleRate,
          numChannels: 1,
        );
      }

      _recorderSubscription = _recorderController.stream.listen(
        (Uint8List data) {
          try {
            final samples = _pcm16ToDoubles(data);
            if (samples.isNotEmpty) {
              onAudio(samples);
            }
          } catch (e) {
            _log('Error processing recorder data: $e');
          }
        },
        onError: (error) {
          _log('Recorder stream error: $error');
          _handleStreamError();
        },
        cancelOnError: false,
      );

      _isRecording = true;
      _log('Recording started (flutter_sound)');
      return true;
    } catch (e) {
      _log('Error starting recording: $e');
      return false;
    }
  }

  /// Start recording with detailed DSP results
  Future<bool> startWithDSP(DSPCallback onResult) async {
    return await start((samples) {
      final readyFrames = _audioState.addSamples(samples);
      for (final frameData in readyFrames) {
        final frame = _dsp.processAudioFrame(frameData);
        if (frame.isComplete) {
          _framesProcessed++;
          
          MultiNoteDetectionResult chordResult = MultiNoteDetectionResult.empty();
          if (frame.fftData != null && frame.fftData!.isNotEmpty) {
            chordResult = _dsp.detectMultiNoteChord(frame.fftData!);
          }

          onResult(DSPResult(
            rmsLevel: frame.rmsEnergy,
            fundamentalFreq: frame.fundamentalFreq ?? 0,
            note: frame.fundamentalFreq != null && frame.fundamentalFreq! > 0
                ? _dsp.frequencyToNote(frame.fundamentalFreq!)
                : '—',
            chord: chordResult.chordName,
            confidence: chordResult.confidence,
            framesProcessed: _framesProcessed,
          ));
        }
      }
    });
  }

  /// Start recording with real-time chord detection (Legacy support)
  Future<bool> startWithChordDetection(
    AudioCallback onAudio,
    ChordCallback onChord,
  ) async {
    return await start((samples) {
      onAudio(samples);
      
      // Secondary processing for chords
      final readyFrames = _audioState.addSamples(samples);
      for (final frameData in readyFrames) {
        final frame = _dsp.processAudioFrame(frameData);
        if (frame.isComplete) {
          final chord = _dsp.detectMultiNoteChord(frame.fftData ?? []);
          onChord(chord);
        }
      }
    });
  }

  /// Stop recording
  Future<bool> stop() async {
    if (!_isRecording) return false;

    try {
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      if (_recorder.isRecording) await _recorder.stopRecorder();

      _isRecording = false;
      _log('Recording stopped (flutter_sound)');
      return true;
    } catch (e) {
      _log('Error stopping recording: $e');
      return false;
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stop();
    try {
      await _recorder.closeRecorder();
    } catch (_) {}
    try {
      await _recorderController.close();
    } catch (_) {}

    _isInitialized = false;
    _log('Audio service disposed');
  }

  /// Get status
  /// Get status
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
  int get framesProcessed => _framesProcessed;

  /// Reset DSP engine state
  void resetDSP() {
    _dsp.resetGainState();
    _audioState.reset();
    _framesProcessed = 0;
  }

  // ============ Private Methods ============

  /// Convert PCM16 byte array to double samples (-1.0 to 1.0)
  List<double> _pcm16ToDoubles(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final out = List<double>.filled(count, 0);
    for (int i = 0; i < count; i++) {
      int lo = bytes[i * 2];
      int hi = bytes[i * 2 + 1];
      int pcm = lo | (hi << 8);
      if (pcm >= 32768) pcm -= 65536;
      out[i] = pcm / 32768.0;
    }
    return out;
  }

  void _handleStreamError() {
    // Simple retry logic
    if (_isRecording) {
      _log('Attempting to restart recorder stream after error...');
      stop().then((_) {
        // Wait a bit before restarting
        Future.delayed(const Duration(seconds: 1), () {
          // Note: we can't easily restart with the same callback here without saving it
          // In production, this would be managed by a higher-level state machine or saved callback
          _log('Manual restart required or implement callback preservation');
        });
      });
    }
  }

  void _log(String message) {
    stderr.writeln('[AudioService] $message');
  }
}
