import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class FaceEmbeddingResult {
  const FaceEmbeddingResult({
    required this.embedding,
    required this.detectionScore,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<double> embedding;
  final double detectionScore;
  final int imageWidth;
  final int imageHeight;
}

class FaceEmbeddingService {
  FaceEmbeddingService();

  // ============================================================
  // MODEL ASSETS
  // ============================================================

  static const String _detectorAsset =
      'assets/models/det_10g.onnx';

  static const String _recognizerAsset =
      'assets/models/w600k_r50.onnx';

  // ============================================================
  // MODEL SETTINGS
  // ============================================================

  static const int _detectorWidth = 640;
  static const int _detectorHeight = 640;

  static const int _recognizerWidth = 112;
  static const int _recognizerHeight = 112;

  static const double _detectionThreshold = 0.60;
  static const double _nmsThreshold = 0.40;

  static const List<int> _strides = [
    8,
    16,
    32,
  ];

  static const int _anchorsPerLocation = 2;

  // ============================================================
  // INSIGHTFACE ARCFACE DESTINATION LANDMARKS
  // ============================================================

  static const List<List<double>> _arcFaceLandmarks = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041],
  ];

  // ============================================================
  // ONNX
  // ============================================================

  final OnnxRuntime _runtime =
      OnnxRuntime();

  OrtSession? _detectorSession;
  OrtSession? _recognizerSession;

  Future<void>? _initializationFuture;

  // ============================================================
  // INITIALIZE MODELS
  // ============================================================

  Future<void> initialize() {
    final existing =
        _initializationFuture;

    if (existing != null) {
      return existing;
    }

    final future = _initializeInternal();

    _initializationFuture = future;

    return future;
  }

  Future<void> _initializeInternal() async {
    try {
      final detector =
          await _runtime.createSessionFromAsset(
        _detectorAsset,
      );

      final recognizer =
          await _runtime.createSessionFromAsset(
        _recognizerAsset,
      );

      if (detector.inputNames.isEmpty) {
        await detector.close();
        await recognizer.close();

        throw Exception(
          'Face detector model has no input tensor.',
        );
      }

      if (detector.outputNames.length != 9) {
        await detector.close();
        await recognizer.close();

        throw Exception(
          'Unexpected SCRFD detector output count: '
          '${detector.outputNames.length}. '
          'Expected 9 outputs from det_10g.',
        );
      }

      if (recognizer.inputNames.isEmpty ||
          recognizer.outputNames.isEmpty) {
        await detector.close();
        await recognizer.close();

        throw Exception(
          'Face recognition model has an invalid '
          'input/output configuration.',
        );
      }

      _detectorSession = detector;
      _recognizerSession = recognizer;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  // ============================================================
  // GENERATE FACE EMBEDDING
  // ============================================================

  Future<FaceEmbeddingResult> generateEmbedding({
    required String imagePath,
  }) async {
    await initialize();

    final detector =
        _detectorSession;

    final recognizer =
        _recognizerSession;

    if (detector == null ||
        recognizer == null) {
      throw Exception(
        'Face models are not initialized.',
      );
    }

    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception(
        'Captured face image was not found.',
      );
    }

    cv.Mat? source;
    cv.Mat? alignedFace;

    try {
      final bytes =
          await file.readAsBytes();

      source = cv.imdecode(
        bytes,
        cv.IMREAD_COLOR,
      );

      if (source.isEmpty) {
        throw Exception(
          'Unable to decode captured face image.',
        );
      }

      if (source.width < 160 ||
          source.height < 160) {
        throw Exception(
          'Face image resolution is too low.',
        );
      }

      // --------------------------------------------------------
      // 1. DETECT FACE + 5 LANDMARKS
      // --------------------------------------------------------

      final detection =
          await _detectSingleFace(
        source,
        detector,
      );

      // --------------------------------------------------------
      // 2. ALIGN TO INSIGHTFACE 112x112 TEMPLATE
      // --------------------------------------------------------

      alignedFace = _alignFace(
        source,
        detection.keypoints,
      );

      // --------------------------------------------------------
      // 3. RUN ARCFACE
      // --------------------------------------------------------

      final embedding =
          await _runRecognizer(
        alignedFace,
        recognizer,
      );

      return FaceEmbeddingResult(
        embedding: embedding,
        detectionScore:
            detection.score,
        imageWidth:
            source.width,
        imageHeight:
            source.height,
      );
    } finally {
      alignedFace?.dispose();
      source?.dispose();
    }
  }

  // ============================================================
  // DETECT SINGLE FACE
  // ============================================================

  Future<_DetectedFace> _detectSingleFace(
    cv.Mat source,
    OrtSession detector,
  ) async {
    cv.Mat? resized;
    cv.Mat? detectorImage;
    cv.Mat? detectorRoi;

    try {
      final originalWidth =
          source.width;

      final originalHeight =
          source.height;

      final imageRatio =
          originalHeight /
              originalWidth;

      final modelRatio =
          _detectorHeight /
              _detectorWidth;

      late final int resizedWidth;
      late final int resizedHeight;

      if (imageRatio > modelRatio) {
        resizedHeight =
            _detectorHeight;

        resizedWidth =
            (
              resizedHeight /
              imageRatio
            ).round();
      } else {
        resizedWidth =
            _detectorWidth;

        resizedHeight =
            (
              resizedWidth *
              imageRatio
            ).round();
      }

      if (resizedWidth <= 0 ||
          resizedHeight <= 0) {
        throw Exception(
          'Invalid face image dimensions.',
        );
      }

      final detectionScale =
          resizedHeight /
              originalHeight;

      resized = cv.resize(
        source,
        (
          resizedWidth,
          resizedHeight,
        ),
      );

      detectorImage =
          cv.Mat.zeros(
        _detectorHeight,
        _detectorWidth,
        cv.MatType.CV_8UC(3),
      );

      detectorRoi =
          detectorImage.region(
        cv.Rect(
          0,
          0,
          resizedWidth,
          resizedHeight,
        ),
      );

      cv.copyTo(
        resized,
        detectorRoi,
      );

      final inputData =
          _matToNchw(
        detectorImage,
        mean: 127.5,
        std: 128.0,
      );

      final outputs =
          await _runSession(
        session: detector,
        inputData: inputData,
        shape: const [
          1,
          3,
          _detectorHeight,
          _detectorWidth,
        ],
      );

      if (outputs.length != 9) {
        throw Exception(
          'SCRFD returned '
          '${outputs.length} outputs instead of 9.',
        );
      }

      final candidates =
          <_DetectedFace>[];

      const fmc = 3;

      for (var level = 0;
          level < _strides.length;
          level++) {
        final stride =
            _strides[level];

        final scores =
            outputs[level];

        final boxPredictions =
            outputs[level + fmc];

        final landmarkPredictions =
            outputs[level + fmc * 2];

        final featureHeight =
            _detectorHeight ~/
                stride;

        final featureWidth =
            _detectorWidth ~/
                stride;

        final expectedAnchors =
            featureHeight *
                featureWidth *
                _anchorsPerLocation;

        if (scores.length <
            expectedAnchors) {
          throw Exception(
            'Unexpected SCRFD score tensor size '
            'for stride $stride.',
          );
        }

        if (boxPredictions.length <
            expectedAnchors * 4) {
          throw Exception(
            'Unexpected SCRFD bbox tensor size '
            'for stride $stride.',
          );
        }

        if (landmarkPredictions.length <
            expectedAnchors * 10) {
          throw Exception(
            'Unexpected SCRFD landmark tensor size '
            'for stride $stride.',
          );
        }

        var anchorIndex = 0;

        for (var y = 0;
            y < featureHeight;
            y++) {
          for (var x = 0;
              x < featureWidth;
              x++) {
            final centerX =
                x * stride.toDouble();

            final centerY =
                y * stride.toDouble();

            for (var anchor = 0;
                anchor <
                    _anchorsPerLocation;
                anchor++) {
              final score =
                  scores[
                    anchorIndex
                  ];

              if (score >=
                  _detectionThreshold) {
                final boxOffset =
                    anchorIndex * 4;

                final left =
                    boxPredictions[
                      boxOffset
                    ] *
                    stride;

                final top =
                    boxPredictions[
                      boxOffset + 1
                    ] *
                    stride;

                final right =
                    boxPredictions[
                      boxOffset + 2
                    ] *
                    stride;

                final bottom =
                    boxPredictions[
                      boxOffset + 3
                    ] *
                    stride;

                final x1 =
                    (
                      centerX -
                      left
                    ) /
                    detectionScale;

                final y1 =
                    (
                      centerY -
                      top
                    ) /
                    detectionScale;

                final x2 =
                    (
                      centerX +
                      right
                    ) /
                    detectionScale;

                final y2 =
                    (
                      centerY +
                      bottom
                    ) /
                    detectionScale;

                final kps =
                    <_FacePoint>[];

                final kpsOffset =
                    anchorIndex * 10;

                for (var point = 0;
                    point < 5;
                    point++) {
                  final offsetX =
                      landmarkPredictions[
                        kpsOffset +
                            point * 2
                      ] *
                      stride;

                  final offsetY =
                      landmarkPredictions[
                        kpsOffset +
                            point * 2 +
                            1
                      ] *
                      stride;

                  kps.add(
                    _FacePoint(
                      x: (
                            centerX +
                            offsetX
                          ) /
                          detectionScale,

                      y: (
                            centerY +
                            offsetY
                          ) /
                          detectionScale,
                    ),
                  );
                }

                candidates.add(
                  _DetectedFace(
                    score: score,

                    x1: x1,
                    y1: y1,
                    x2: x2,
                    y2: y2,

                    keypoints: kps,
                  ),
                );
              }

              anchorIndex++;
            }
          }
        }
      }

      if (candidates.isEmpty) {
        throw Exception(
          'No face detected. '
          'Keep your full face visible and '
          'look directly at the camera.',
        );
      }

      // --------------------------------------------------------
      // NMS
      // --------------------------------------------------------

      final faces =
          _nonMaximumSuppression(
        candidates,
      );

      if (faces.isEmpty) {
        throw Exception(
          'No usable face was detected.',
        );
      }

      if (faces.length > 1) {
        throw Exception(
          'Multiple faces detected. '
          'Only one student should be visible.',
        );
      }

      return faces.first;
    } finally {
      detectorRoi?.dispose();
      detectorImage?.dispose();
      resized?.dispose();
    }
  }

  // ============================================================
  // NMS
  // ============================================================

  List<_DetectedFace>
      _nonMaximumSuppression(
    List<_DetectedFace> candidates,
  ) {
    final ordered =
        List<_DetectedFace>.from(
      candidates,
    )
          ..sort(
            (a, b) =>
                b.score.compareTo(
              a.score,
            ),
          );

    final kept =
        <_DetectedFace>[];

    while (ordered.isNotEmpty) {
      final current =
          ordered.removeAt(0);

      kept.add(current);

      ordered.removeWhere(
        (candidate) {
          final overlap =
              _intersectionOverUnion(
            current,
            candidate,
          );

          return overlap >
              _nmsThreshold;
        },
      );
    }

    return kept;
  }

  double _intersectionOverUnion(
    _DetectedFace a,
    _DetectedFace b,
  ) {
    final intersectionX1 =
        math.max(
      a.x1,
      b.x1,
    );

    final intersectionY1 =
        math.max(
      a.y1,
      b.y1,
    );

    final intersectionX2 =
        math.min(
      a.x2,
      b.x2,
    );

    final intersectionY2 =
        math.min(
      a.y2,
      b.y2,
    );

    final width =
        math.max(
      0.0,
      intersectionX2 -
          intersectionX1 +
          1.0,
    );

    final height =
        math.max(
      0.0,
      intersectionY2 -
          intersectionY1 +
          1.0,
    );

    final intersection =
        width * height;

    final areaA =
        math.max(
          0.0,
          a.x2 - a.x1 + 1.0,
        ) *
        math.max(
          0.0,
          a.y2 - a.y1 + 1.0,
        );

    final areaB =
        math.max(
          0.0,
          b.x2 - b.x1 + 1.0,
        ) *
        math.max(
          0.0,
          b.y2 - b.y1 + 1.0,
        );

    final union =
        areaA +
            areaB -
            intersection;

    if (union <= 0) {
      return 0;
    }

    return intersection /
        union;
  }

  // ============================================================
  // ALIGN FACE
  // ============================================================

  cv.Mat _alignFace(
    cv.Mat source,
    List<_FacePoint> keypoints,
  ) {
    if (keypoints.length != 5) {
      throw Exception(
        'Exactly five facial landmarks are required.',
      );
    }

    final sourcePoints =
        keypoints
            .map(
              (point) => cv.Point2f(
                point.x,
                point.y,
              ),
            )
            .toList();

    final destinationPoints =
        _arcFaceLandmarks
            .map(
              (point) => cv.Point2f(
                point[0],
                point[1],
              ),
            )
            .toList();

    cv.VecPoint2f? from;
    cv.VecPoint2f? to;
    cv.Mat? affine;
    cv.Mat? inliers;

    try {
      from =
          cv.VecPoint2f.fromList(
        sourcePoints,
      );

      to =
          cv.VecPoint2f.fromList(
        destinationPoints,
      );

      final result =
          cv.estimateAffinePartial2D(
        from,
        to,
      );

      affine = result.$1;
      inliers = result.$2;

      if (affine.isEmpty) {
        throw Exception(
          'Face alignment could not be calculated.',
        );
      }

      return cv.warpAffine(
        source,
        affine,
        (
          _recognizerWidth,
          _recognizerHeight,
        ),
      );
    } finally {
      inliers?.dispose();
      affine?.dispose();

      from?.dispose();
      to?.dispose();

      for (final point
          in sourcePoints) {
        point.dispose();
      }

      for (final point
          in destinationPoints) {
        point.dispose();
      }
    }
  }

  // ============================================================
  // RUN ARCFACE RECOGNIZER
  // ============================================================

  Future<List<double>> _runRecognizer(
    cv.Mat alignedFace,
    OrtSession recognizer,
  ) async {
    if (alignedFace.width !=
            _recognizerWidth ||
        alignedFace.height !=
            _recognizerHeight) {
      throw Exception(
        'Aligned face must be 112x112.',
      );
    }

    final input =
        _matToNchw(
      alignedFace,
      mean: 127.5,
      std: 127.5,
    );

    final outputs =
        await _runSession(
      session: recognizer,
      inputData: input,
      shape: const [
        1,
        3,
        _recognizerHeight,
        _recognizerWidth,
      ],
    );

    if (outputs.isEmpty) {
      throw Exception(
        'Face recognition model returned no embedding.',
      );
    }

    final rawEmbedding =
        outputs.first;

    if (rawEmbedding.length != 512) {
      throw Exception(
        'Unexpected face embedding dimensions: '
        '${rawEmbedding.length}. Expected 512.',
      );
    }

    return _l2Normalize(
      rawEmbedding,
    );
  }

  // ============================================================
  // MAT -> NCHW FLOAT32
  // ============================================================

  Float32List _matToNchw(
    cv.Mat image, {
    required double mean,
    required double std,
  }) {
    if (image.channels != 3) {
      throw Exception(
        'Expected a 3-channel BGR image.',
      );
    }

    final width =
        image.width;

    final height =
        image.height;

    final pixels =
        width * height;

    final data =
        image.data;

    if (data.length <
        pixels * 3) {
      throw Exception(
        'OpenCV image buffer is incomplete.',
      );
    }

    final tensor =
        Float32List(
      pixels * 3,
    );

    // OpenCV = BGR.
    // InsightFace blobFromImage(... swapRB: true)
    // means ONNX receives RGB in NCHW layout.

    for (var index = 0;
        index < pixels;
        index++) {
      final sourceOffset =
          index * 3;

      final blue =
          data[sourceOffset]
              .toDouble();

      final green =
          data[sourceOffset + 1]
              .toDouble();

      final red =
          data[sourceOffset + 2]
              .toDouble();

      tensor[index] =
          (red - mean) /
              std;

      tensor[pixels + index] =
          (green - mean) /
              std;

      tensor[
        pixels * 2 + index
      ] =
          (blue - mean) /
              std;
    }

    return tensor;
  }

  // ============================================================
  // GENERIC ONNX SESSION
  // ============================================================

  Future<List<List<double>>> _runSession({
    required OrtSession session,
    required Float32List inputData,
    required List<int> shape,
  }) async {
    final inputName =
        session.inputNames.first;

    final inputValue =
        await OrtValue.fromList(
      inputData,
      shape,
    );

    Map<String, OrtValue>?
        outputValues;

    try {
      outputValues =
          await session.run(
        {
          inputName: inputValue,
        },
      );

      final outputs =
          <List<double>>[];

      for (final outputName
          in session.outputNames) {
        final value =
            outputValues[
              outputName
            ];

        if (value == null) {
          throw Exception(
            'ONNX output "$outputName" '
            'was not returned.',
          );
        }

        final flattened =
            await value
                .asFlattenedList();

        outputs.add(
          flattened
              .map(
                (value) =>
                    (value as num)
                        .toDouble(),
              )
              .toList(
                growable: false,
              ),
        );
      }

      return outputs;
    } finally {
      await inputValue.dispose();

      if (outputValues != null) {
        for (final value
            in outputValues.values) {
          await value.dispose();
        }
      }
    }
  }

  // ============================================================
  // L2 NORMALIZATION
  // ============================================================

  List<double> _l2Normalize(
    List<double> values,
  ) {
    var sumSquares = 0.0;

    for (final value in values) {
      sumSquares +=
          value * value;
    }

    final norm =
        math.sqrt(
      sumSquares,
    );

    if (!norm.isFinite ||
        norm <= 0) {
      throw Exception(
        'Generated face embedding is invalid.',
      );
    }

    return values
        .map(
          (value) =>
              value / norm,
        )
        .toList(
          growable: false,
        );
  }

  // ============================================================
  // CLOSE MODELS
  // ============================================================

  Future<void> close() async {
    final detector =
        _detectorSession;

    final recognizer =
        _recognizerSession;

    _detectorSession = null;
    _recognizerSession = null;

    _initializationFuture = null;

    if (detector != null) {
      await detector.close();
    }

    if (recognizer != null) {
      await recognizer.close();
    }
  }
}

// ============================================================
// INTERNAL FACE
// ============================================================

class _DetectedFace {
  const _DetectedFace({
    required this.score,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.keypoints,
  });

  final double score;

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  final List<_FacePoint> keypoints;
}

// ============================================================
// INTERNAL POINT
// ============================================================

class _FacePoint {
  const _FacePoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}