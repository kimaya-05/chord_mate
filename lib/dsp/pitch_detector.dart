import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// YIN Pitch Detector
//
// Implements the YIN algorithm (de Cheveigné & Kawahara, 2002) for accurate
// monophonic fundamental frequency detection.
//
// Designed specifically for guitar tuning:
//   - Handles the full guitar range (E2 = 82 Hz … e4 = 330 Hz)
//   - Robust to octave errors via the cumulative mean normalised difference
//   - No external dependencies — pure Dart
// ─────────────────────────────────────────────────────────────────────────────

class PitchDetector {
  final int    sampleRate;
  final int    frameSize;

  /// YIN threshold — lower = more selective (miss more notes),
  /// higher = more detections but more octave errors.
  /// 0.10–0.15 is the sweet spot for acoustic guitar.
  final double threshold;

  /// Minimum and maximum fundamental frequency accepted (Hz).
  final double minFreqHz;
  final double maxFreqHz;

  /// Result of a single pitch detection frame.
  PitchResult? _lastResult;

  PitchDetector({
    this.sampleRate = 44100,
    this.frameSize  = 4096,
    this.threshold  = 0.12,
    this.minFreqHz  = 70.0,   // below low E2 (82 Hz) with some headroom
    this.maxFreqHz  = 400.0,  // above high e4 (330 Hz) with some headroom
  });

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Analyse one frame of audio samples (range −1.0 … +1.0).
  /// Returns null when no reliable pitch is found (silence / noise).
  PitchResult? detect(List<double> samples) {
    if (samples.length < frameSize) return null;

    final frame = samples.length == frameSize
        ? samples
        : samples.sublist(0, frameSize);

    // Quick RMS gate — skip silent frames immediately
    final rms = _rms(frame);
    if (rms < 0.008) return null;

    // ── Step 1 & 2: difference function + cumulative mean normalisation ──────
    final minLag = (sampleRate / maxFreqHz).floor().clamp(1, frameSize ~/ 2);
    final maxLag = (sampleRate / minFreqHz).ceil().clamp(minLag + 1, frameSize ~/ 2);

    final diff = _differenceFunction(frame, maxLag);
    final cmnd = _cumulativeMeanNormalisedDifference(diff);

    // ── Step 3: absolute threshold — find first dip below threshold ──────────
    int? bestLag;
    for (int lag = minLag; lag <= maxLag; lag++) {
      if (cmnd[lag] < threshold) {
        // Look ahead for a lower local minimum
        bestLag = lag;
        while (lag + 1 <= maxLag && cmnd[lag + 1] < cmnd[lag]) {
          lag++;
          bestLag = lag;
        }
        break;
      }
    }

    // If no dip found, fall back to the global minimum (less reliable)
    if (bestLag == null) {
      double minVal = double.infinity;
      for (int lag = minLag; lag <= maxLag; lag++) {
        if (cmnd[lag] < minVal) {
          minVal = cmnd[lag];
          bestLag = lag;
        }
      }
      // Reject if even the global min is far above threshold
      if (minVal > threshold * 2.5) return null;
    }

    if (bestLag == null || bestLag == 0) return null;

    // ── Step 4: parabolic interpolation for sub-sample precision ─────────────
    final double refinedLag = _parabolicInterpolation(cmnd, bestLag, minLag, maxLag);
    if (refinedLag <= 0) return null;

    final double frequency = sampleRate / refinedLag;
    if (frequency < minFreqHz || frequency > maxFreqHz) return null;

    // Confidence — invert the CMND dip value (lower dip = higher confidence)
    final double confidence = (1.0 - cmnd[bestLag]).clamp(0.0, 1.0);

    _lastResult = PitchResult(
      frequency:  frequency,
      confidence: confidence,
      rms:        rms,
    );
    return _lastResult;
  }

  PitchResult? get lastResult => _lastResult;

  // ── YIN internals ──────────────────────────────────────────────────────────

  /// YIN step 2: difference function
  /// d(τ) = Σ (x[t] − x[t+τ])²  for t = 0 … W/2
  List<double> _differenceFunction(List<double> frame, int maxLag) {
    final int W = frame.length ~/ 2; // use half the frame for τ search
    final diff = List<double>.filled(maxLag + 1, 0.0);

    // diff[0] is always 0 by definition but we leave it as 0.
    for (int lag = 1; lag <= maxLag; lag++) {
      double sum = 0.0;
      for (int t = 0; t < W; t++) {
        final double delta = frame[t] - frame[t + lag];
        sum += delta * delta;
      }
      diff[lag] = sum;
    }
    return diff;
  }

  /// YIN step 3: cumulative mean normalised difference function
  /// d'(τ) = 1                            if τ = 0
  ///       = d(τ) / [(1/τ) Σ_{j=1}^{τ} d(j)]  otherwise
  List<double> _cumulativeMeanNormalisedDifference(List<double> diff) {
    final cmnd = List<double>.filled(diff.length, 0.0);
    cmnd[0] = 1.0; // conventional value
    double runningSum = 0.0;

    for (int lag = 1; lag < diff.length; lag++) {
      runningSum += diff[lag];
      if (runningSum == 0.0) {
        cmnd[lag] = 1.0;
      } else {
        cmnd[lag] = diff[lag] * lag / runningSum;
      }
    }
    return cmnd;
  }

  /// YIN step 5: parabolic interpolation around the best lag peak.
  double _parabolicInterpolation(
      List<double> cmnd, int lag, int minLag, int maxLag) {
    if (lag <= minLag || lag >= maxLag) return lag.toDouble();

    final double ym1 = cmnd[lag - 1];
    final double y0  = cmnd[lag];
    final double yp1 = cmnd[lag + 1];

    final double denom = ym1 - 2.0 * y0 + yp1;
    if (denom == 0.0) return lag.toDouble();

    final double shift = 0.5 * (ym1 - yp1) / denom;
    // Clamp to ±1 sample so we never jump too far
    return lag + shift.clamp(-1.0, 1.0);
  }

  double _rms(List<double> samples) {
    double sum = 0.0;
    for (final s in samples) sum += s * s;
    return sqrt(sum / samples.length);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PitchResult
// ─────────────────────────────────────────────────────────────────────────────

class PitchResult {
  /// Detected fundamental frequency in Hz.
  final double frequency;

  /// Confidence 0.0–1.0 (higher = more reliable).
  final double confidence;

  /// RMS level of the frame (useful for noise-gating in the UI).
  final double rms;

  const PitchResult({
    required this.frequency,
    required this.confidence,
    required this.rms,
  });

  @override
  String toString() =>
      'PitchResult(${frequency.toStringAsFixed(2)} Hz, '
      'conf=${confidence.toStringAsFixed(2)}, '
      'rms=${rms.toStringAsFixed(4)})';
}