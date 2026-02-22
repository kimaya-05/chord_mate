import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:chord_mate/dsp/dsp_engine.dart';

void main() {
  group('DSPEngine Tests', () {
    late DSPEngine dsp;
    const int sampleRate = 44100;
    const int N = 2048;

    setUp(() {
      dsp = DSPEngine(sampleRate: sampleRate, frameSize: N);
    });

    test('FFT Accuracy - Sine Wave', () {
      final double freq = 440.0; // A4
      final List<double> signal = List.generate(N, (n) {
        return sin(2 * pi * freq * n / sampleRate);
      });

      final windowed = dsp.applyWindow(signal);
      final fft = dsp.computeFFT(windowed);
      final detectedFreq = dsp.detectFrequency(fft);

      // With a 2048 point FFT at 44.1kHz, resolution is ~21.5Hz.
      // Parabolic interpolation should get us closer.
      expect(detectedFreq, closeTo(freq, 5.0));
    });

    test('Note Detection - A4, C4, E4', () {
      final notes = {
        'A4': 440.0,
        'C4': 261.63,
        'E4': 329.63,
      };

      notes.forEach((name, freq) {
        final List<double> signal = List.generate(N, (n) {
          return sin(2 * pi * freq * n / sampleRate);
        });

        final fft = dsp.computeFFT(dsp.applyWindow(signal));
        final detectedFreq = dsp.findFundamentalHPS(fft);
        final detectedNote = dsp.getPitchClass(detectedFreq);

        expect(detectedNote, equals(name.replaceAll(RegExp(r'\d'), '')));
      });
    });

    test('Chord Template Matching - C Major', () {
      // Synthesize C Major (C, E, G)
      final freqs = [261.63, 329.63, 392.00];
      final List<double> signal = List.generate(N, (n) {
        double val = 0;
        for (var f in freqs) {
          val += sin(2 * pi * f * n / sampleRate);
        }
        return val / freqs.length;
      });

      final fft = dsp.computeFFT(dsp.applyWindow(signal));
      final result = dsp.detectMultiNoteChord(fft);

      expect(result.chordName, contains('C Major'));
    });

    test('Noise Gate - Silence', () {
      final List<double> silence = List.filled(N, 0.001); // Below threshold (0.005)
      final frame = dsp.processAudioFrame(silence);

      expect(frame.samples.every((s) => s == 0), isTrue);
      expect(frame.fundamentalFreq, isNull);
    });

    test('Noise Gate - Signal', () {
      final List<double> signal = List.generate(N, (n) => 0.1 * sin(2 * pi * 440 * n / sampleRate));
      final frame = dsp.processAudioFrame(signal);

      expect(frame.samples.any((s) => s != 0), isTrue);
      expect(frame.fundamentalFreq, isNotNull);
    });

    test('dB Calculation Formula', () {
      // 1.0 (ref) should be 0 dB
      final stft = STFTResult(
        magnitude: [[1.0, 0.5, 0.1]],
        phase: [[0, 0, 0]],
        timeFrames: [0],
        frequencyBins: [0, 1, 2],
      );

      final db = stft.getMagnitudeDB(refLevel: 1.0);
      expect(db[0][0], closeTo(0.0, 0.001));
      expect(db[0][1], closeTo(-6.02, 0.01)); // 20 * log10(0.5)
      expect(db[0][2], closeTo(-20.0, 0.01)); // 20 * log10(0.1)
    });
  });
}
