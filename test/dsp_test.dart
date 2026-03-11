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

      // After simplification, C Major becomes 'C'
      expect(result.chordName, equals('C'));
    });

    test('Chord Classification - E Major (was misclassified as B)', () {
      // E Major: E4=329.63, G#4=415.30, B4=493.88
      final freqs = [329.63, 415.30, 493.88];
      final List<double> signal = List.generate(N, (n) {
        double val = 0;
        for (var f in freqs) {
          val += sin(2 * pi * f * n / sampleRate);
        }
        return val / freqs.length;
      });
      final fft = dsp.computeFFT(dsp.applyWindow(signal));
      // Feed 6 identical frames so the stability filter commits.
      late MultiNoteDetectionResult result;
      for (int i = 0; i < 6; i++) {
        result = dsp.detectMultiNoteChord(fft);
      }
      expect(result.chordName, equals('E'));
    });

    test('Chord Classification - F Major (was misclassified as C)', () {
      // F Major: F4=349.23, A4=440.00, C5=523.25
      final freqs = [349.23, 440.00, 523.25];
      final List<double> signal = List.generate(N, (n) {
        double val = 0;
        for (var f in freqs) {
          val += sin(2 * pi * f * n / sampleRate);
        }
        return val / freqs.length;
      });
      final fft = dsp.computeFFT(dsp.applyWindow(signal));
      late MultiNoteDetectionResult result;
      for (int i = 0; i < 6; i++) {
        result = dsp.detectMultiNoteChord(fft);
      }
      expect(result.chordName, equals('F'));
    });

    test('Chord Classification - A Major (was misclassified as A minor)', () {
      // A Major: A4=440.00, C#5=554.37, E5=659.25
      final freqs = [440.00, 554.37, 659.25];
      final List<double> signal = List.generate(N, (n) {
        double val = 0;
        for (var f in freqs) {
          val += sin(2 * pi * f * n / sampleRate);
        }
        return val / freqs.length;
      });
      final fft = dsp.computeFFT(dsp.applyWindow(signal));
      late MultiNoteDetectionResult result;
      for (int i = 0; i < 6; i++) {
        result = dsp.detectMultiNoteChord(fft);
      }
      expect(result.chordName, equals('A'));
    });

    test('Stability Filter - chord only committed after stabilityThreshold frames', () {
      // Generate an E-major FFT
      final freqs = [329.63, 415.30, 493.88];
      final List<double> signal = List.generate(N, (n) {
        double val = 0;
        for (var f in freqs) {
          val += sin(2 * pi * f * n / sampleRate);
        }
        return val / freqs.length;
      });
      final fft = dsp.computeFFT(dsp.applyWindow(signal));

      // Feed 4 frames (below threshold of 5) – committed chord may still be empty/unknown.
      for (int i = 0; i < 4; i++) {
        dsp.detectMultiNoteChord(fft);
      }
      final beforeThreshold = dsp.detectMultiNoteChord(fft); // 5th frame triggers commit

      // After 5 identical frames, the chord should be committed.
      expect(beforeThreshold.chordName, isNot(equals('Unknown')));
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

  group('Chord Simplification - simplifyChordName()', () {
    test('Major variants collapse to root', () {
      expect(simplifyChordName('C Major'), equals('C'));
      expect(simplifyChordName('D Dominant7'), equals('D'));
      expect(simplifyChordName('D MajorSeventh'), equals('D'));
      expect(simplifyChordName('D Sus4'), equals('D'));
      expect(simplifyChordName('D Sus2'), equals('D'));
      expect(simplifyChordName('E Augmented'), equals('E'));
    });

    test('Minor/dim variants collapse to root minor', () {
      expect(simplifyChordName('C Minor'), equals('C minor'));
      expect(simplifyChordName('A Diminished'), equals('A minor'));
      expect(simplifyChordName('B MinorSeventh'), equals('B minor'));
    });

    test('Sharp roots mapped to nearest natural', () {
      expect(simplifyChordName('C# Major'), equals('C'));
      expect(simplifyChordName('D# Minor'), equals('E minor'));
      expect(simplifyChordName('F# Major'), equals('G'));
      expect(simplifyChordName('G# Minor'), equals('A minor'));
      expect(simplifyChordName('A# Major'), equals('B'));
    });

    test('Ambiguous result uses best candidate', () {
      // e.g. "C Major / C Minor (ambiguous)" → pick C Major → 'C'
      expect(simplifyChordName('C Major / C Minor (ambiguous)'), equals('C'));
    });

    test('Unknown input is returned unchanged', () {
      expect(simplifyChordName('Unknown'), equals('Unknown'));
      expect(simplifyChordName(''), equals(''));
    });
  });
}
