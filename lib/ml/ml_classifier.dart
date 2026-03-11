import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class MLChordClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Load the Model and labels
  Future<void> initialize() async {
    try {
      // Load interpreter Options
      final options = InterpreterOptions()..threads = 1;
      _interpreter = await Interpreter.fromAsset('assets/models/chord_classifier.tflite', options: options);

      // Load Labels
      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData.split('\n').where((s) => s.trim().isNotEmpty).toList();

      _isInitialized = true;
      print('✅ ML Model loaded successfully with ${_labels.length} labels.');
    } catch (e) {
      print('❌ Failed to load model: $e');
    }
  }

  /// Run Inference on a Log-Mel Spectrogram 2D array
  /// [melSpectrogram] expects shape [mels, frames]
  String classify(List<List<double>> melSpectrogram) {
    if (!_isInitialized || _interpreter == null) return 'Unknown';

    // Model expected shape: [1, 64, 128, 1]
    const int height = 64;
    const int width = 128;
    
    // Flatten and convert input to exactly what tflite_flutter expects (multi-dimensional List)
    // Create zero-padded 4D tensor: [batch, height, width, channels]
    var input = List.generate(
      1,
      (b) => List.generate(
        height,
        (h) => List.generate(
          width,
          (w) => [(w < melSpectrogram.length && h < melSpectrogram[0].length) ? melSpectrogram[w][h] : -80.0],
        ),
      ),
    );

    // Output tensor shape: [1, num_classes]
    var output = List.generate(1, (i) => List.filled(_labels.length, 0.0));

    try {
      _interpreter!.run(input, output);
      
      // Find probability peak
      var probabilities = output[0];
      int maxIndex = 0;
      double maxProb = 0.0;
      
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      if (maxProb < 0.3) {
        return 'Unknown'; // Confidence threshold
      }

      return _labels[maxIndex];
    } catch (e) {
      print('❌ Inference error: $e');
      return 'Unknown';
    }
  }

  void close() {
    _interpreter?.close();
  }
}
