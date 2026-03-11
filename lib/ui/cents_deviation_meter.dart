import 'package:flutter/material.dart';

class CentsDeviationMeter extends StatelessWidget {
  final int? centsOff;
  final String label;

  const CentsDeviationMeter({
    super.key,
    required this.centsOff,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // centsOff is usually between -50 and +50
    double deviation = (centsOff ?? 0).toDouble();
    // clamp to -50..50
    deviation = deviation.clamp(-50.0, 50.0);
    
    // Normalize to 0.0 .. 1.0 where 0.5 is perfectly in tune
    double normalized = (deviation + 50) / 100;
    
    bool hasSignal = centsOff != null;
    Color activeColor = (deviation.abs() <= 15) ? Colors.green : ((deviation < 0) ? Colors.orange : Colors.redAccent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasSignal ? '$label (${centsOff! > 0 ? '+' : ''}$centsOff ¢)' : '$label (--)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Center mark (Perfect pitch)
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  height: 24,
                  color: Colors.white70,
                ),
              ),
              // Needle
              if (hasSignal)
                Align(
                  alignment: FractionalOffset(normalized, 0.5),
                  child: Container(
                    width: 6,
                    height: 24,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withAlpha(128), // 0.5 opacity
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
