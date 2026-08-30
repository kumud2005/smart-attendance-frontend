import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_embedding_service.dart';
import 'liveness_evidence.dart';

class LivenessAnalysisService {
  LivenessAnalysisService({
    FaceEmbeddingService? faceEmbeddingService,
  }) : _faceEmbeddingService =
            faceEmbeddingService ?? FaceEmbeddingService(),
       _faceDetector = FaceDetector(
         options: FaceDetectorOptions(
           enableClassification: true,
           enableLandmarks: true,
           enableContours: false,
           enableTracking: false,
           minFaceSize: 0.15,
           performanceMode: FaceDetectorMode.accurate,
         ),
       );

  final FaceEmbeddingService _faceEmbeddingService;
  final FaceDetector _faceDetector;

  bool _closed = false;

  // ============================================================
  // ANALYZE ONE LIVENESS CAPTURE LOCALLY
  // ============================================================

  Future<LivenessFrameEvidence> analyzeFrame({
    required String imagePath,
    required LivenessChallengeType challenge,
  }) async {
    if (_closed) {
      throw Exception(
        'Liveness analysis service has already been closed.',
      );
    }

    final cleanPath = imagePath.trim();

    if (cleanPath.isEmpty) {
      throw Exception(
        'Liveness capture path cannot be empty.',
      );
    }

    final file = File(cleanPath);

    if (!await file.exists()) {
      throw Exception(
        'Liveness capture was not found on the device.',
      );
    }

    // ----------------------------------------------------------
    // 1. ML KIT FACE / EYE / POSE ANALYSIS
    // ----------------------------------------------------------

    final inputImage =
        InputImage.fromFilePath(cleanPath);

    final faces =
        await _faceDetector.processImage(
      inputImage,
    );

    if (faces.isEmpty) {
      throw Exception(
        'No face detected. Keep your full face visible.',
      );
    }

    if (faces.length > 1) {
      throw Exception(
        'Multiple faces detected. Only one student should be visible.',
      );
    }

    final face = faces.first;

    final yaw = _requiredFiniteValue(
      face.headEulerAngleY,
      'Head pose could not be measured.',
    );

    final pitch = _finiteValueOrZero(
      face.headEulerAngleX,
    );

    final roll = _finiteValueOrZero(
      face.headEulerAngleZ,
    );

    final leftEye =
        _validProbabilityOrNull(
      face.leftEyeOpenProbability,
    );

    final rightEye =
        _validProbabilityOrNull(
      face.rightEyeOpenProbability,
    );

    if (challenge == LivenessChallengeType.neutral ||
        challenge == LivenessChallengeType.blink) {
      if (leftEye == null || rightEye == null) {
        throw Exception(
          'Eye openness could not be measured. '
          'Face the camera more directly and try again.',
        );
      }
    }

    // ----------------------------------------------------------
    // 2. GENERATE 512D FACE EMBEDDING LOCALLY
    // ----------------------------------------------------------

    final embeddingResult =
        await _faceEmbeddingService.generateEmbedding(
      imagePath: cleanPath,
    );

    if (embeddingResult.embedding.length != 512) {
      throw Exception(
        'Invalid local face embedding dimensions.',
      );
    }

    return LivenessFrameEvidence(
      challenge: challenge,

      embedding:
          List<double>.unmodifiable(
        embeddingResult.embedding,
      ),

      embeddingDetectionScore:
          embeddingResult.detectionScore,

      headYaw: yaw,
      headPitch: pitch,
      headRoll: roll,

      leftEyeOpenProbability:
          leftEye,

      rightEyeOpenProbability:
          rightEye,

      imageWidth:
          embeddingResult.imageWidth,

      imageHeight:
          embeddingResult.imageHeight,
    );
  }

  // ============================================================
  // CONVENIENCE METHODS
  // ============================================================

  Future<LivenessFrameEvidence> analyzeNeutral({
    required String imagePath,
  }) {
    return analyzeFrame(
      imagePath: imagePath,
      challenge:
          LivenessChallengeType.neutral,
    );
  }

  Future<LivenessFrameEvidence> analyzeBlink({
    required String imagePath,
  }) {
    return analyzeFrame(
      imagePath: imagePath,
      challenge:
          LivenessChallengeType.blink,
    );
  }

  Future<LivenessFrameEvidence> analyzeTurn({
    required String imagePath,
  }) {
    return analyzeFrame(
      imagePath: imagePath,
      challenge:
          LivenessChallengeType.turn,
    );
  }

  // ============================================================
  // VALIDATION HELPERS
  // ============================================================

  double _requiredFiniteValue(
    double? value,
    String message,
  ) {
    if (value == null ||
        !value.isFinite) {
      throw Exception(message);
    }

    return value;
  }

  double _finiteValueOrZero(
    double? value,
  ) {
    if (value == null ||
        !value.isFinite) {
      return 0.0;
    }

    return value;
  }

  double? _validProbabilityOrNull(
    double? value,
  ) {
    if (value == null ||
        !value.isFinite) {
      return null;
    }

    if (value < 0.0 ||
        value > 1.0) {
      return null;
    }

    return value;
  }

  // ============================================================
  // CLOSE
  // ============================================================

  Future<void> close() async {
    if (_closed) {
      return;
    }

    _closed = true;

    await _faceDetector.close();
    await _faceEmbeddingService.close();
  }
}