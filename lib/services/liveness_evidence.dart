enum LivenessChallengeType {
  neutral,
  blink,
  turn,
}

class LivenessFrameEvidence {
  const LivenessFrameEvidence({
    required this.challenge,
    required this.embedding,
    required this.embeddingDetectionScore,
    required this.headYaw,
    required this.headPitch,
    required this.headRoll,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.imageWidth,
    required this.imageHeight,
  });

  final LivenessChallengeType challenge;

  final List<double> embedding;

  final double embeddingDetectionScore;

  final double headYaw;
  final double headPitch;
  final double headRoll;

  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;

  final int imageWidth;
  final int imageHeight;

  double? get averageEyeOpenProbability {
    final left = leftEyeOpenProbability;
    final right = rightEyeOpenProbability;

    if (left == null || right == null) {
      return null;
    }

    return (left + right) / 2.0;
  }
}