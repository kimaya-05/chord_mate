import 'dart:math';

const Map<String, double> noteFrequencies = {
  'C': 261.63, 'C#': 277.18, 'D': 293.66, 'D#': 311.13,
  'E': 329.63, 'F': 349.23, 'F#': 369.99, 'G': 392.00,
  'G#': 415.30, 'A': 440.00, 'A#': 466.16, 'B': 493.88,
};

const Map<String, List<int>> chordTemplates = {
  'Major': [0, 4, 7],
  'Minor': [0, 3, 7],
  'Dominant7': [0, 4, 7, 10],
  'MajorSeventh': [0, 4, 7, 11],
  'MinorSeventh': [0, 3, 7, 10],
  'Diminished': [0, 3, 6],
  'Augmented': [0, 4, 8],   
  'Sus2': [0, 2, 7],
  'Sus4': [0, 5, 7],
};

const List<String> noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F',
  'F#', 'G', 'G#', 'A', 'A#', 'B'
];

String simplifyChordName(String rawName) {
  if (rawName.isEmpty || rawName == 'Unknown') return rawName;

  // If ambiguous (e.g. "Am / C"), take the first option only.
  String name = rawName.contains(' / ')
      ? rawName.split(' / ').first.trim()
      : rawName;

  final rootMatch = RegExp(r'^([A-G]#?)').firstMatch(name);
  if (rootMatch == null) return rawName;
  final String root = rootMatch.group(1)!;

  // Extract the chord type (everything after the root note).
  final String type = name.substring(rootMatch.end).trim();

  // Decide major vs minor before any enharmonic mapping so we don't
  // lose the minor quality when collapsing sharps.
  final bool isMinor = type.startsWith('Minor') ||
      type.startsWith('Dim') ||
      type.startsWith('Diminished');

  // Map sharp roots to the nearest natural note that matches one of the
  // 14 practice chords: A Am B Bm C Cm D Dm E Em F Fm G Gm.
  //
  // Major sharps → nearest natural major:  C#→C  D#→E  F#→G  G#→A  A#→B
  // Minor sharps → nearest natural minor:  C#m→Cm D#m→Em F#m→Gm G#m→Am A#m→Bm
  const Map<String, String> sharpMajor = {
    'C#': 'C', 'D#': 'E', 'F#': 'G', 'G#': 'A', 'A#': 'B',
  };
  const Map<String, String> sharpMinor = {
    'C#': 'C', 'D#': 'E', 'F#': 'G', 'G#': 'A', 'A#': 'B',
  };

  final String naturalRoot = isMinor
      ? (sharpMinor[root] ?? root)
      : (sharpMajor[root] ?? root);

  return isMinor ? '$naturalRoot minor' : naturalRoot;
}

const double ln2 = 0.693147180559945;
const double a4Frequency = 440.0;
const int a4Midi = 69;

// ============ Streaming Buffer for Real-Time Processing ============

/// Circular buffer for streaming audio from microphone
class StreamingBuffer {
  final List<double> buffer;
  final int frameSize;
  final int hopSize;
  int _writeIndex = 0;
  int _frameCount = 0;
  // bool _frameReady = false;

  StreamingBuffer({
    required this.frameSize,
    this.hopSize = 512,  // Add hopSize parameter
  }) : buffer = List.filled(frameSize, 0.0);

  /// Add samples to buffer, returns complete frames when ready
  List<AudioFrame> addSamples(List<double> newSamples) {
    List<AudioFrame> frames = [];
    
    for (double sample in newSamples) {
      buffer[_writeIndex] = sample;
      _writeIndex++;
      
      // Check if we have a complete frame
      if (_writeIndex >= frameSize) {
        // Create a copy of the frame
        frames.add(AudioFrame(
          samples: List<double>.from(buffer),
          frameIndex: _frameCount,
          isComplete: true,
        ));
        _frameCount++;
        
        // Shift buffer for overlap (keep hopSize samples for next frame)
        if (hopSize < frameSize) {
          // Keep the last hopSize samples for next frame
          int keepSamples = hopSize;
          int shiftAmount = frameSize - keepSamples;
          
          // Shift the last keepSamples to the beginning
          for (int i = 0; i < keepSamples; i++) {
            buffer[i] = buffer[shiftAmount + i];
          }
          _writeIndex = keepSamples;
        } else {
          // If hopSize >= frameSize, just reset
          _writeIndex = 0;
        }
      }
    }
    
    return frames;
  }

  void clear() {
    _writeIndex = 0;
    _frameCount = 0;
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = 0.0;
    }
  }
}

// ============ DSP Engine ============

/// DSP Engine for real-time audio analysis with frame-based processing
class DSPEngine {
  final int sampleRate;
  final int frameSize;
  final int hopSize;

  static const int noteOctave = 4;
  int _frameCounter = 0;
  
  // Gain control constants
  static const double minAcceptableLevel = 0.01;  // -40 dB
  static const double maxAcceptableLevel = 0.5;   // -6 dB
  static const double targetLevel = 0.2;
  static const double gainSmoothingFactor = 0.7;
  static const double maxGain = 10.0;
  static const double minGain = 0.1;
  
  // Gain control state
  late double _recentPeakLevel = 0.0;
  late double _currentGain = 1.0;

  // Chromagram & smoothing state
  final int chromaBins = 12;
  final int smoothingWindowMs;
  final double chromaThreshold; // relative threshold (0..1)
  final List<List<double>> _chromaBuffer = [];
  final bool enableDebugLogs;

  // Rolling window for octave detection (fundamental + octave harmonic)
  final int octaveWindowMs;
  final List<_OctavePair> _octaveHistory = [];

  // Chroma / chord detection frequency focus (acoustic guitar friendly)
  // - Below ~55 Hz is mostly rumble; above a few kHz is mostly pick noise/brightness
  static const double _minChordFreqHz = 55.0;
  static const double _maxChordFreqHz = 2200.0;
  static const int _maxChromaPeaks = 36;
  static const int _harmonicFoldMax = 6;
  
  // Chord stability tracking & latency measurement
  String _lastChordName = '';
  int _chordStabilityCounter = 0;
  final int stabilityThreshold = 3;  // require 3 consecutive same chords
  double _lastChordScore = 0.0;
  double _lastProcessingLatencyMs = 0.0;

  double get lastProcessingLatencyMs => _lastProcessingLatencyMs;

  void _log(String msg) {
    if (enableDebugLogs) print('[DSPEngine] $msg');
  }
  int get _chromaBufferMaxFrames {
    // frames = smoothingMs / (hopSize / sampleRate * 1000)
    double hopMs = hopSize / sampleRate * 1000.0;
    int frames = (smoothingWindowMs / max(hopMs, 1)).round();
    return max(1, frames);
  }

  int get _octaveBufferMaxFrames {
    // frames ≈ windowMs / hopDurationMs
    double hopMs = hopSize / sampleRate * 1000.0;
    int frames = (octaveWindowMs / max(hopMs, 1)).round();
    return max(1, frames);
  }

  DSPEngine({
    this.sampleRate = 44100,
    this.frameSize = 4096,
    this.hopSize = 1024,
    this.smoothingWindowMs = 300,
    this.chromaThreshold = 0.07, // Lowered threshold for better third detection
    this.enableDebugLogs = false,
    this.octaveWindowMs = 300,
  });

  /// Validates signal before processing
  bool _validateSignal(List<double> signal) {
    return signal.isNotEmpty && signal.every((v) => v.isFinite);
  }

  /// Apply Hamming window for spectral leakage reduction
  List<double> applyWindow(List<double> signal) {
    if (!_validateSignal(signal)) return [];
    int N = signal.length;
    return List.generate(N, (n) {
      double w = 0.54 - 0.46 * cos(2 * pi * n / (N - 1));
      return signal[n] * w;
    });
  }

  /// Apply Hann window (alternative to Hamming)
  List<double> applyHannWindow(List<double> signal) {
    if (!_validateSignal(signal)) return [];
    int N = signal.length;
    return List.generate(N, (n) {
      double w = 0.5 * (1 - cos(2 * pi * n / (N - 1)));
      return signal[n] * w;
    });
  }

  /// Apply Blackman window (lowest spectral leakage)
  List<double> _applyBlackmanWindow(List<double> signal) {
    int N = signal.length;
    return List.generate(N, (n) {
      double w = 0.42 - 0.5 * cos(2 * pi * n / (N - 1)) +
          0.08 * cos(4 * pi * n / (N - 1));
      return signal[n] * w;
    });
  }

  /// Normalize signal to [-1, 1] range for better analysis
  List<double> normalize(List<double> signal) {
    if (!_validateSignal(signal)) return [];
    double maxVal = signal.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return signal;
    return signal.map((v) => v / maxVal).toList();
  }

  // ============ Frame-Based Audio Streaming ============

  /// Process a single audio frame from microphone stream
  /// Process a single audio frame from microphone stream with gain control
  /// Process a single audio frame from microphone stream with gain control
  AudioFrame processAudioFrame(List<double> audioData) {
    if (audioData.length < frameSize) {
      return AudioFrame(
        samples: audioData,
        frameIndex: _frameCounter,  // Use current counter even for incomplete frames
        isComplete: false,
      );
    }

    // Extract the frame
    List<double> frame = audioData.sublist(0, frameSize);

    // ── Start latency timer ──────────────────────────────────────────────────
    final sw = Stopwatch()..start();

    // Check if we need gain adjustment BEFORE windowing
    bool needsGain = _needsGainAdjustment(frame);
    
    // Apply gain control if needed
    List<double> processedFrame = frame;
    if (needsGain) {
      processedFrame = applyAutomaticGainControl(frame);
    }
    
    // Apply window function
    List<double> windowed = applyWindow(processedFrame);
    
    // Compute FFT for immediate use if needed
    List<double> fft = computeFFT(windowed);
    // Log raw amplitude values
    double rawPeak = frame.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    double rawRmsLog = sqrt(frame.fold<double>(0.0, (a, b) => a + b * b) / frame.length);
    _log('RawPeak=${rawPeak.toStringAsFixed(5)}, RawRMS=${rawRmsLog.toStringAsFixed(5)}');
    
    // Detect fundamental frequency (optional, can be done later)
    double fundamentalFreq = 0;
    if (fft.isNotEmpty) {
      fundamentalFreq = findFundamentalHPS(fft);
    }

    // Log FFT peaks (top 5)
    if (fft.isNotEmpty) {
      List<PeakData> fftPeaks = findPeaks(fft, threshold: 0.02);
      int topN = min(5, fftPeaks.length);
      if (topN > 0) {
        String peaks = fftPeaks.take(topN).map((p) => '${p.frequency.toStringAsFixed(1)}Hz(${p.magnitude.toStringAsFixed(3)})').join(', ');
        _log('FFT Peaks: $peaks');
      }
    }

    // Simple noise gate: if raw RMS is below threshold, zero the frame
    const double noiseGateThreshold = 0.005;
    double rawRms = 0;
    if (frame.isNotEmpty) {
      rawRms = sqrt(frame.fold<double>(0.0, (a, b) => a + b * b) / frame.length);
    }

    // ── Stop timer and record latency ────────────────────────────────────────
    sw.stop();
    _lastProcessingLatencyMs = sw.elapsedMicroseconds / 1000.0;

    if (rawRms < noiseGateThreshold) {
      // Return an explicitly zeroed frame for downstream tests/consumers
      AudioFrame noisy = AudioFrame(
        samples: List.filled(frameSize, 0.0),
        frameIndex: _frameCounter,
        isComplete: true,
        rawFrame: frame,
        fftData: [],
        fundamentalFreq: null,
        gainApplied: needsGain,
        gainValue: _currentGain,
      );
      _frameCounter++;
      return noisy;
    }

    // Create frame with current counter, then increment
    AudioFrame result = AudioFrame(
      samples: windowed,
      frameIndex: _frameCounter,  // Use current counter value
      isComplete: true,
      rawFrame: frame,
      fftData: fft,
      fundamentalFreq: fundamentalFreq > 0 ? fundamentalFreq : null,
      gainApplied: needsGain,
      gainValue: _currentGain,
    );
    
    // Increment counter for next frame
    _frameCounter++;
    
    return result;
  }

  // ============ FFT Implementation ============

  /// Cooley-Tukey Radix-2 FFT (O(n log n) - much faster than naive DFT)
  List<Complex> _fft(List<Complex> signal) {
    int N = signal.length;
    if (N == 1) return signal;
    if (N % 2 != 0) return _naiveDFT(signal);

    // Divide
    List<Complex> even = [], odd = [];
    for (int i = 0; i < N; i += 2) {
      even.add(signal[i]);
      odd.add(signal[i + 1]);
    }

    // Conquer
    List<Complex> evenFFT = _fft(even);
    List<Complex> oddFFT = _fft(odd);

    // Combine
    List<Complex> result = List.filled(N, Complex(0, 0));
    for (int k = 0; k < N ~/ 2; k++) {
      double angle = -2 * pi * k / N;
      Complex w = Complex(cos(angle), sin(angle));
      Complex t = w * oddFFT[k];
      result[k] = evenFFT[k] + t;
      result[k + N ~/ 2] = evenFFT[k] - t;
    }
    return result;
  }

  /// Naive DFT for non-power-of-2 lengths
  List<Complex> _naiveDFT(List<Complex> signal) {
    int N = signal.length;
    List<Complex> result = [];
    for (int k = 0; k < N; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        double angle = 2 * pi * k * n / N;
        real += signal[n].real * cos(angle) - signal[n].imag * sin(angle);
        imag += signal[n].real * sin(angle) + signal[n].imag * cos(angle);
      }
      result.add(Complex(real, imag));
    }
    return result;
  }

  /// Compute FFT spectrum (returns magnitudes)
  List<double> computeFFT(List<double> signal) {
    if (!_validateSignal(signal)) return [];
    int N = signal.length;

    int padded = 1 << (log(N) / log(2)).ceil();
    List<Complex> complexSignal = List.filled(padded, Complex(0, 0));
    for (int i = 0; i < N; i++) {
      complexSignal[i] = Complex(signal[i], 0);
    }

    List<Complex> fftResult = _fft(complexSignal);
    return List.generate(padded ~/ 2, (k) {
      return fftResult[k].magnitude / padded * 2;
    });
  }

  /// Get frequency bins (Hz values for each bin)
  List<double> getFrequencyBins(int spectrumLength) {
    double resolution = sampleRate / (spectrumLength * 2);
    return List.generate(spectrumLength, (i) => i * resolution);
  }

  // ============ Harmonic Product Spectrum (HPS) ============

  /// Compute harmonic product spectrum for robust fundamental detection
  /// Multiplies spectrum by downsampled versions to find fundamental
  List<double> harmonicProductSpectrum(
    List<double> magnitudes, {
    int maxHarmonics = 5,
  }) {
    if (magnitudes.isEmpty) return [];

    final int N = magnitudes.length;
    // Work in log-magnitude to prevent exponential blow-up of harmonics.
    final List<double> logMag = magnitudes
        .map((v) => log(v + 1e-9))
        .toList();

    final List<double> hps = List<double>.filled(N, 0.0);

    for (int k = 0; k < N; k++) {
      double sum = logMag[k];
      for (int h = 2; h <= maxHarmonics; h++) {
        final int hk = k * h;
        if (hk >= N) break;
        sum += logMag[hk];
      }
      hps[k] = sum;
    }

    // Convert back from log-sum to a linear-ish scale for peak finding.
    final List<double> linear = hps.map((v) => exp(v / maxHarmonics)).toList();

    // Normalise.
    final double maxVal = linear.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return linear;
    return linear.map((v) => v / maxVal).toList();
  }
/// Find peaks using Harmonic Product Spectrum
List<PeakData> findPeaksHPS(
  List<double> magnitudes, {
  double threshold = 0.1,
  int maxHarmonics = 5,
  int maxPeaks = 6,
}) {
  if (magnitudes.isEmpty) return [];

  List<double> hps = harmonicProductSpectrum(
    magnitudes, 
    maxHarmonics: maxHarmonics
  );

  List<PeakData> peaks = [];
  List<double> freqs = getFrequencyBins(magnitudes.length);

  // Find local maxima in HPS
  for (int i = 2; i < hps.length - 2; i++) {  // Start from index 2 to avoid DC
    if (hps[i] > threshold && 
        hps[i] > hps[i - 1] && 
        hps[i] > hps[i - 2] && 
        hps[i] > hps[i + 1] && 
        hps[i] > hps[i + 2]) {
      
      // Quadratic interpolation for better frequency estimation
      double freq = _interpolatePeak(
        magnitudes[i - 1], magnitudes[i], magnitudes[i + 1],
        freqs[i - 1], freqs[i], freqs[i + 1]
      );
      
      peaks.add(PeakData(
        frequency: freq,
        magnitude: magnitudes[i],  // Use original magnitude, not HPS
        binIndex: i,
        hpsValue: hps[i],
      ));
    }
  }

    // Sort by HPS value
    peaks.sort((a, b) => (b.hpsValue ?? 0).compareTo(a.hpsValue ?? 0));
    return peaks.take(maxPeaks).toList();
  }

  /// Quadratic interpolation for peak frequency estimation
  double _interpolatePeak(
    double ym1, double y0, double yp1,
    double fm1, double f0, double fp1
  ) {
    double a = (yp1 + ym1 - 2 * y0) / 2;
    double b = (yp1 - ym1) / 2;
    
    if (a == 0) return f0;
    
    double shift = -b / (2 * a);
    return f0 + shift * (fp1 - f0);
  }

  /// Find fundamental frequency using HPS
double findFundamentalHPS(
  List<double> magnitudes, {
  int minFreqHz = 75,
  int maxFreqHz = 1300,
  int maxHarmonics = 5,
}) {
  if (magnitudes.isEmpty) return 0;

  final List<double> hps = harmonicProductSpectrum(
    magnitudes,
    maxHarmonics: maxHarmonics,
  );

  final double freqResolution = sampleRate / (magnitudes.length * 2.0);
  final int minBin =
      (minFreqHz / freqResolution).floor().clamp(1, magnitudes.length - 1);
  final int maxBin =
      (maxFreqHz / freqResolution).ceil().clamp(minBin + 1, magnitudes.length - 1);

  // Find HPS peak in the guitar range.
  double maxHPS = -1;
  int peakBin = minBin;
  for (int k = minBin; k <= maxBin; k++) {
    if (hps[k] > maxHPS) {
      maxHPS = hps[k];
      peakBin = k;
    }
  }

  // Parabolic interpolation for sub-bin accuracy.
  double peakFreq;
  if (peakBin > minBin && peakBin < maxBin) {
    final double ym1 = hps[peakBin - 1];
    final double y0  = hps[peakBin];
    final double yp1 = hps[peakBin + 1];
    final double denom = ym1 - 2 * y0 + yp1;
    final double shift = denom != 0 ? 0.5 * (ym1 - yp1) / denom : 0.0;
    peakFreq = (peakBin + shift) * freqResolution;
  } else {
    peakFreq = peakBin * freqResolution;
  }

  // ── Sub-harmonic check ────────────────────────────────────────────────────
  // If half this frequency (one octave down) has meaningful spectral energy,
  // the HPS peak is almost certainly sitting on the 2nd harmonic.
  // We only descend one octave — two octaves down would be below guitar range.
  final double subFreq = peakFreq / 2.0;
  if (subFreq >= minFreqHz) {
    final double subEnergy = _subHarmonicCheck(magnitudes, subFreq, freqResolution);
    final double peakEnergy = _subHarmonicCheck(magnitudes, peakFreq, freqResolution);

    // If the sub-harmonic has at least 20 % of the HPS-peak's raw energy,
    // trust it as the true fundamental.  The 20 % threshold is intentionally
    // low: on guitar the fundamental is often weaker than the 2nd harmonic
    // (especially on wound strings), so we lean toward the lower octave.
    if (peakEnergy > 0 && subEnergy / peakEnergy >= 0.20) {
      return subFreq;
    }
  }

  return peakFreq;
}

double _subHarmonicCheck(
  List<double> magnitudes,
  double targetHz,
  double freqResolution,
) {
  final int centerBin = (targetHz / freqResolution).round();
  final int lo = (centerBin - 2).clamp(0, magnitudes.length - 1);
  final int hi = (centerBin + 2).clamp(0, magnitudes.length - 1);

  double peak = 0;
  for (int b = lo; b <= hi; b++) {
    if (magnitudes[b] > peak) peak = magnitudes[b];
  }
  return peak;
}

double _autocorrelationF0(
  List<double> samples, {
  int minFreqHz = 75,
  int maxFreqHz = 1300,
}) {
  final int N = samples.length;
  if (N < 2) return 0;

  // Lag range in samples.
  final int minLag = (sampleRate / maxFreqHz).floor().clamp(1, N - 1);
  final int maxLag = (sampleRate / minFreqHz).ceil().clamp(minLag + 1, N - 1);

  // Normalised autocorrelation (NSDF style — avoids bias toward short lags).
  // r[lag] = sum(x[n]*x[n+lag]) / sqrt(sum(x[n]^2) * sum(x[n+lag]^2))

  double bestCorr = -1;
  int bestLag = minLag;

  for (int lag = minLag; lag <= maxLag; lag++) {
    double num = 0, e1 = 0, e2 = 0;
    final int len = N - lag;
    for (int n = 0; n < len; n++) {
      num += samples[n] * samples[n + lag];
      e1  += samples[n] * samples[n];
      e2  += samples[n + lag] * samples[n + lag];
    }
    final double denom = sqrt(e1 * e2);
    final double corr = denom > 1e-10 ? num / denom : 0.0;
    if (corr > bestCorr) {
      bestCorr = corr;
      bestLag = lag;
    }
  }

  // Reject weak correlations — likely noise or inharmonic transients.
  if (bestCorr < 0.5) return 0;

  // Sub-sample refinement via parabolic interpolation on the correlation peak.
  double refinedLag = bestLag.toDouble();
  if (bestLag > minLag && bestLag < maxLag) {
    final double ym1 = _autocorrelationAt(samples, bestLag - 1);
    final double y0  = _autocorrelationAt(samples, bestLag);
    final double yp1 = _autocorrelationAt(samples, bestLag + 1);
    final double denom2 = ym1 - 2 * y0 + yp1;
    if (denom2 != 0) {
      refinedLag += 0.5 * (ym1 - yp1) / denom2;
    }
  }

  return sampleRate / refinedLag;
}

double _autocorrelationAt(List<double> samples, int lag) {
  final int len = samples.length - lag;
  if (len <= 0) return 0;
  double sum = 0;
  for (int n = 0; n < len; n++) {
    sum += samples[n] * samples[n + lag];
  }
  return sum;
}

double _robustFundamental(List<double> magnitudes, List<double> timeDomain) {
  const int minHz = 75;
  const int maxHz = 1300;

  final double hps  = findFundamentalHPS(magnitudes,
      minFreqHz: minHz, maxFreqHz: maxHz);
  final double ac   = _autocorrelationF0(timeDomain,
      minFreqHz: minHz, maxFreqHz: maxHz);

  // Neither method found anything.
  if (hps <= 0 && ac <= 0) return 0;

  // Only one succeeded — use it.
  if (hps <= 0) return ac;
  if (ac  <= 0) return hps;

  // Both succeeded — compare.
  // Agreement within ±1 semitone (≈ 5.9 % frequency ratio).
  final double ratio = hps / ac;
  const double semitoneTolerance = 1.0594630943592953; // 2^(1/12)

  if (ratio < semitoneTolerance && ratio > 1.0 / semitoneTolerance) {
    // They agree — HPS has better frequency resolution, use it.
    return hps;
  }

  // HPS is approximately one octave above autocorrelation → octave error.
  if (ratio > 1.8 && ratio < 2.2) {
    return ac; // trust autocorrelation
  }

  // HPS is approximately one octave below (rare but possible).
  if (ratio > 0.45 && ratio < 0.55) {
    return hps;
  }

  // Larger disagreement — autocorrelation is more reliable for octave identity.
  return ac;
}

  // ============ Harmonic Weighting ============

  /// Apply harmonic weighting to spectrum
  /// Emphasizes frequencies with strong harmonic relationships
  List<double> applyHarmonicWeighting(
    List<double> magnitudes, {
    double fundamentalFreq = 0,
    int maxHarmonics = 8,
    double harmonicDecay = 0.9,
  }) {
    if (magnitudes.isEmpty) return magnitudes;

    // Detect fundamental if not provided
    if (fundamentalFreq <= 0) {
      fundamentalFreq = findFundamentalHPS(magnitudes, maxHarmonics: maxHarmonics);
      if (fundamentalFreq <= 0) return magnitudes;
    }

    List<double> freqs = getFrequencyBins(magnitudes.length);
    List<double> weighted = List.filled(magnitudes.length, 0.0);

    // Weight each frequency bin based on harmonic relationship
    for (int bin = 0; bin < magnitudes.length; bin++) {
      double freq = freqs[bin];
      if (freq <= 0) continue;

      double closestHarmonicWeight = 0;

      for (int h = 1; h <= maxHarmonics; h++) {
        double expectedFreq = fundamentalFreq * h;
        double distance = (freq - expectedFreq).abs();

        // Weight inversely with distance and harmonically damped
        double weight = pow(harmonicDecay, h - 1).toDouble() /
            (1 + distance / (fundamentalFreq * 0.05));

        closestHarmonicWeight += weight;
      }

      // Apply harmonic weight
      weighted[bin] = magnitudes[bin] * closestHarmonicWeight;
    }

    return weighted;
  }

  // ============ Peak Detection ============

  /// Find peaks in spectrum above threshold
  List<PeakData> findPeaks(List<double> magnitudes, {double threshold = 0.01}) {
    if (magnitudes.isEmpty) return [];

    double maxMag = magnitudes.reduce((a, b) => a > b ? a : b);
    threshold *= maxMag;

    List<PeakData> peaks = [];
    List<double> freqs = getFrequencyBins(magnitudes.length);

    for (int i = 1; i < magnitudes.length - 1; i++) {
      if (magnitudes[i] > magnitudes[i - 1] &&
          magnitudes[i] > magnitudes[i + 1] &&
          magnitudes[i] > threshold) {
        // Parabolic interpolation for finer frequency estimate
        double alpha = magnitudes[i - 1];
        double beta = magnitudes[i];
        double gamma = magnitudes[i + 1];
        double p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);
        double frequency = freqs[i.toInt()] + (p * (freqs[1] - freqs[0]));

        peaks.add(PeakData(
          frequency: frequency,
          magnitude: beta,
          binIndex: i,
        ));
      }
    }

    peaks.sort((a, b) => b.magnitude.compareTo(a.magnitude));
    return peaks;
  }

  // ============ Frequency Detection ============

  /// Detect single dominant frequency
  double detectFrequency(List<double> magnitudes) {
    if (magnitudes.isEmpty) return 0;
    List<PeakData> peaks = findPeaks(magnitudes, threshold: 0.01);
    return peaks.isNotEmpty ? peaks.first.frequency : 0;
  }

  /// Detect multiple fundamental frequencies (filters out harmonics)
  List<double> detectMultipleFrequencies(
  List<double> magnitudes, {
  int maxNotes = 6,
  double harmonicTolerance = 0.03,  // Reduced tolerance for better discrimination
  bool useHPS = true,
}) {
  List<PeakData> peaks;
  if (useHPS) {
    List<PeakData> hpsPeaks = findPeaksHPS(magnitudes, maxPeaks: maxNotes * 3);
    List<PeakData> magPeaks = findPeaks(magnitudes, threshold: 0.02);

    // Combine HPS and magnitude peaks, avoiding near-duplicates
    double freqRes = sampleRate / (magnitudes.length * 2);
    peaks = List.from(hpsPeaks);
    for (var p in magPeaks) {
      bool exists = peaks.any((q) => (q.frequency - p.frequency).abs() < freqRes * 0.5);
      if (!exists) peaks.add(p);
    }
  } else {
    peaks = findPeaks(magnitudes, threshold: 0.02);
  }

  if (peaks.isEmpty) return [];

  // Sort by frequency for better harmonic detection
  peaks.sort((a, b) => a.frequency.compareTo(b.frequency));
  
  List<double> fundamentals = [];
  
  for (var peak in peaks) {
    // Skip very low frequencies (likely noise)
    if (peak.frequency < 60) continue;
    
    bool isHarmonic = false;
    
    // Check if this peak is a harmonic of any detected fundamental
    for (var f in fundamentals) {
      double ratio = peak.frequency / f;
      int nearestHarmonic = ratio.round();
      
      // Check if ratio is close to an integer (2, 3, 4, etc.)
      if (nearestHarmonic >= 2 && 
          (ratio - nearestHarmonic).abs() < harmonicTolerance) {
        isHarmonic = true;
        break;
      }
      
      // Also check sub-harmonics (fundamental is harmonic of peak)
      double inverseRatio = f / peak.frequency;
      int nearestSubHarmonic = inverseRatio.round();
      if (nearestSubHarmonic >= 2 && 
          (inverseRatio - nearestSubHarmonic).abs() < harmonicTolerance) {
        isHarmonic = true;
        break;
      }
    }
    
    if (!isHarmonic) {
      fundamentals.add(peak.frequency);
    }
    
    if (fundamentals.length >= maxNotes) break;
  }
  
  return fundamentals;
}
  // ============ Note/Pitch Detection ============

  /// Get pitch class (C, C#, D, etc.) from frequency
  String getPitchClass(double frequency) {
    if (frequency <= 0) return 'Unknown';
    double semitones = 12 * (log(frequency / a4Frequency) / ln2);
    int midiNote = (a4Midi + semitones).round();
    return noteNames[midiNote % 12];
  }

  /// Convert frequency to full note name with octave
  String frequencyToNote(double frequency) {
    if (frequency <= 0) return 'Unknown';

    double semitones = 12 * (log(frequency / a4Frequency) / ln2);
    int midiNote = (a4Midi + semitones).round();
    int noteInOctave = midiNote % 12;
    int octave = (midiNote ~/ 12) - 1;

    double cents = (semitones - semitones.roundToDouble()) * 100;
    return '${noteNames[noteInOctave]}$octave (${cents > 0 ? '+' : ''}${cents.toStringAsFixed(1)} ¢)';
  }

  /// Convert a note name with octave (e.g. "A2", "C#3") to frequency in Hz.
  /// Returns null if parsing fails or the pitch is out of a reasonable range.
  double? _noteNameWithOctaveToFrequency(String note) {
    final match = RegExp(r'^([A-G]#?)(-?\d)$').firstMatch(note.trim());
    if (match == null) return null;

    final baseName = match.group(1)!;
    final octave = int.tryParse(match.group(2)!);
    if (octave == null) return null;

    final baseFreq = noteFrequencies[baseName];
    if (baseFreq == null) return null;

    // noteFrequencies[] hold 4th‑octave pitches (e.g. A4 = 440).
    final semitoneOffset = (octave - 4) * 12;
    final freq = baseFreq * pow(2.0, semitoneOffset / 12.0);

    // Guardrails: ignore clearly impossible guitar‑practice ranges.
    if (freq <= 10 || freq > 8000) return null;
    return freq;
  }

  /// Get unique pitch classes from frequencies
  Set<String> getUniquePitchClasses(List<double> frequencies) {
    return frequencies.map((f) => getPitchClass(f)).toSet();
  }

  // ============ Harmonic Analysis ============

  /// Detect harmonics of a fundamental frequency
  List<FrequencyComponent> detectHarmonics(
    List<double> magnitudes, {
    double fundamentalFreq = 0,
    int maxHarmonics = 10,
  }) {
    if (magnitudes.isEmpty) return [];

    List<PeakData> peaks = findPeaks(magnitudes, threshold: 0.005);
    if (peaks.isEmpty) return [];

    double f0 = fundamentalFreq > 0 ? fundamentalFreq : peaks.first.frequency;
    List<FrequencyComponent> harmonics = [];

    for (int h = 1; h <= maxHarmonics && peaks.isNotEmpty; h++) {
      double expectedFreq = f0 * h;

      PeakData? closest;
      double minDiff = double.infinity;

      for (var peak in peaks) {
        double diff = (peak.frequency - expectedFreq).abs();
        if (diff < f0 * 0.1 && diff < minDiff) {
          minDiff = diff;
          closest = peak;
        }
      }

      if (closest != null) {
        harmonics.add(FrequencyComponent(
          harmonic: h,
          frequency: closest.frequency,
          magnitude: closest.magnitude,
          expectedFreq: expectedFreq,
          detuning: ((closest.frequency - expectedFreq) / expectedFreq * 100),
        ));
        peaks.remove(closest);
      }
    }

    return harmonics;
  }

  double _calculateConfidence(List<FrequencyComponent> harmonics) {
    if (harmonics.isEmpty) return 0;
    double avgDetuning = harmonics
        .map((h) => (h.detuning).abs())
        .reduce((a, b) => a + b) /
        harmonics.length;
    return (max(0.0, 1 - (avgDetuning / 5.0))).clamp(0.0, 1.0);
  }

  // ============ Chord Classification ============

  /// Detect chord using template matching on detected notes
  String classifyChordFromNotes(Set<String> notes) {
    if (notes.isEmpty) return 'Unknown';

    final noteList = notes.toList();

    for (var root in noteList) {
      int rootIdx = _noteIndex(root);

      for (var entry in chordTemplates.entries) {
        bool match = entry.value.every((interval) {
          int idx = (rootIdx + interval) % 12;
          return notes.contains(noteNames[idx]);
        });

        if (match) {
          return simplifyChordName('$root ${entry.key}');
        }
      }
    }

    return 'Unknown';
  }

  /// Convert a single magnitude spectrum to a 12-bin chroma vector
  List<double> _spectrumToChroma(List<double> magnitudes) {
    List<double> chroma = List.filled(chromaBins, 0.0);
    if (magnitudes.isEmpty) return chroma;

    // Peak-based HPCP style chroma is much more robust on acoustic guitar
    // (reduces overtone dominance vs summing every FFT bin).
    final spec = _smoothSpectrum(magnitudes);
    final maxMag = spec.reduce((a, b) => a > b ? a : b);
    if (maxMag <= 0) return chroma;

    // Focus on prominent spectral peaks within a musically relevant band.
    // A dynamic threshold keeps behavior stable across different mic gains.
    final peaks = findPeaks(spec, threshold: 0.02)
        .where((p) => p.frequency >= _minChordFreqHz && p.frequency <= _maxChordFreqHz)
        .take(_maxChromaPeaks)
        .toList();

    if (peaks.isEmpty) return chroma;

    // Helper: add energy to chroma with fractional pitch interpolation
    void addToChroma(double frequency, double energy) {
      if (frequency <= 0 || energy <= 0) return;

      // Convert to fractional MIDI, then distribute between adjacent pitch classes.
      final p = a4Midi + 12.0 * (log(frequency / a4Frequency) / ln2);
      final nearest = p.roundToDouble();
      final delta = (p - nearest).clamp(-0.5, 0.5); // semitones

      int i0 = (nearest.toInt() % 12 + 12) % 12;
      int i1 = ((i0 + (delta >= 0 ? 1 : -1)) % 12 + 12) % 12;

      final w1 = (delta.abs() * 2.0).clamp(0.0, 1.0);
      final w0 = 1.0 - w1;
      chroma[i0] += energy * w0;
      chroma[i1] += energy * w1;
    }

    // Harmonic folding:
    // For each observed peak at f, also vote for f/h (h=2..N) so strong harmonics
    // still contribute back to the implied fundamental pitch class.
    for (final p in peaks) {
      // Mild magnitude compression so one very loud partial doesn't dominate.
      final mag = pow(p.magnitude / maxMag, 0.6).toDouble();
      if (mag <= 0) continue;

      // Downweight very high peaks (mostly timbre/noise) even if they're loud.
      final highFreqPenalty = 1.0 / (1.0 + (p.frequency / 1200.0));
      final baseEnergy = mag * highFreqPenalty;

      // Always include the direct vote (h=1).
      addToChroma(p.frequency, baseEnergy);

      // Only fold if the peak is plausibly a harmonic (above low fundamentals).
      if (p.frequency >= 160.0) {
        for (int h = 2; h <= _harmonicFoldMax; h++) {
          final f0 = p.frequency / h;
          if (f0 < _minChordFreqHz) break;
          // 1/h decay is key: many overtones should not overpower actual fundamentals.
          final foldEnergy = baseEnergy * (1.0 / h);
          addToChroma(f0, foldEnergy);
        }
      }
    }

    // L1 normalize (stable for thresholding + averaging)
    final sum = chroma.reduce((a, b) => a + b);
    if (sum > 0) {
      for (int i = 0; i < chroma.length; i++) {
        chroma[i] /= sum;
      }
    }

    return chroma;
  }

  /// Simple 3-point smoothing kernel across frequency axis
  List<double> _smoothSpectrum(List<double> mags) {
    if (mags.length < 3) return List.from(mags);
    List<double> out = List.filled(mags.length, 0.0);
    for (int i = 0; i < mags.length; i++) {
      double left = i > 0 ? mags[i - 1] * 0.25 : 0.0;
      double center = mags[i] * 0.5;
      double right = i < mags.length - 1 ? mags[i + 1] * 0.25 : 0.0;
      out[i] = left + center + right;
    }
    return out;
  }

  void _pushChromaFrame(List<double> chroma) {
    _chromaBuffer.add(chroma);
    int maxFrames = _chromaBufferMaxFrames;
    while (_chromaBuffer.length > maxFrames) {
      _chromaBuffer.removeAt(0);
    }
  }

  void _pushOctavePair(_OctavePair pair) {
    _octaveHistory.add(pair);
    int maxFrames = _octaveBufferMaxFrames;
    while (_octaveHistory.length > maxFrames) {
      _octaveHistory.removeAt(0);
    }
  }

  List<double> _averageChroma() {
    if (_chromaBuffer.isEmpty) return List.filled(chromaBins, 0.0);
    List<double> avg = List.filled(chromaBins, 0.0);
    for (var c in _chromaBuffer) {
      for (int i = 0; i < chromaBins; i++) {
        avg[i] += c[i];
      }
    }
    double denom = _chromaBuffer.length.toDouble();
    for (int i = 0; i < chromaBins; i++) {
      avg[i] /= denom;
    }

    // Apply relative threshold to ignore weak classes
    double maxVal = avg.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return avg;
    // Lower threshold for third interval (major/minor)
    for (int i = 0; i < chromaBins; i++) {
      // Check if this bin is a major or minor third above a strong root
      bool isThird = false;
      for (int root = 0; root < chromaBins; root++) {
        if (avg[root] >= maxVal * chromaThreshold) {
          int majorThird = (root + 4) % 12;
          int minorThird = (root + 3) % 12;
          if (i == majorThird || i == minorThird) isThird = true;
        }
      }
      double threshold = isThird ? chromaThreshold * 0.5 : chromaThreshold;
      if (avg[i] < maxVal * threshold) avg[i] = 0.0;
    }
    // Re-normalize after threshold
    double s = avg.reduce((a, b) => a + b);
    if (s > 0) {
      for (int i = 0; i < chromaBins; i++) {
        avg[i] /= s;
      }
    }
    return avg;
  }

  /// Match chord using chroma similarity with weighted importance on the third
  /// Weights: root=1.0, third=1.5, fifth=1.0, seventh=0.8
  Map<String, dynamic> _classifyChordFromChroma(List<double> originalChroma, {int? bassPitchClass}) {
    // Return { 'name': String, 'score': double }
    if (originalChroma.every((c) => c <= 0)) return {'name': 'Unknown', 'score': 0.0};

    // Copy to avoid mutating caller data
    final chroma = List<double>.from(originalChroma);

    // Use L2 norm for cosine similarity.
    final chromaNorm = sqrt(chroma.map((c) => c * c).reduce((a, b) => a + b));
    if (chromaNorm == 0) return {'name': 'Unknown', 'score': 0.0};

    String bestName = 'Unknown';
    double bestScore = 0.0;

    // For each possible root and template, compute a weighted score that:
    // - rewards chord-tone energy
    // - penalizes non-chord tones (common on acoustic guitar due to overtones/noise)
    // - applies a light bass-note prior from low-frequency peaks
    for (int root = 0; root < 12; root++) {
      for (var entry in chordTemplates.entries) {
        final intervals = entry.value;

        // Interval-based weights (avoid treating sus tones like a "third")
        double intervalWeight(int interval) {
          if (interval == 0) return 1.15; // root
          if (interval == 3) return 1.80; // minor third — boosted for minor chord detection
          if (interval == 4) return 1.55;
          if (interval == 7) return 1.05; // fifth
          if (interval == 10 || interval == 11) return 0.85; // 7th
          if (interval == 2 || interval == 5) return 1.05; // sus2 / sus4
          if (interval == 6 || interval == 8) return 0.95; // dim/aug tone
          return 0.9;
        }

        final chordToneMask = List<double>.filled(12, 0.0);
        double wSum = 0.0;
        for (final interval in intervals) {
          final idx = (root + interval) % 12;
          final w = intervalWeight(interval);
          chordToneMask[idx] = max(chordToneMask[idx], w);
          wSum += w;
        }
        if (wSum <= 0) continue;

        double positive = 0.0;
        double outside = 0.0;
        for (int i = 0; i < 12; i++) {
          final v = chroma[i];
          if (v <= 0) continue;
          final w = chordToneMask[i];
          if (w > 0) {
            positive += v * w;
          } else {
            outside += v;
          }
        }

        // Normalize positive by chord weight sum so different template sizes compare fairly.
        double score = positive / wSum;

        // Penalize non-chord tones (helps acoustic guitar where high harmonics smear chroma).
        const double outsidePenalty = 0.40;
        score -= outsidePenalty * outside;

        // Bass prior: if we have a bass pitch class estimate, gently reward
        // templates whose root (or chord tone) matches it.
         if (bassPitchClass != null) {
          if (bassPitchClass == root) {
            score += 0.18;
          } else if (chordToneMask[bassPitchClass] > 0) {
            score += 0.04;
          } else {
            score -= 0.08;
          }
        }

        // A small prior towards simple triads for stability.
        final type = entry.key;
        if (type == 'Major' || type == 'Minor') score += 0.015;

        // Convert to a [0..1] similarity-like value for downstream thresholds.
        // Use cosine similarity as a secondary stabilizer (keeps old behavior shape).
        double dot = 0.0;
        double tplEnergy = 0.0;
        for (int i = 0; i < 12; i++) {
          final w = chordToneMask[i];
          if (w <= 0) continue;
          dot += chroma[i] * w;
          tplEnergy += w * w;
        }
        final tplNorm = sqrt(tplEnergy);
        final cosSim = (tplNorm > 0) ? (dot / (chromaNorm * tplNorm)) : 0.0;
        final sim = (0.65 * cosSim + 0.35 * score).clamp(0.0, 1.0);

        if (sim > bestScore) {
          bestScore = sim;
          bestName = '${noteNames[root]} ${entry.key}';
        }
      }
    }
    return {'name': bestName, 'score': bestScore.clamp(0.0, 1.0)};
  }

  int? _estimateBassPitchClass(List<double> magnitudes) {
    if (magnitudes.isEmpty) return null;
    final maxMag = magnitudes.reduce((a, b) => a > b ? a : b);
    if (maxMag <= 0) return null;

    // Find strongest peak in low-frequency band (bass region).
    // Using peaks avoids being tricked by broadband noise.
    final bassPeaks = findPeaks(magnitudes, threshold: 0.02)
        .where((p) => p.frequency >= 55.0 && p.frequency <= 350.0)
        .toList();
    if (bassPeaks.isEmpty) return null;
    bassPeaks.sort((a, b) => b.magnitude.compareTo(a.magnitude));

    final f = bassPeaks.first.frequency;
    if (f <= 0) return null;
    final semitones = 12 * (log(f / a4Frequency) / ln2);
    final midi = (a4Midi + semitones).round();
    return ((midi % 12) + 12) % 12;
  }

  _OctavePair? _findBestOctavePair(List<PeakData> peaks) {
    if (peaks.length < 2) return null;

    // Work on the loudest peaks first.
    final sorted = List<PeakData>.from(peaks)
      ..sort((a, b) => b.magnitude.compareTo(a.magnitude));
    final top = sorted.take(8).toList();

    _OctavePair? best;
    double bestCost = double.infinity;

    for (int i = 0; i < top.length; i++) {
      for (int j = i + 1; j < top.length; j++) {
        final f1 = top[i].frequency;
        final f2 = top[j].frequency;
        if (f1 <= 0 || f2 <= 0) continue;

        final low = min(f1, f2);
        final high = max(f1, f2);

        // Octave interval should be very close to 1200 cents.
        final intervalCents = 1200.0 * (log(high / low) / ln2);
        final diff = (intervalCents - 1200.0).abs();

        // Discard clearly non‑octave pairs (> ~2/3 semitone off).
        if (diff > 80.0) continue;

        if (diff < bestCost) {
          bestCost = diff;
          best = _OctavePair(low, high);
        }
      }
    }

    return best;
  }

  /// End-to-end chord detection from spectrum with latency measurement and stability filtering
  MultiNoteDetectionResult detectMultiNoteChord(List<double> magnitudes) {
    // Measure processing latency
    var startTime = DateTime.now();
    
    // New chroma-based pipeline:
    if (magnitudes.isEmpty) return MultiNoteDetectionResult.empty();

    // Convert current spectrum to chroma and push into temporal buffer
    List<double> chromaFrame = _spectrumToChroma(magnitudes);
    _pushChromaFrame(chromaFrame);

    // Average recent chroma frames (smoothing over time)
    List<double> avgChroma = _averageChroma();

    // If nothing above threshold, return empty
    double totalEnergy = avgChroma.reduce((a, b) => a + b);
    if (totalEnergy <= 0) return MultiNoteDetectionResult.empty();

    // Get detected pitch classes (non-zero chroma bins)
    List<String> detected = [];
    for (int i = 0; i < avgChroma.length; i++) {
      if (avgChroma[i] > 0) detected.add(noteNames[i]);
    }

    _log('ChromaFrame: ${chromaFrame.map((c) => c.toStringAsFixed(3)).join(', ')}');
    _log('AvgChroma: ${avgChroma.map((c) => c.toStringAsFixed(3)).join(', ')}');
    _log('Detected pitch classes: ${detected.join(', ')}');

    // Match chord by weighted similarity
    final bassPc = _estimateBassPitchClass(magnitudes);
    var match = _classifyChordFromChroma(avgChroma, bassPitchClass: bassPc);
    String chordName = match['name'] ?? 'Unknown';
    double confidence = (match['score'] is double) ? match['score'] : 0.0;

    // Apply stability filtering to prevent flickering
    String finalChordName = chordName;
    if (chordName == _lastChordName && confidence >= _lastChordScore * 0.9) {
      // Same chord, increment stability counter
      _chordStabilityCounter++;
      if (_chordStabilityCounter < stabilityThreshold) {
        // Haven't reached stability threshold yet, keep last chord
        finalChordName = _lastChordName;
      }
    } else {
      // Different chord detected, reset counter
      _chordStabilityCounter = 1;
      _lastChordName = chordName;
      _lastChordScore = confidence;
    }

    _log('ChordDecision: $finalChordName (score: ${confidence.toStringAsFixed(3)}, stability: $_chordStabilityCounter/$stabilityThreshold)');

    // Measure processing latency
    _lastProcessingLatencyMs = DateTime.now().difference(startTime).inMilliseconds.toDouble();
    _log('ProcessingLatency: ${_lastProcessingLatencyMs.toStringAsFixed(2)} ms');

    return MultiNoteDetectionResult(
      detectedNotes: detected,
      fundamentalFrequencies: [],
      chordName: simplifyChordName(finalChordName),
      confidence: confidence,
    );
  }

  /// Octave detection helper using HPS + a short rolling buffer.
  /// Returns how closely the detected low/high notes match the requested octave.
  OctaveResult detectOctaveFromSpectrum(
    List<double> magnitudes, {
    required String targetLow,
    required String targetHigh,
    double centsTolerance = 15.0,
  }) {
    if (magnitudes.isEmpty) {
      _octaveHistory.clear();
      return OctaveResult.noInput(targetLow: targetLow, targetHigh: targetHigh);
    }

    // Find candidate fundamentals/harmonics using HPS.
    final peaks = findPeaksHPS(
      magnitudes,
      threshold: 0.06,
      maxHarmonics: 5,
      maxPeaks: 10,
    );

    final pair = _findBestOctavePair(peaks);

    if (pair != null) {
      _pushOctavePair(pair);
    } else if (peaks.isEmpty) {
      // No usable peaks at all → treat as no input and clear history.
      _octaveHistory.clear();
      return OctaveResult.noInput(targetLow: targetLow, targetHigh: targetHigh);
    }

    if (_octaveHistory.isEmpty) {
      return OctaveResult.noInput(targetLow: targetLow, targetHigh: targetHigh);
    }

    // Average over the last ~300 ms for stability.
    double avgLow = 0;
    double avgHigh = 0;
    for (final p in _octaveHistory) {
      avgLow += p.lowHz;
      avgHigh += p.highHz;
    }
    final len = _octaveHistory.length.toDouble();
    avgLow /= len;
    avgHigh /= len;

    final targetLowHz = _noteNameWithOctaveToFrequency(targetLow);
    final targetHighHz = _noteNameWithOctaveToFrequency(targetHigh);

    if (targetLowHz == null || targetHighHz == null) {
      return OctaveResult(
        targetLow: targetLow,
        targetHigh: targetHigh,
        detectedLowHz: avgLow,
        detectedHighHz: avgHigh,
        centsOffLow: null,
        centsOffHigh: null,
        status: OctaveStatus.wrongNotes,
      );
    }

    // Cents offsets relative to target pitches.
    final centsLow =
        (1200.0 * (log(avgLow / targetLowHz) / ln2)).round();
    final centsHigh =
        (1200.0 * (log(avgHigh / targetHighHz) / ln2)).round();

    // Check that the interval itself is an octave.
    final intervalCents = 1200.0 * (log(avgHigh / avgLow) / ln2);
    final intervalError = (intervalCents - 1200.0).abs();
    const double intervalTolerance = 40.0; // ~1/3 semitone

    OctaveStatus status;
    final absLow = centsLow.abs();
    final absHigh = centsHigh.abs();

    if (intervalError > intervalTolerance) {
      status = OctaveStatus.wrongNotes;
    } else if (absLow <= centsTolerance && absHigh <= centsTolerance) {
      status = OctaveStatus.correct;
    } else {
      // Decide whether the overall tendency is sharp or flat.
      final dominant = absLow >= absHigh ? centsLow : centsHigh;
      if (dominant > centsTolerance) {
        status = OctaveStatus.sharpNote;
      } else if (dominant < -centsTolerance) {
        status = OctaveStatus.flatNote;
      } else {
        status = OctaveStatus.wrongNotes;
      }
    }

    return OctaveResult(
      targetLow: targetLow,
      targetHigh: targetHigh,
      detectedLowHz: avgLow,
      detectedHighHz: avgHigh,
      centsOffLow: centsLow,
      centsOffHigh: centsHigh,
      status: status,
    );
  }

  /// Reset stored octave history (use when starting a new exercise).
  void resetOctaveHistory() {
    _octaveHistory.clear();
  }

  /// Legacy method maintaining compatibility
  ChordDetectionResult detectChord(List<double> magnitudes) {
    if (magnitudes.isEmpty) return ChordDetectionResult.empty();

    List<PeakData> peaks = findPeaks(magnitudes, threshold: 0.01);
    if (peaks.isEmpty) return ChordDetectionResult.empty();

    double fundamentalFreq = peaks.first.frequency;
    List<FrequencyComponent> harmonics = detectHarmonics(
      magnitudes,
      fundamentalFreq: fundamentalFreq,
      maxHarmonics: 10,
    );

    return ChordDetectionResult(
      fundamentalFreq: fundamentalFreq,
      fundamentalNote: frequencyToNote(fundamentalFreq),
      harmonics: harmonics,
      confidence: _calculateConfidence(harmonics),
    );
  }

  // ignore: unused_element
  double _calculateMultiNoteConfidence(
    List<double> magnitudes,
    List<double> frequencies,
  ) {
    if (frequencies.isEmpty) return 0;

    double totalMagnitude = 0;
    double totalWeight = 0;
    
    // Weight by harmonic strength
    for (var freq in frequencies) {
      double mag = _getMagnitudeAtFrequency(magnitudes, freq);
      
      // Check if this frequency has strong harmonics
      List<FrequencyComponent> harmonics = detectHarmonics(
        magnitudes, 
        fundamentalFreq: freq,
        maxHarmonics: 5,
      );
      
      double harmonicStrength = harmonics.isEmpty ? 0 : 
          harmonics.map((h) => h.magnitude).reduce((a, b) => a + b) / harmonics.length;
      
      totalMagnitude += mag * (1 + harmonicStrength);
      totalWeight += 1 + harmonicStrength;
    }

    double avgMagnitude = totalMagnitude / totalWeight;
    double maxMagnitude = magnitudes.reduce((a, b) => a > b ? a : b);
    
    return (avgMagnitude / maxMagnitude).clamp(0.0, 1.0);
  }

  double _getMagnitudeAtFrequency(List<double> magnitudes, double frequency) {
    List<double> freqs = getFrequencyBins(magnitudes.length);
    double minDiff = double.infinity;
    double closestMag = 0;

    for (int i = 0; i < freqs.length; i++) {
      double diff = (freqs[i] - frequency).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestMag = magnitudes[i];
      }
    }

    return closestMag;
  }

  int _noteIndex(String note) {
    return noteNames.indexOf(note);
  }

  // ============ STFT Implementation ============

  /// Compute STFT of signal with overlapping windows
  STFTResult computeSTFT(
    List<double> signal, {
    int windowSize = 512,
    int hopSize = 256,
    String windowType = 'hamming',
  }) {
    if (!_validateSignal(signal)) {
      return STFTResult(
        magnitude: [],
        phase: [],
        timeFrames: [],
        frequencyBins: [],
      );
    }

    List<List<double>> magnitudeSpectrogram = [];
    List<List<double>> phaseSpectrogram = [];
    List<double> timeFrames = [];

    int numFrames = ((signal.length - windowSize) ~/ hopSize) + 1;

    for (int frameIdx = 0; frameIdx < numFrames; frameIdx++) {
      int start = frameIdx * hopSize;
      int end = start + windowSize;

      if (end > signal.length) break;

      List<double> frame = signal.sublist(start, end);
      List<double> windowed = _applyWindowType(frame, windowType);

      List<Complex> complexSignal = List.filled(windowSize, Complex(0, 0));
      for (int i = 0; i < windowSize; i++) {
        complexSignal[i] = Complex(windowed[i], 0);
      }

      List<Complex> fftResult = _fft(complexSignal);

      List<double> mag = [];
      List<double> phase = [];

      for (int k = 0; k < windowSize ~/ 2; k++) {
        mag.add(fftResult[k].magnitude / windowSize * 2);
        phase.add(fftResult[k].phase);
      }

      magnitudeSpectrogram.add(mag);
      phaseSpectrogram.add(phase);
      timeFrames.add((start + windowSize / 2) / sampleRate);
    }

    return STFTResult(
      magnitude: magnitudeSpectrogram,
      phase: phaseSpectrogram,
      timeFrames: timeFrames,
      frequencyBins: getFrequencyBins(windowSize ~/ 2),
    );
  }

  /// Apply selected window function to signal
  List<double> _applyWindowType(List<double> signal, String windowType) {
    switch (windowType.toLowerCase()) {
      case 'hamming':
        return applyWindow(signal);
      case 'hann':
      case 'hanning':
        return applyHannWindow(signal);
      case 'blackman':
        return _applyBlackmanWindow(signal);
      default:
        return applyWindow(signal);
    }
  }

  // ============ Gain Control ============

  // ignore: unused_element
  bool _needsGainAdjustment(List<double> signal) {
    if (signal.isEmpty) return false;
    
    // Calculate peak level and RMS level
    double peakLevel = signal.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    double rmsLevel = sqrt(signal.map((s) => s * s).reduce((a, b) => a + b) / signal.length);
    
    // Update recent peak level with smoothing
    _recentPeakLevel = gainSmoothingFactor * _recentPeakLevel + 
                      (1 - gainSmoothingFactor) * peakLevel;
    
    // Check if signal is too quiet (needs amplification)
    if (_recentPeakLevel < minAcceptableLevel && _currentGain < maxGain) {
      return true;
    }
    
    // Check if signal is too loud (needs attenuation)
    if (_recentPeakLevel > maxAcceptableLevel && _currentGain > minGain) {
      return true;
    }
    
    // Check if signal has good dynamic range but poor peak-to-RMS ratio
    // (might indicate clipping or distortion)
    double peakToRmsRatio = peakLevel / (rmsLevel + 1e-10);
    if (peakToRmsRatio < 2.0 && peakLevel > minAcceptableLevel) {
      // Suspiciously low peak-to-RMS ratio - might be distorted
      return true;
    }
    
    return false;
  }
  
  /// Apply automatic gain control to bring signal to optimal level
  List<double> applyAutomaticGainControl(List<double> signal) {
    if (signal.isEmpty) return signal;
    
    // Calculate current peak level
    double peakLevel = signal.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    if (peakLevel < 1e-10) return signal;  // Silence
    
    // Calculate desired gain
    double desiredGain = targetLevel / peakLevel;
    
    // Clamp gain to reasonable range
    desiredGain = desiredGain.clamp(minGain, maxGain);
    
    // Smooth gain changes to avoid artifacts
    _currentGain = gainSmoothingFactor * _currentGain + 
                  (1 - gainSmoothingFactor) * desiredGain;
    
    // Apply gain
    return signal.map((s) => s * _currentGain).toList();
  }
  
  /// Reset gain state (call when starting new analysis session)
  void resetGainState() {
    _recentPeakLevel = 0.0;
    _currentGain = 1.0;
  }
  
  /// Alternative: Simple gain adjustment with hysteresis
  List<double> applySimpleGainControl(List<double> signal) {
    if (signal.isEmpty) return signal;
    
    double peakLevel = signal.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    
    // Hysteresis thresholds to prevent rapid gain switching
    const double gainUpThreshold = 0.008;    // -42 dB
    const double gainDownThreshold = 0.6;    // -4.4 dB
    const double targetGainUp = 4.0;          // 12 dB boost
    const double targetGainDown = 0.5;        // -6 dB attenuation
    
    if (peakLevel < gainUpThreshold && _currentGain < targetGainUp) {
      // Gradually increase gain
      _currentGain = (_currentGain + 0.1).clamp(0.1, targetGainUp);
    } else if (peakLevel > gainDownThreshold && _currentGain > targetGainDown) {
      // Gradually decrease gain
      _currentGain = (_currentGain - 0.1).clamp(targetGainDown, 10.0);
    } else {
      // Slowly return to unity gain
      _currentGain += (1.0 - _currentGain) * 0.01;
    }
    
    return signal.map((s) => s * _currentGain).toList();
  }
  
  /// Get current gain value for debugging/monitoring
  double get currentGain => _currentGain;
  
  /// Get recent peak level for debugging/monitoring
  double get recentPeakLevel => _recentPeakLevel;

  // ============ Noise Suppression with Harmonic Weighting ============

  /// Noise suppression using harmonic weighting
  List<double> noiseSuppressionHarmonicWeighting(
    List<double> signal, {
    int windowSize = 512,
    int hopSize = 256,
    double fundamentalFreq = 0,
    int maxHarmonics = 8,
    double harmonicDecay = 0.9,
    double suppressionStrength = 1.0,
  }) {
    if (!_validateSignal(signal)) return signal;

    STFTResult stft = computeSTFT(
      signal,
      windowSize: windowSize,
      hopSize: hopSize,
    );

    if (stft.magnitude.isEmpty) return signal;

    List<List<double>> denoisedMagnitude = [];

    for (var frameMag in stft.magnitude) {
      double f0 = fundamentalFreq > 0
          ? fundamentalFreq
          : findFundamentalHPS(frameMag, maxHarmonics: maxHarmonics);

      if (f0 <= 0) {
        denoisedMagnitude.add(frameMag);
        continue;
      }

      List<double> weighted =
          applyHarmonicWeighting(frameMag, fundamentalFreq: f0, maxHarmonics: maxHarmonics, harmonicDecay: harmonicDecay);

      List<double> denoised = [];
      for (int k = 0; k < frameMag.length; k++) {
        double suppressionFactor = suppressionStrength * weighted[k] / (frameMag[k] + 1e-10);
        suppressionFactor = suppressionFactor.clamp(0.1, 1.0);
        denoised.add(frameMag[k] * suppressionFactor);
      }

      denoisedMagnitude.add(denoised);
    }

    return _reconstructFromSTFT(
      denoisedMagnitude,
      stft.phase,
      windowSize,
      hopSize,
    );
  }

  /// Reconstruct time-domain signal from STFT
  List<double> _reconstructFromSTFT(
    List<List<double>> magnitude,
    List<List<double>> phase,
    int windowSize,
    int hopSize,
  ) {
    if (magnitude.isEmpty || phase.isEmpty) return [];

    int numFrames = magnitude.length;
    int numBins = magnitude[0].length;
    double outputLength = ((numFrames - 1) * hopSize + windowSize).toDouble();
    List<double> output = List.filled(outputLength.toInt(), 0.0);

    for (int frameIdx = 0; frameIdx < numFrames; frameIdx++) {
      List<Complex> complexSpec = [];
      for (int k = 0; k < numBins; k++) {
        double mag = magnitude[frameIdx][k];
        double ph = phase[frameIdx][k];
        complexSpec.add(Complex(mag * cos(ph), mag * sin(ph)));
      }

      for (int k = numBins - 2; k >= 1; k--) {
        complexSpec.add(Complex(
          complexSpec[k].real,
          -complexSpec[k].imag,
        ));
      }

      List<Complex> timeDomain = _ifft(complexSpec, windowSize);

      int start = frameIdx * hopSize;
      for (int n = 0; n < windowSize && start + n < output.length; n++) {
        double w = 0.54 - 0.46 * cos(2 * pi * n / (windowSize - 1));
        output[start + n] += timeDomain[n].real * w;
      }
    }

    return output;
  }

  /// Inverse FFT
  List<Complex> _ifft(List<Complex> spectrum, int size) {
    List<Complex> padded = List.filled(size, Complex(0, 0));
    for (int i = 0; i < spectrum.length && i < size; i++) {
      padded[i] = spectrum[i];
    }

    List<Complex> conjugated =
        padded.map((c) => Complex(c.real, -c.imag)).toList();
    List<Complex> fftResult = _fft(conjugated);
    return fftResult.map((c) => Complex(c.real / size, -c.imag / size)).toList();
  }
}

// ============ Data Classes ============

/// Represents a frequency peak in the spectrum
class PeakData {
  final double frequency;
  final double magnitude;
  final int binIndex;
  final double? hpsValue; // Harmonic Product Spectrum value

  PeakData({
    required this.frequency,
    required this.magnitude,
    required this.binIndex,
    this.hpsValue,
  });
}

/// Represents a frequency component (harmonic)
class FrequencyComponent {
  final int harmonic;
  final double frequency;
  final double magnitude;
  final double expectedFreq;
  final double detuning; // cents

  FrequencyComponent({
    required this.harmonic,
    required this.frequency,
    required this.magnitude,
    required this.expectedFreq,
    required this.detuning,
  });

  @override
  String toString() =>
      'H$harmonic: ${frequency.toStringAsFixed(2)} Hz (${detuning > 0 ? '+' : ''}${detuning.toStringAsFixed(1)} ¢)';
}

/// Single note chord detection result
class ChordDetectionResult {
  final double fundamentalFreq;
  final String fundamentalNote;
  final List<FrequencyComponent> harmonics;
  final double confidence;

  ChordDetectionResult({
    required this.fundamentalFreq,
    required this.fundamentalNote,
    required this.harmonics,
    required this.confidence,
  });

  factory ChordDetectionResult.empty() {
    return ChordDetectionResult(
      fundamentalFreq: 0,
      fundamentalNote: 'Unknown',
      harmonics: [],
      confidence: 0,
    );
  }

  @override
  String toString() =>
      'Chord: $fundamentalNote\nFreq: ${fundamentalFreq.toStringAsFixed(2)} Hz\nHarmonics: ${harmonics.length}\nConfidence: ${(confidence * 100).toStringAsFixed(1)}%';
}

/// Multi-note chord detection result
class MultiNoteDetectionResult {
  final List<String> detectedNotes;
  final List<double> fundamentalFrequencies;
  final String chordName;
  final double confidence;

  MultiNoteDetectionResult({
    required this.detectedNotes,
    required this.fundamentalFrequencies,
    required this.chordName,
    required this.confidence,
  });

  factory MultiNoteDetectionResult.empty() {
    return MultiNoteDetectionResult(
      detectedNotes: [],
      fundamentalFrequencies: [],
      chordName: 'Unknown',
      confidence: 0,
    );
  }

  @override
  String toString() =>
      'Chord: $chordName\nNotes: ${detectedNotes.join(", ")}\nFrequencies: ${fundamentalFrequencies.map((f) => f.toStringAsFixed(1)).join(", ")} Hz\nConfidence: ${(confidence * 100).toStringAsFixed(1)}%';
}

/// Octave detection status for practice mode.
enum OctaveStatus {
  correct,
  sharpNote,
  flatNote,
  wrongNotes,
  noInput,
}

/// Result of analysing whether two notes form a target octave.
class OctaveResult {
  final String targetLow;   // e.g. "A2"
  final String targetHigh;  // e.g. "A3"
  final double? detectedLowHz;
  final double? detectedHighHz;
  final int? centsOffLow;
  final int? centsOffHigh;
  final OctaveStatus status;

  const OctaveResult({
    required this.targetLow,
    required this.targetHigh,
    required this.detectedLowHz,
    required this.detectedHighHz,
    required this.centsOffLow,
    required this.centsOffHigh,
    required this.status,
  });

  factory OctaveResult.noInput({
    required String targetLow,
    required String targetHigh,
  }) {
    return OctaveResult(
      targetLow: targetLow,
      targetHigh: targetHigh,
      detectedLowHz: null,
      detectedHighHz: null,
      centsOffLow: null,
      centsOffHigh: null,
      status: OctaveStatus.noInput,
    );
  }
}

/// Complex number for FFT calculations
class Complex {
  double real;
  double imag;

  Complex(this.real, this.imag);

  double get magnitude => sqrt(real * real + imag * imag);
  double get phase => atan2(imag, real);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real,
    );
  }
}

/// STFT Result containing magnitude and phase spectrograms
class STFTResult {
  final List<List<double>> magnitude;
  final List<List<double>> phase;
  final List<double> timeFrames;
  final List<double> frequencyBins;

  STFTResult({
    required this.magnitude,
    required this.phase,
    required this.timeFrames,
    required this.frequencyBins,
  });

  String get shape =>
      '(${magnitude.length}, ${magnitude.isNotEmpty ? magnitude[0].length : 0})';

  List<List<double>> getMagnitudeDB(
      {double refLevel = 1.0, double floor = -80.0}) {
    return magnitude.map((frame) {
      return frame.map((mag) {
        double db = 20 * log(mag / refLevel) / log(10);
        return db.clamp(floor, double.infinity);
      }).toList();
    }).toList();
  }
}

/// Audio frame for streaming processing
class AudioFrame {
  final List<double> samples;        // Windowed samples
  final int frameIndex;
  final bool isComplete;
  final DateTime timestamp;
  
  // New optional fields
  final List<double>? rawFrame;       // Raw audio before processing
  final List<double>? fftData;        // Pre-computed FFT data
  final double? fundamentalFreq;       // Detected fundamental frequency
  final bool gainApplied;              // Whether gain was applied
  final double gainValue;               // Gain value used

  AudioFrame({
    required this.samples,
    required this.frameIndex,
    required this.isComplete,
    DateTime? timestamp,
    this.rawFrame,
    this.fftData,
    this.fundamentalFreq,
    this.gainApplied = false,
    this.gainValue = 1.0,
  }) : timestamp = timestamp ?? DateTime.now();

  double get rmsEnergy {
    if (samples.isEmpty) return 0;
    double sum = samples.fold<double>(0, (a, b) => a + b * b);
    return sqrt(sum / samples.length);
  }

  // Get raw RMS energy (before processing)
  double get rawRmsEnergy {
    if (rawFrame == null || rawFrame!.isEmpty) return 0;
    double sum = rawFrame!.fold<double>(0, (a, b) => a + b * b);
    return sqrt(sum / rawFrame!.length);
  }

  bool hasSignal({double energyThreshold = 0.01}) {
    return rmsEnergy > energyThreshold;
  }

  // Check if this frame contains a valid note
  bool hasValidNote({double minConfidence = 0.3}) {
    return fundamentalFreq != null && 
           fundamentalFreq! > 60 && 
           fundamentalFreq! < 1000 &&
           rmsEnergy > 0.005;
  }

  @override
  String toString() {
    String gainInfo = gainApplied ? ' (gain: ${gainValue.toStringAsFixed(2)}x)' : '';
    String freqInfo = fundamentalFreq != null 
        ? ', Freq: ${fundamentalFreq!.toStringAsFixed(1)} Hz' 
        : '';
    return 'AudioFrame #$frameIndex (${samples.length} samples, RMS: ${rmsEnergy.toStringAsFixed(4)}$gainInfo$freqInfo)';
  }
}

/// Streaming audio processing state
/// Streaming audio processing state
class StreamingAudioState {
  final List<double> currentBuffer;
  final int frameSize;
  final int hopSize;
  int samplesInBuffer = 0;
  int totalFramesProcessed = 0;
  double? lastFundamentalFreq;
  String? lastDetectedChord;
  double lastConfidence = 0;
  DateTime lastProcessedTime = DateTime.now();

  StreamingAudioState({
    required this.frameSize,
    required this.hopSize,
  }) : currentBuffer = List.filled(frameSize, 0.0);

  List<List<double>> addSamples(List<double> newSamples) {
    List<List<double>> readyFrames = [];

    for (double sample in newSamples) {
      if (samplesInBuffer < frameSize) {
        currentBuffer[samplesInBuffer] = sample;
        samplesInBuffer++;
      }

      if (samplesInBuffer >= frameSize) {
        // Create a copy of the complete frame
        readyFrames.add(List<double>.from(currentBuffer));
        totalFramesProcessed++;
        
        // Shift buffer for overlap (keep last hopSize samples)
        if (hopSize < frameSize) {
          // Move the last (frameSize - hopSize) samples to the beginning
          for (int i = 0; i < frameSize - hopSize; i++) {
            currentBuffer[i] = currentBuffer[i + hopSize];
          }
          samplesInBuffer = frameSize - hopSize;
        } else {
          // If hopSize >= frameSize, just reset
          samplesInBuffer = 0;
        }
      }
    }

    return readyFrames;
  }

  void reset() {
    samplesInBuffer = 0;
    totalFramesProcessed = 0;
    lastFundamentalFreq = null;
    lastDetectedChord = null;
    lastConfidence = 0;
    for (int i = 0; i < currentBuffer.length; i++) {
      currentBuffer[i] = 0.0;
    }
  }
}

/// Lightweight container for averaging octave candidates over a short window.
class _OctavePair {
  final double lowHz;
  final double highHz;

  _OctavePair(this.lowHz, this.highHz);
}

