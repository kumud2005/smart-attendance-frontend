import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../core/theme/app_theme.dart';

import '../../services/face_embedding_service.dart';
import '../../services/student_service.dart';
import 'student_liveness_screen.dart';

class StudentFaceScreen extends StatefulWidget {
  const StudentFaceScreen({
    super.key,
    required this.attendanceId,
    required this.attendanceData,
  });

  final int attendanceId;
  final Map<String, dynamic> attendanceData;

  @override
  State<StudentFaceScreen> createState() =>
      _StudentFaceScreenState();
}

class _StudentFaceScreenState
    extends State<StudentFaceScreen>
    with WidgetsBindingObserver {
  final StudentService _studentService =
      StudentService();

  final FaceEmbeddingService _faceEmbeddingService =
      FaceEmbeddingService();

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;

  bool _initializingCamera = true;
  bool _capturing = false;
  bool _verifying = false;

  String? _capturedImagePath;
  String? _errorMessage;

  double? _brightnessScore;
  double? _sharpnessScore;

  Map<String, dynamic>? _result;

  // ============================================================
  // QUALITY SETTINGS
  // ============================================================

  static const double _minimumBrightness = 55.0;
  static const double _maximumBrightness = 215.0;

  // Laplacian variance.
  //
  // Start fairly leniently. We can tune this after testing
  // using the actual student phone camera.
  static const double _minimumSharpness = 45.0;

  static const int _minimumImageWidth = 320;
  static const int _minimumImageHeight = 320;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeCamera();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state ==
        AppLifecycleState.inactive) {
      controller.dispose();

      _cameraController = null;

      return;
    }

    if (state ==
        AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // ============================================================
  // INITIALIZE CAMERA
  // ============================================================

  Future<void> _initializeCamera() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _initializingCamera = true;
      _errorMessage = null;
    });

    try {
      final cameras =
          await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'No camera was found on this device.',
        );
      }

      CameraDescription selectedCamera =
          cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection ==
            CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      final oldController =
          _cameraController;

      if (oldController != null) {
        await oldController.dispose();
      }

      final controller =
          CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      // --------------------------------------------------------
      // CAMERA QUALITY SETTINGS
      // --------------------------------------------------------

      try {
        await controller.setFlashMode(
          FlashMode.off,
        );
      } catch (_) {
        // Some devices may not expose this on the front camera.
      }

      try {
        await controller.setFocusMode(
          FocusMode.auto,
        );
      } catch (_) {
        // Automatic focus may not be configurable on all devices.
      }

      try {
        await controller.setExposureMode(
          ExposureMode.auto,
        );
      } catch (_) {
        // Automatic exposure may not be configurable.
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraDescription =
            selectedCamera;

        _initializingCamera = false;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initializingCamera = false;

        if (error.code ==
            'CameraAccessDenied') {
          _errorMessage =
              'Camera permission was denied. '
              'Please allow camera access and try again.';
        } else {
          _errorMessage =
              'Camera error: ${error.description ?? error.code}';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initializingCamera = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  // ============================================================
  // CAPTURE FACE
  // ============================================================

  Future<void> _captureFace() async {
    if (_capturing ||
        _verifying) {
      return;
    }

    final controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      _showMessage(
        'Camera is not ready.',
      );

      return;
    }

    setState(() {
      _capturing = true;
      _errorMessage = null;

      _capturedImagePath = null;

      _brightnessScore = null;
      _sharpnessScore = null;

      _result = null;
    });

    try {
      final image =
          await controller.takePicture();

      final quality =
          await _checkImageQuality(
        image.path,
      );

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // REJECT BAD IMAGE BEFORE BACKEND REQUEST
      // --------------------------------------------------------

      if (!quality.accepted) {
        await _deleteFileSafely(
          image.path,
        );

        setState(() {
          _capturing = false;

          _brightnessScore =
              quality.brightness;

          _sharpnessScore =
              quality.sharpness;

          _errorMessage =
              quality.message;
        });

        return;
      }

      // --------------------------------------------------------
      // ACCEPTED
      // --------------------------------------------------------

      setState(() {
        _capturing = false;

        _capturedImagePath =
            image.path;

        _brightnessScore =
            quality.brightness;

        _sharpnessScore =
            quality.sharpness;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _capturing = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  // ============================================================
  // OPENCV IMAGE QUALITY CHECK
  // ============================================================

  Future<_FaceImageQuality>
      _checkImageQuality(
    String imagePath,
  ) async {
    cv.Mat? source;
    cv.Mat? gray;
    cv.Mat? laplacian;

    cv.Scalar? brightnessMean;
    cv.Scalar? laplacianMean;
    cv.Scalar? laplacianStdDev;

    try {
      final bytes =
          await File(
        imagePath,
      ).readAsBytes();

      source = cv.imdecode(
        bytes,
        cv.IMREAD_COLOR,
      );

      if (source.isEmpty) {
        return const _FaceImageQuality(
          accepted: false,
          message:
              'The captured image could not be decoded.',
        );
      }

      // --------------------------------------------------------
      // RESOLUTION
      // --------------------------------------------------------

      if (source.width <
              _minimumImageWidth ||
          source.height <
              _minimumImageHeight) {
        return _FaceImageQuality(
          accepted: false,
          message:
              'Image resolution is too low. '
              'Hold the phone steady and capture again.',
          width: source.width,
          height: source.height,
        );
      }

      // --------------------------------------------------------
      // GRAYSCALE
      // --------------------------------------------------------

      gray = cv.cvtColor(
        source,
        cv.COLOR_BGR2GRAY,
      );

      // --------------------------------------------------------
      // BRIGHTNESS
      // --------------------------------------------------------

      brightnessMean =
          cv.mean(gray);

      final brightness =
          brightnessMean.val1;

      if (brightness <
          _minimumBrightness) {
        return _FaceImageQuality(
          accepted: false,
          brightness: brightness,
          message:
              'The image is too dark. '
              'Move to a brighter area and capture again.',
          width: source.width,
          height: source.height,
        );
      }

      if (brightness >
          _maximumBrightness) {
        return _FaceImageQuality(
          accepted: false,
          brightness: brightness,
          message:
              'The image is overexposed. '
              'Avoid very bright light directly behind or '
              'in front of your face.',
          width: source.width,
          height: source.height,
        );
      }

      // --------------------------------------------------------
      // SHARPNESS / BLUR CHECK
      //
      // Laplacian variance is a common blur measurement:
      //
      // Low variance  -> blurry image
      // High variance -> sharper image
      // --------------------------------------------------------

      laplacian =
          cv.laplacian(
        gray,
        cv.MatType.CV_64F,
      );

      final statistics =
          cv.meanStdDev(
        laplacian,
      );

      laplacianMean =
          statistics.$1;

      laplacianStdDev =
          statistics.$2;

      final standardDeviation =
          laplacianStdDev.val1;

      final sharpness =
          standardDeviation *
              standardDeviation;

      if (sharpness <
          _minimumSharpness) {
        return _FaceImageQuality(
          accepted: false,
          brightness: brightness,
          sharpness: sharpness,
          message:
              'The face image appears blurry. '
              'Hold the phone steady, keep your face still, '
              'and capture again.',
          width: source.width,
          height: source.height,
        );
      }

      // --------------------------------------------------------
      // PASSED
      // --------------------------------------------------------

      return _FaceImageQuality(
        accepted: true,
        brightness: brightness,
        sharpness: sharpness,
        width: source.width,
        height: source.height,
        message:
            'Image quality is suitable for face verification.',
      );
    } catch (error) {
      return _FaceImageQuality(
        accepted: false,
        message:
            'OpenCV could not validate the image: '
            '${_cleanErrorMessage(error)}',
      );
    } finally {
      laplacianStdDev?.dispose();
      laplacianMean?.dispose();
      brightnessMean?.dispose();

      laplacian?.dispose();
      gray?.dispose();
      source?.dispose();
    }
  }

  // ============================================================
  // VERIFY FACE
  // ============================================================

  Future<void> _verifyFace() async {
    final imagePath =
        _capturedImagePath;

    if (imagePath == null) {
      _showMessage(
        'Capture a clear face image first.',
      );

      return;
    }

    if (_verifying) {
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      // --------------------------------------------------------
      // 1. GENERATE CURRENT FACE EMBEDDING LOCALLY
      // --------------------------------------------------------
      //
      // The captured image stays on this device.
      // det_10g + ArcFace alignment + w600k_r50 run locally.

      final embeddingResult =
          await _faceEmbeddingService.generateEmbedding(
        imagePath: imagePath,
      );

      // --------------------------------------------------------
      // 2. SEND ONLY THE 512D EMBEDDING TO FASTAPI
      // --------------------------------------------------------

      final result =
          await _studentService.verifyFace(
        attendanceId:
            widget.attendanceId,

        faceEmbedding:
            embeddingResult.embedding,
      );

      // The temporary camera image is no longer required after
      // the backend has received the numeric embedding.
      await _deleteFileSafely(
        imagePath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedImagePath = null;
        _verifying = false;
        _result = result;
      });

      final faceVerified =
          result['face_verified'] == true;

      final attendanceStatus =
          result['attendance_status']
              ?.toString()
              .toUpperCase();

      final nextStep =
          result['next_verification_step']
              ?.toString()
              .toUpperCase();

      // --------------------------------------------------------
      // 3. SUCCESS
      // --------------------------------------------------------

      if (faceVerified &&
          attendanceStatus !=
              'REJECTED' &&
          nextStep == 'LIVENESS') {
        _showFaceSuccessDialog(
          result,
        );

        return;
      }

      // --------------------------------------------------------
      // 4. REJECTED
      // --------------------------------------------------------

      if (attendanceStatus ==
          'REJECTED') {
        _showFaceRejectedDialog(
          result,
        );

        return;
      }

      // --------------------------------------------------------
      // 5. UNEXPECTED RESPONSE STATE
      // --------------------------------------------------------

      setState(() {
        _errorMessage =
            'Face verification returned an unexpected response.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verifying = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  // ============================================================
  // CAPTURE AGAIN
  // ============================================================

  Future<void> _captureAgain() async {
    final oldPath =
        _capturedImagePath;

    if (oldPath != null) {
      await _deleteFileSafely(
        oldPath,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _capturedImagePath = null;

      _brightnessScore = null;
      _sharpnessScore = null;

      _result = null;
      _errorMessage = null;
    });
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  void _showFaceSuccessDialog(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

    final similarity =
        _numberValue(
      result['face_similarity'],
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Face Verified',
                ),
              ),
            ],
          ),
          content: Text(
            similarity == null
                ? 'Your face was verified successfully.'
                : 'Your face was verified successfully.\n\n'
                    'Similarity: '
                    '${similarity.toStringAsFixed(4)}',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                Navigator.of(
                  dialogContext,
                ).pop();

                // Release the face-verification camera completely
                // before the liveness screen tries to open it.
                // Some Android devices need a short hand-off delay.
                final controller =
                    _cameraController;

                _cameraController = null;

                if (controller != null) {
                  try {
                    await controller.dispose();
                  } catch (_) {
                    // Camera may already be releasing.
                  }
                }

                await Future<void>.delayed(
                  const Duration(
                    milliseconds: 400,
                  ),
                );

                if (!mounted) {
                  return;
                }

                Navigator.of(context)
                    .pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentLivenessScreen(
                      attendanceId:
                          widget.attendanceId,
                    ),
                  ),
                );
              },
              child: const Text(
                'Continue',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // REJECTED DIALOG
  // ============================================================

  void _showFaceRejectedDialog(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

    final reason =
        result['rejection_reason']
            ?.toString()
            .trim();

    final similarity =
        _numberValue(
      result['face_similarity'],
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.cancel_rounded,
                color: AppColors.error,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Face Verification Failed',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                reason == null ||
                        reason.isEmpty
                    ? 'Your face could not be verified.'
                    : reason,
              ),
              if (similarity != null) ...[
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Similarity: '
                  '${similarity.toStringAsFixed(4)}',
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                Navigator.of(context)
                    .pop();
              },
              child: const Text(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double? _numberValue(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  String _cleanErrorMessage(
    Object error,
  ) {
    final message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  Future<void> _deleteFileSafely(
    String path,
  ) async {
    try {
      final file =
          File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary image cleanup failure is non-critical.
    }
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    _cameraController?.dispose();

    final capturedPath =
        _capturedImagePath;

    if (capturedPath != null) {
      unawaited(
        _deleteFileSafely(
          capturedPath,
        ),
      );
    }

    unawaited(
      _faceEmbeddingService.close(),
    );

    _studentService.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final subject =
        widget.attendanceData[
              'subject_name'
            ]?.toString() ??
            '-';

    final section =
        widget.attendanceData[
              'section_name'
            ]?.toString() ??
            '-';

    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Face Verification',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 650,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verify Your Face',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    '$subject • Section $section',
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildCameraCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildInstructions(),

                  if (_brightnessScore !=
                          null ||
                      _sharpnessScore !=
                          null) ...[
                    const SizedBox(
                      height: 16,
                    ),
                    _buildQualityCard(),
                  ],

                  if (_errorMessage !=
                      null) ...[
                    const SizedBox(
                      height: 16,
                    ),
                    _buildErrorCard(),
                  ],

                  if (_result != null) ...[
                    const SizedBox(
                      height: 16,
                    ),
                    _buildResultCard(),
                  ],

                  const SizedBox(
                    height: 20,
                  ),

                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA CARD
  // ============================================================

  Widget _buildCameraCard() {
    final path =
        _capturedImagePath;

    if (_initializingCamera) {
      return const Card(
        child: SizedBox(
          height: 430,
          child: Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (path != null) {
      return Card(
        clipBehavior:
            Clip.antiAlias,
        child: SizedBox(
          height: 430,
          width: double.infinity,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return Card(
        child: SizedBox(
          height: 430,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons
                        .no_photography_rounded,
                    size: 60,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'Camera unavailable',
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  OutlinedButton(
                    onPressed:
                        _initializeCamera,
                    child: const Text(
                      'Retry Camera',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: SizedBox(
        height: 430,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(
              controller,
            ),

            // --------------------------------------------------
            // DARK EDGE OVERLAY
            // --------------------------------------------------

            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  width: 18,
                  color: Colors.black
                      .withValues(
                    alpha: 0.12,
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // FACE GUIDE
            // --------------------------------------------------

            Center(
              child: Container(
                width: 225,
                height: 290,
                decoration:
                    BoxDecoration(
                  borderRadius:
                      const BorderRadius
                          .all(
                    Radius.elliptical(
                      115,
                      145,
                    ),
                  ),
                  border: Border.all(
                    color:
                        Colors.white,
                    width: 3,
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // CAMERA LABEL
            // --------------------------------------------------

            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.black
                      .withValues(
                    alpha: 0.50,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child: const Text(
                  'Position your face inside the guide',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.black
                      .withValues(
                    alpha: 0.45,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child: Text(
                  _cameraDescription
                              ?.lensDirection ==
                          CameraLensDirection
                              .front
                      ? 'Front camera • Auto focus • Auto exposure'
                      : 'Camera • Auto focus • Auto exposure',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INSTRUCTIONS
  // ============================================================

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'For the best result',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
                fontSize: 16,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _instruction(
              Icons.light_mode_rounded,
              'Use even lighting on your face.',
            ),

            _instruction(
              Icons.center_focus_strong,
              'Keep your face centered in the guide.',
            ),

            _instruction(
              Icons.pan_tool_alt_rounded,
              'Hold the phone steady.',
            ),

            _instruction(
              Icons.face_rounded,
              'Look directly at the camera.',
            ),

            _instruction(
              Icons.group_off_rounded,
              'Only one person should be visible.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _instruction(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color:
                AppColors.primary,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUALITY
  // ============================================================

  Widget _buildQualityCard() {
    final brightness =
        _brightnessScore;

    final sharpness =
        _sharpnessScore;

    final brightnessGood =
        brightness != null &&
            brightness >=
                _minimumBrightness &&
            brightness <=
                _maximumBrightness;

    final sharpnessGood =
        sharpness != null &&
            sharpness >=
                _minimumSharpness;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'OpenCV Image Quality',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            if (brightness != null)
              _qualityRow(
                label:
                    'Brightness',
                value:
                    brightness.toStringAsFixed(
                  1,
                ),
                passed:
                    brightnessGood,
              ),

            if (sharpness != null)
              _qualityRow(
                label:
                    'Sharpness',
                value:
                    sharpness.toStringAsFixed(
                  1,
                ),
                passed:
                    sharpnessGood,
              ),
          ],
        ),
      ),
    );
  }

  Widget _qualityRow({
    required String label,
    required String value,
    required bool passed,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons
                    .check_circle_rounded
                : Icons
                    .warning_rounded,
            color: passed
                ? AppColors.success
                : AppColors.warning,
            size: 20,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              label,
            ),
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUTTONS
  // ============================================================

  Widget _buildButtons() {
    if (_capturedImagePath ==
        null) {
      return SizedBox(
        width: double.infinity,
        child:
            FilledButton.icon(
          onPressed:
              (_capturing ||
                      _verifying ||
                      _initializingCamera)
                  ? null
                  : _captureFace,
          icon: _capturing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons
                      .camera_alt_rounded,
                ),
          label: Text(
            _capturing
                ? 'Checking Image...'
                : 'Capture Face',
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child:
              FilledButton.icon(
            onPressed:
                _verifying
                    ? null
                    : _verifyFace,
            icon: _verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .verified_user_rounded,
                  ),
            label: Text(
              _verifying
                  ? 'Verifying Face...'
                  : 'Verify Face',
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        SizedBox(
          width: double.infinity,
          child:
              OutlinedButton.icon(
            onPressed:
                _verifying
                    ? null
                    : _captureAgain,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'Capture Again',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.error.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              AppColors.error.withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons
                .error_outline_rounded,
            color: AppColors.error,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              _errorMessage ??
                  'Unable to verify face.',
              style:
                  const TextStyle(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULT
  // ============================================================

  Widget _buildResultCard() {
    final result =
        _result!;

    final verified =
        result['face_verified'] ==
            true;

    final similarity =
        _numberValue(
      result['face_similarity'],
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  verified
                      ? Icons
                          .check_circle_rounded
                      : Icons
                          .cancel_rounded,
                  color: verified
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  verified
                      ? 'Face Verified'
                      : 'Face Rejected',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),

            if (similarity !=
                null) ...[
              const SizedBox(
                height: 12,
              ),
              Text(
                'Similarity: '
                '${similarity.toStringAsFixed(4)}',
              ),
            ],

            const SizedBox(
              height: 6,
            ),

            Text(
              'Attendance: '
              '${result['attendance_status'] ?? '-'}',
            ),

            Text(
              'Next step: '
              '${result['next_verification_step'] ?? '-'}',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OPENCV QUALITY RESULT
// ============================================================

class _FaceImageQuality {
  const _FaceImageQuality({
    required this.accepted,
    required this.message,
    this.brightness,
    this.sharpness,
    this.width,
    this.height,
  });

  final bool accepted;
  final String message;

  final double? brightness;
  final double? sharpness;

  final int? width;
  final int? height;
}