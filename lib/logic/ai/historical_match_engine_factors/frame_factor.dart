// lib/logic/ai/historical_match_engine_factors/frame_factor.dart

class FrameFactorResult {
  final double score;
  final double relativePos;
  final String zone;
  final bool isGateFixed;

  FrameFactorResult({
    required this.score,
    required this.relativePos,
    required this.zone,
    required this.isGateFixed,
  });
}

class FrameFactor {
  FrameFactorResult analyze(int gateNumber, int totalHorses, Map<String, double> zoneWinRates, double maxRate) {
    double frameScore = 0.0;
    double relativePos = 0.0;
    String zone = '-';
    bool isGateFixed = gateNumber > 0;

    if (isGateFixed) {
      relativePos = (totalHorses > 1) ? (gateNumber - 1) / (totalHorses - 1) : 0.0;
      zone = getZone(relativePos);
      if (maxRate > 0) {
        final rate = zoneWinRates[zone] ?? 0.0;
        frameScore = (rate / maxRate) * 100.0;
      }
    }

    return FrameFactorResult(
      score: frameScore,
      relativePos: relativePos,
      zone: zone,
      isGateFixed: isGateFixed,
    );
  }

  static String getZone(double p) => p <= 0.33 ? '内' : p <= 0.66 ? '中' : '外';
}