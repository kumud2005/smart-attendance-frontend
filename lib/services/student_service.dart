import '../core/network/api_client.dart';
import 'liveness_evidence.dart';

class StudentService {
  StudentService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // ============================================================
  // FACE MODEL SETTINGS
  // ============================================================

  static const String faceModelName =
      'w600k_r50';

  static const int faceEmbeddingDimensions =
      512;

  // ============================================================
  // STUDENT DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> getDashboard() async {
    final response =
        await _apiClient.get(
      '/student/dashboard',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid student dashboard response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // STUDENT ATTENDANCE REPORT
  // ============================================================

  Future<Map<String, dynamic>>
      getAttendanceReport() async {
    final response =
        await _apiClient.get(
      '/student/attendance/report',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid student attendance report response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // ACTIVE / RESUMABLE ATTENDANCE ATTEMPT
  // ============================================================

  Future<Map<String, dynamic>>
      getActiveAttendanceAttempt() async {
    final response =
        await _apiClient.get(
      '/student/attendance/active-attempt',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid active attendance response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // MARK ATTENDANCE USING QR
  // ============================================================

  Future<Map<String, dynamic>> markAttendance({
    required String qrData,
    double? latitude,
    double? longitude,
  }) async {
    final cleanQrData =
        qrData.trim();

    if (cleanQrData.isEmpty) {
      throw Exception(
        'QR data cannot be empty.',
      );
    }

    final response =
        await _apiClient.post(
      '/student/attendance/mark',
      body: {
        'qr_data':
            cleanQrData,

        'latitude':
            latitude,

        'longitude':
            longitude,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid attendance response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // VERIFY GEOFENCE
  // ============================================================

  Future<Map<String, dynamic>>
      verifyGeofence({
    required int attendanceId,
    required double latitude,
    required double longitude,
  }) async {
    if (attendanceId <= 0) {
      throw Exception(
        'Invalid attendance record.',
      );
    }

    if (
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90
    ) {
      throw Exception(
        'Latitude must be between -90 and 90.',
      );
    }

    if (
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180
    ) {
      throw Exception(
        'Longitude must be between -180 and 180.',
      );
    }

    final response =
        await _apiClient.post(
      '/student/attendance/'
      '$attendanceId/geofence',
      body: {
        'latitude':
            latitude,

        'longitude':
            longitude,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid geofence response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // FACE REGISTRATION STATUS
  // ============================================================

  Future<Map<String, dynamic>>
      getFaceStatus() async {
    final response =
        await _apiClient.get(
      '/student/face/status',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid face status response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // REGISTER FACE EMBEDDING
  // ============================================================

  Future<Map<String, dynamic>>
      registerFace({
    required List<double> faceEmbedding,
  }) async {
    _validateFaceEmbedding(
      faceEmbedding,
    );

    final response =
        await _apiClient.post(
      '/student/face/register',
      body: {
        'face_embedding':
            faceEmbedding,

        'embedding_dimensions':
            faceEmbeddingDimensions,

        'model_name':
            faceModelName,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid face registration response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // VERIFY FACE FOR ATTENDANCE
  // ============================================================

  Future<Map<String, dynamic>>
      verifyFace({
    required int attendanceId,
    required List<double> faceEmbedding,
  }) async {
    if (attendanceId <= 0) {
      throw Exception(
        'Invalid attendance record.',
      );
    }

    _validateFaceEmbedding(
      faceEmbedding,
    );

    final response =
        await _apiClient.post(
      '/student/attendance/'
      '$attendanceId/face-embedding',
      body: {
        'embedding':
            faceEmbedding,

        'model_name':
            faceModelName,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid face verification response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // VERIFY LIVENESS USING LOCAL NUMERIC EVIDENCE
  // ============================================================

  Future<Map<String, dynamic>>
      verifyLiveness({
    required int attendanceId,
    required LivenessFrameEvidence neutralEvidence,
    required LivenessFrameEvidence blinkEvidence,
    required LivenessFrameEvidence turnEvidence,
  }) async {
    if (attendanceId <= 0) {
      throw Exception(
        'Invalid attendance record.',
      );
    }

    if (
        neutralEvidence.challenge
        != LivenessChallengeType.neutral
    ) {
      throw Exception(
        'Invalid neutral liveness evidence.',
      );
    }

    if (
        blinkEvidence.challenge
        != LivenessChallengeType.blink
    ) {
      throw Exception(
        'Invalid blink liveness evidence.',
      );
    }

    if (
        turnEvidence.challenge
        != LivenessChallengeType.turn
    ) {
      throw Exception(
        'Invalid head-turn liveness evidence.',
      );
    }

    _validateLivenessEvidence(
      neutralEvidence,
      requireEyeProbabilities: true,
    );

    _validateLivenessEvidence(
      blinkEvidence,
      requireEyeProbabilities: true,
    );

    _validateLivenessEvidence(
      turnEvidence,
      requireEyeProbabilities: false,
    );

    final response =
        await _apiClient.post(
      '/student/attendance/'
      '$attendanceId/liveness',
      body: {
        'model_name':
            faceModelName,

        'embedding_dimensions':
            faceEmbeddingDimensions,

        'neutral':
            _livenessEvidenceBody(
          neutralEvidence,
        ),

        'blink':
            _livenessEvidenceBody(
          blinkEvidence,
        ),

        'turn':
            _livenessEvidenceBody(
          turnEvidence,
        ),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid liveness response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // LIVENESS EVIDENCE JSON
  // ============================================================

  Map<String, dynamic> _livenessEvidenceBody(
    LivenessFrameEvidence evidence,
  ) {
    return {
      'embedding':
          evidence.embedding,

      'left_eye_open_probability':
          evidence.leftEyeOpenProbability,

      'right_eye_open_probability':
          evidence.rightEyeOpenProbability,

      'head_yaw':
          evidence.headYaw,

      'head_pitch':
          evidence.headPitch,

      'head_roll':
          evidence.headRoll,

      'detection_score':
          evidence.embeddingDetectionScore,
    };
  }

  // ============================================================
  // VALIDATE LIVENESS EVIDENCE
  // ============================================================

  void _validateLivenessEvidence(
    LivenessFrameEvidence evidence, {
    required bool requireEyeProbabilities,
  }) {
    _validateFaceEmbedding(
      evidence.embedding,
    );

    if (!evidence.embeddingDetectionScore.isFinite) {
      throw Exception(
        'Invalid face detection score.',
      );
    }

    if (
        evidence.embeddingDetectionScore < 0 ||
        evidence.embeddingDetectionScore > 1
    ) {
      throw Exception(
        'Face detection score is outside the valid range.',
      );
    }

    if (!evidence.headYaw.isFinite ||
        !evidence.headPitch.isFinite ||
        !evidence.headRoll.isFinite) {
      throw Exception(
        'Invalid head-pose evidence.',
      );
    }

    final left =
        evidence.leftEyeOpenProbability;

    final right =
        evidence.rightEyeOpenProbability;

    if (requireEyeProbabilities &&
        (left == null || right == null)) {
      throw Exception(
        'Eye openness evidence is required.',
      );
    }

    if (left != null) {
      _validateProbability(
        left,
        'left-eye',
      );
    }

    if (right != null) {
      _validateProbability(
        right,
        'right-eye',
      );
    }
  }

  void _validateProbability(
    double value,
    String label,
  ) {
    if (
        !value.isFinite ||
        value < 0 ||
        value > 1
    ) {
      throw Exception(
        'Invalid $label probability.',
      );
    }
  }

  // ============================================================
  // VALIDATE FACE EMBEDDING
  // ============================================================

  void _validateFaceEmbedding(
    List<double> embedding,
  ) {
    if (
        embedding.length
        != faceEmbeddingDimensions
    ) {
      throw Exception(
        'Invalid face embedding dimensions. '
        'Expected $faceEmbeddingDimensions values, '
        'received ${embedding.length}.',
      );
    }

    var hasNonZeroValue = false;

    for (final value in embedding) {
      if (!value.isFinite) {
        throw Exception(
          'Face embedding contains invalid values.',
        );
      }

      if (value.abs() > 1e-12) {
        hasNonZeroValue = true;
      }
    }

    if (!hasNonZeroValue) {
      throw Exception(
        'Face embedding is invalid.',
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _apiClient.dispose();
  }
}
