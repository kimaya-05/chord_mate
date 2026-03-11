import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../dsp/dsp_engine.dart';
import '../ml/ml_classifier.dart';

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
  final double latencyMs;
  final String mlPrediction;
  final double mlConfidence;
  final OctaveResult? octaveResult; // New field for targets

  DSPResult({
    required this.rmsLevel,
    required this.fundamentalFreq,
    required this.note,
    required this.chord,
    required this.confidence,
    required this.framesProcessed,
    this.latencyMs = 0.0,
    this.mlPrediction = '',
    this.mlConfidence = 0.0,
    this.octaveResult,
  });
}

/// Callback for detailed DSP results
typedef DSPCallback = void Function(DSPResult result);

/// Audio service for capturing microphone input and processing audio
class AudioService {
  final DSPEngine _dsp = DSPEngine(enableDebugLogs: true);
  late final StreamingAudioState _audioState;
  final MLChordClassifier _mlClassifier = MLChordClassifier();
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<Uint8List> _recorderController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _recorderSubscription;
  bool _isInitialized = false;
  bool _isRecording = false;
  int _framesProcessed = 0;
  
  // ML spectrogram buffering
  final List<List<double>> _melSpectrogramBuffer = [];
  static const int melBands = 64;
  static const int spectrogramFrames = 128;
  
  // Configuration
  static const int sampleRate = 44100;
  
  // Last ML prediction state for UI persistence
  String _lastMLPrediction = 'Unknown';
  double _lastMLConfidence = 0.0;
  
  // Target tracking for Octave Practice Session
  String? _targetLow;
  String? _targetHigh;

  AudioService() {
    // ensure streaming buffer matches DSP engine frame/hop sizes
    _audioState = StreamingAudioState(frameSize: _dsp.frameSize, hopSize: _dsp.hopSize);
  }

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
      
      // Initialize ML classifier
      await _mlClassifier.initialize();

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

          OctaveResult? octaveRes;
          if (_targetLow != null && _targetHigh != null && frame.fftData != null && frame.fftData!.isNotEmpty) {
            octaveRes = _dsp.detectOctaveFromSpectrum(frame.fftData!, targetLow: _targetLow!, targetHigh: _targetHigh!);
          }

          // Compute ML prediction from FFT data
          if (frame.fftData != null && frame.fftData!.isNotEmpty) {
            // Convert FFT to mel-spectrogram frame (unnormalized power dB)
            List<double> melFrame = _fftToMelSpectrogram(frame.fftData!);
            _melSpectrogramBuffer.add(melFrame);

            // Keep only the latest spectrogramFrames
            if (_melSpectrogramBuffer.length > spectrogramFrames) {
              _melSpectrogramBuffer.removeAt(0);
            }

            // Create a padded copy for prediction if buffer is not full
            List<List<double>> predictionBuffer;
            if (_melSpectrogramBuffer.length < spectrogramFrames) {
              predictionBuffer = List.from(_melSpectrogramBuffer);
              int padCount = spectrogramFrames - _melSpectrogramBuffer.length;
              // Python pads at the end, but since this is real-time we just pad the unused frames
              for (int i = 0; i < padCount; i++) {
                 predictionBuffer.insert(0, List.filled(melBands, -80.0));
              }
            } else {
              predictionBuffer = _melSpectrogramBuffer;
            }

            // Normalize globally across the 128 frames (like librosa.power_to_db)
            double globalMaxDb = -80.0;
            for (var mFrame in predictionBuffer) {
              for (var val in mFrame) {
                if (val > globalMaxDb) globalMaxDb = val;
              }
            }

            List<List<double>> normalizedBuffer = predictionBuffer.map((mFrame) {
              return mFrame.map((val) {
                double normalized = val - globalMaxDb;
                return normalized < -80.0 ? -80.0 : normalized;
              }).toList();
            }).toList();

            final result = _getMLPredictionAndConfidence(normalizedBuffer);
            _lastMLPrediction = result['chord'] as String;
            _lastMLConfidence = result['confidence'] as double;
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
            latencyMs: _dsp.lastProcessingLatencyMs,
            mlPrediction: _lastMLPrediction,
            mlConfidence: _lastMLConfidence,
            octaveResult: octaveRes,
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

  // ============ ML Prediction Methods ============

  /// Convert FFT magnitude spectrum to mel-spectrogram frame
  List<double> _fftToMelSpectrogram(List<double> fftMagnitudes) {
    // Compute mel-frequency bands from FFT data
    List<double> melBins = List.filled(melBands, 0.0);

    // Create mel-filterbank
    for (int m = 0; m < melBands; m++) {
      // Python's librosa uses max frequency = sr/2. Since the model was trained 
      // on 16kHz audio, the max frequency used was 8000 Hz.
      double melLow = _hertzToMel(0.0);
      double melHigh = _hertzToMel(8000.0);

      double melCenter = melLow + (melHigh - melLow) * (m + 1) / (melBands + 1);
      double melLowerEdge = melLow + (melHigh - melLow) * m / (melBands + 1);
      double melUpperEdge = melLow + (melHigh - melLow) * (m + 2) / (melBands + 1);

      double freqCenter = _melToHertz(melCenter);
      double freqLower = _melToHertz(melLowerEdge);
      double freqUpper = _melToHertz(melUpperEdge);

      int binCenter = _frequencyToBin(freqCenter);
      int binLower = _frequencyToBin(freqLower);
      int binUpper = _frequencyToBin(freqUpper);

      double energy = 0.0;
      for (int k = binLower; k < binUpper && k < fftMagnitudes.length; k++) {
        double weight = 0.0;
        if (k < binCenter) {
          weight = (k - binLower) / max(1, binCenter - binLower);
        } else {
          weight = (binUpper - k) / max(1, binUpper - binCenter);
        }
        energy += weight * (fftMagnitudes[k] * fftMagnitudes[k]);
      }

      // Convert to log power (dB scale) equivalent to librosa.power_to_db(S) without normalization
      double dbValue = 10 * log(max(1e-10, energy)) / log(10);
      melBins[m] = dbValue;
    }

    return melBins;
  }

  /// Get ML prediction and confidence from mel-spectrogram buffer
  Map<String, dynamic> _getMLPredictionAndConfidence(List<List<double>> melSpectrogram) {
    if (!_mlClassifier.isInitialized) {
      return {'chord': '', 'confidence': 0.0};
    }

    // Run ML inference
    String prediction = _mlClassifier.classify(melSpectrogram);

    // For now, return confidence of 0.5 as a placeholder
    double confidence = prediction.isNotEmpty && prediction != 'Unknown' ? 0.6 : 0.0;

    return {'chord': prediction, 'confidence': confidence};
  }

  /// Convert Hz to Mel scale
  double _hertzToMel(double hz) {
    return 2595 * log(1 + hz / 700) / log(10);
  }

  /// Convert Mel to Hz
  double _melToHertz(double mel) {
    return 700 * (pow(10, mel / 2595) - 1);
  }

  /// Convert frequency to FFT bin index
  int _frequencyToBin(double frequency) {
    return (frequency * _dsp.frameSize / sampleRate).toInt();
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
    
    _mlClassifier.close();
    _isInitialized = false;
    _log('Audio service disposed');
  }

  /// Get status
  /// Get status
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
  int get framesProcessed => _framesProcessed;

  void setTargetOctave(String? low, String? high) {
    _targetLow = low;
    _targetHigh = high;
  }

  /// Reset DSP engine state
  void resetDSP() {
    _dsp.resetGainState();
    _audioState.reset();
    _framesProcessed = 0;
    _melSpectrogramBuffer.clear();
    _lastMLPrediction = 'Unknown';
    _lastMLConfidence = 0.0;
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
