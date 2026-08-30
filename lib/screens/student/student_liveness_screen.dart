import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../core/theme/app_theme.dart';

import '../../services/liveness_analysis_service.dart';
import '../../services/student_service.dart';
import '../../services/liveness_evidence.dart';

class StudentLivenessScreen extends StatefulWidget {
  const StudentLivenessScreen({
    super.key,
    required this.attendanceId,
  });

  final int attendanceId;

  @override
  State<StudentLivenessScreen> createState() =>
      _StudentLivenessScreenState();
}

class _StudentLivenessScreenState
    extends State<StudentLivenessScreen>
    with WidgetsBindingObserver {
  final StudentService _studentService =
      StudentService();

  final LivenessAnalysisService _livenessAnalysisService =
      LivenessAnalysisService();

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;

  bool _initializingCamera = true;
  bool _capturing = false;
  bool _verifying = false;

  int _step = 0;

  LivenessFrameEvidence? _neutralEvidence;
  LivenessFrameEvidence? _blinkEvidence;
  LivenessFrameEvidence? _turnEvidence;

  String? _errorMessage;

  double? _brightnessScore;
  double? _sharpnessScore;

  Map<String, dynamic>? _result;

  // ============================================================
  // OPENCV QUALITY SETTINGS
  // ============================================================

  static const double _minimumBrightness = 45.0;
  static const double _maximumBrightness = 225.0;

  static const double _minimumSharpness = 35.0;

  static const int _minimumImageWidth = 320;
  static const int _minimumImageHeight = 320;

  // These match the backend liveness checks that we will wire next.
  static const double _neutralEyeOpenThreshold = 0.55;
  static const double _blinkRatioThreshold = 0.75;
  static const double _headTurnYawThreshold = 12.0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Give the previous screen time to release the front camera
    // before this screen requests it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        await Future<void>.delayed(
          const Duration(
            milliseconds: 250,
          ),
        );

        if (!mounted) {
          return;
        }

        await _initializeCamera();
      },
    );
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
      return;
    }

    if (state == AppLifecycleState.resumed) {
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
      final cameras = await availableCameras();

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

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      try {
        await controller.setFlashMode(
          FlashMode.off,
        );
      } catch (_) {
        // Not supported by every front camera.
      }

      try {
        await controller.setFocusMode(
          FocusMode.auto,
        );
      } catch (_) {
        // Not supported by every device.
      }

      try {
        await controller.setExposureMode(
          ExposureMode.auto,
        );
      } catch (_) {
        // Not supported by every device.
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
              'Camera error: '
              '${error.description ?? error.code}';
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
  // STEP INFORMATION
  // ============================================================

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Neutral Face';

      case 1:
        return 'Blink Challenge';

      case 2:
        return 'Head Turn Challenge';

      default:
        return 'Liveness Verification';
    }
  }

  String get _stepInstruction {
    switch (_step) {
      case 0:
        return 'Look directly at the camera with your eyes open.';

      case 1:
        return 'Close your eyes naturally for the capture.';

      case 2:
        return 'Turn your head clearly to the left or right.';

      default:
        return '';
    }
  }

  IconData get _stepIcon {
    switch (_step) {
      case 0:
        return Icons.face_rounded;

      case 1:
        return Icons.visibility_off_rounded;

      case 2:
        return Icons.rotate_right_rounded;

      default:
        return Icons.face_retouching_natural_rounded;
    }
  }

  LivenessFrameEvidence? get _currentEvidence {
    switch (_step) {
      case 0:
        return _neutralEvidence;

      case 1:
        return _blinkEvidence;

      case 2:
        return _turnEvidence;

      default:
        return null;
    }
  }

  LivenessChallengeType get _currentChallenge {
    switch (_step) {
      case 0:
        return LivenessChallengeType.neutral;

      case 1:
        return LivenessChallengeType.blink;

      case 2:
        return LivenessChallengeType.turn;

      default:
        return LivenessChallengeType.neutral;
    }
  }

  // ============================================================
  // CAPTURE CURRENT CHALLENGE
  // ============================================================

  Future<void> _captureCurrentStep() async {
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

      _brightnessScore = null;
      _sharpnessScore = null;
    });

    String? temporaryImagePath;

    try {
      final image =
          await controller.takePicture();

      temporaryImagePath =
          image.path;

      final quality =
          await _checkImageQuality(
        image.path,
      );

      if (!mounted) {
        return;
      }

      if (!quality.accepted) {
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
      // ANALYZE THE CHALLENGE ENTIRELY ON THE DEVICE
      // --------------------------------------------------------

      final evidence =
          await _livenessAnalysisService.analyzeFrame(
        imagePath:
            image.path,

        challenge:
            _currentChallenge,
      );

      _validateCurrentChallenge(
        evidence,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _setCurrentEvidence(
          evidence,
        );

        _capturing = false;

        _brightnessScore =
            quality.brightness;

        _sharpnessScore =
            quality.sharpness;

        _errorMessage = null;
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
    } finally {
      // The liveness photograph is temporary. Once its numeric
      // evidence has been produced, it is deleted locally.
      if (temporaryImagePath != null) {
        await _deleteFileSafely(
          temporaryImagePath,
        );
      }
    }
  }

  // ============================================================
  // SAVE CURRENT STEP EVIDENCE
  // ============================================================

  void _setCurrentEvidence(
    LivenessFrameEvidence evidence,
  ) {
    switch (_step) {
      case 0:
        _neutralEvidence =
            evidence;
        break;

      case 1:
        _blinkEvidence =
            evidence;
        break;

      case 2:
        _turnEvidence =
            evidence;
        break;
    }
  }

  // ============================================================
  // LOCAL CHALLENGE VALIDATION
  // ============================================================

  void _validateCurrentChallenge(
    LivenessFrameEvidence evidence,
  ) {
    switch (evidence.challenge) {
      case LivenessChallengeType.neutral:
        final eyeOpen =
            evidence.averageEyeOpenProbability;

        if (eyeOpen == null ||
            eyeOpen <
                _neutralEyeOpenThreshold) {
          throw Exception(
            'Keep both eyes open and look directly at the camera.',
          );
        }

        break;

      case LivenessChallengeType.blink:
        final neutral =
            _neutralEvidence;

        final neutralEyeOpen =
            neutral?.averageEyeOpenProbability;

        final blinkEyeOpen =
            evidence.averageEyeOpenProbability;

        if (neutralEyeOpen == null ||
            neutralEyeOpen <= 0 ||
            blinkEyeOpen == null) {
          throw Exception(
            'Blink evidence could not be measured. '
            'Capture the neutral step again.',
          );
        }

        final blinkRatio =
            blinkEyeOpen /
                neutralEyeOpen;

        if (blinkRatio >
            _blinkRatioThreshold) {
          throw Exception(
            'Blink was not detected clearly. '
            'Close both eyes naturally and capture again.',
          );
        }

        break;

      case LivenessChallengeType.turn:
        final neutral =
            _neutralEvidence;

        if (neutral == null) {
          throw Exception(
            'Capture the neutral step first.',
          );
        }

        final yawChange =
            (evidence.headYaw -
                    neutral.headYaw)
                .abs();

        if (yawChange <
            _headTurnYawThreshold) {
          throw Exception(
            'Head turn was not large enough. '
            'Turn clearly left or right and capture again.',
          );
        }

        break;
    }
  }

  // ============================================================
  // OPENCV IMAGE QUALITY
  // ============================================================

  Future<_LivenessImageQuality>
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
        return const _LivenessImageQuality(
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
        return _LivenessImageQuality(
          accepted: false,
          width: source.width,
          height: source.height,
          message:
              'Image resolution is too low. '
              'Hold the phone steady and capture again.',
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
        return _LivenessImageQuality(
          accepted: false,
          brightness: brightness,
          width: source.width,
          height: source.height,
          message:
              'The image is too dark. '
              'Move to a brighter area.',
        );
      }

      if (brightness >
          _maximumBrightness) {
        return _LivenessImageQuality(
          accepted: false,
          brightness: brightness,
          width: source.width,
          height: source.height,
          message:
              'The image is too bright. '
              'Avoid strong light facing the camera.',
        );
      }

      // --------------------------------------------------------
      // SHARPNESS
      // --------------------------------------------------------

      laplacian = cv.laplacian(
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
        return _LivenessImageQuality(
          accepted: false,
          brightness: brightness,
          sharpness: sharpness,
          width: source.width,
          height: source.height,
          message:
              'The image appears blurry. '
              'Keep the phone and your face steady.',
        );
      }

      return _LivenessImageQuality(
        accepted: true,
        brightness: brightness,
        sharpness: sharpness,
        width: source.width,
        height: source.height,
        message:
            'Image quality is suitable.',
      );
    } catch (error) {
      return _LivenessImageQuality(
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
  // CONTINUE TO NEXT CHALLENGE
  // ============================================================

  void _continueToNextStep() {
    if (_currentEvidence == null) {
      _showMessage(
        'Capture this challenge first.',
      );

      return;
    }

    if (_step < 2) {
      setState(() {
        _step++;

        _brightnessScore = null;
        _sharpnessScore = null;

        _errorMessage = null;
      });

      return;
    }

    _verifyLiveness();
  }

  // ============================================================
  // PREVIOUS STEP
  // ============================================================

  void _previousStep() {
    if (_step <= 0 ||
        _verifying) {
      return;
    }

    setState(() {
      _step--;

      _brightnessScore = null;
      _sharpnessScore = null;

      _errorMessage = null;
    });
  }

  // ============================================================
  // VERIFY LIVENESS
  // ============================================================

  Future<void> _verifyLiveness() async {
    final neutral =
        _neutralEvidence;

    final blink =
        _blinkEvidence;

    final turn =
        _turnEvidence;

    if (neutral == null ||
        blink == null ||
        turn == null) {
      _showMessage(
        'Complete all three liveness challenges first.',
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
      // No photograph is sent here. StudentService serializes
      // only embeddings, eye probabilities, and head-pose values.
      final result =
          await _studentService.verifyLiveness(
        attendanceId:
            widget.attendanceId,

        neutralEvidence:
            neutral,

        blinkEvidence:
            blink,

        turnEvidence:
            turn,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verifying = false;
        _result = result;
      });

      final verified =
          result['liveness_verified'] ==
              true;

      final status =
          result['attendance_status']
              ?.toString()
              .toUpperCase();

      if (verified &&
          status == 'PRESENT') {
        _showSuccessDialog(
          result,
        );

        return;
      }

      _showFailureDialog(
        result,
      );
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
  // SUCCESS DIALOG
  // ============================================================

  void _showSuccessDialog(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

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
                  'Attendance Marked',
                ),
              ),
            ],
          ),
          content: const Text(
            'QR, location, face, and liveness '
            'verification were completed successfully.\n\n'
            'Your attendance status is PRESENT.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                Navigator.of(context)
                    .popUntil(
                  (route) =>
                      route.isFirst,
                );
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
  // FAILURE DIALOG
  // ============================================================

  void _showFailureDialog(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

    final reason =
        result['rejection_reason']
            ?.toString()
            .trim();

    final blinkDetected =
        result['blink_detected'] ==
            true;

    final headTurnDetected =
        result['head_turn_detected'] ==
            true;

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
                  'Liveness Failed',
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
                    ? 'Liveness verification failed.'
                    : reason,
              ),

              const SizedBox(
                height: 16,
              ),

              _dialogCheckRow(
                'Blink detected',
                blinkDetected,
              ),

              _dialogCheckRow(
                'Head turn detected',
                headTurnDetected,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                Navigator.of(context)
                    .popUntil(
                  (route) =>
                      route.isFirst,
                );
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

  Widget _dialogCheckRow(
    String label,
    bool passed,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons
                    .check_circle_rounded
                : Icons
                    .cancel_rounded,
            color: passed
                ? AppColors.success
                : AppColors.error,
            size: 20,
          ),

          const SizedBox(
            width: 9,
          ),

          Text(label),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

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
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary capture cleanup is non-critical.
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

    unawaited(
      _livenessAnalysisService.close(),
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
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Liveness Verification',
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
                    'Liveness Check',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'Complete all three challenges. Face images are processed locally.',
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildProgress(),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildChallengeHeader(),

                  const SizedBox(
                    height: 14,
                  ),

                  _buildCameraCard(),

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
  // PROGRESS
  // ============================================================

  Widget _buildProgress() {
    return Row(
      children: [
        _stepIndicator(
          number: 1,
          label: 'Neutral',
          selected:
              _step == 0,
          completed:
              _neutralEvidence !=
                  null,
        ),

        _progressConnector(),

        _stepIndicator(
          number: 2,
          label: 'Blink',
          selected:
              _step == 1,
          completed:
              _blinkEvidence != null,
        ),

        _progressConnector(),

        _stepIndicator(
          number: 3,
          label: 'Turn',
          selected:
              _step == 2,
          completed:
              _turnEvidence != null,
        ),
      ],
    );
  }

  Widget _stepIndicator({
    required int number,
    required String label,
    required bool selected,
    required bool completed,
  }) {
    final active =
        selected || completed;

    final color = active
        ? AppColors.primary
        : AppColors.textSecondary;

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                color.withValues(
              alpha: 0.12,
            ),
            child: completed
                ? Icon(
                    Icons.check_rounded,
                    color: color,
                  )
                : Text(
                    '$number',
                    style: TextStyle(
                      color: color,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressConnector() {
    return Container(
      width: 28,
      height: 2,
      margin:
          const EdgeInsets.only(
        bottom: 22,
      ),
      color: AppColors.border,
    );
  }

  // ============================================================
  // CHALLENGE HEADER
  // ============================================================

  Widget _buildChallengeHeader() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.surfaceSoft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                _stepIcon,
                color:
                    AppColors.primary,
                size: 28,
              ),
            ),

            const SizedBox(
              width: 15,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _stepTitle,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    _stepInstruction,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors
                          .grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Widget _buildCameraCard() {
    final currentEvidence =
        _currentEvidence;

    if (_initializingCamera) {
      return const Card(
        child: SizedBox(
          height: 420,
          child: Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (currentEvidence != null) {
      return Card(
        child: SizedBox(
          width: double.infinity,
          height: 420,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                24,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons
                        .verified_user_rounded,
                    size: 72,
                    color:
                        AppColors.success,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    '$_stepTitle captured',
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'The image was analyzed locally and deleted. '
                    'Only numeric liveness evidence is kept in memory.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
          height: 420,
          child: Center(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .no_photography_rounded,
                  size: 58,
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
      );
    }

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: 420,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(
              controller,
            ),

            Container(
              decoration:
                  BoxDecoration(
                border: Border.all(
                  width: 16,
                  color: Colors.black
                      .withValues(
                    alpha: 0.12,
                  ),
                ),
              ),
            ),

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

            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.black
                      .withValues(
                    alpha: 0.52,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child: Text(
                  _stepInstruction,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 15,
              left: 15,
              right: 15,
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
                      ? 'Front camera • Keep only your face visible'
                      : 'Keep only your face visible',
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
  // BUTTONS
  // ============================================================

  Widget _buildButtons() {
    final captured =
        _currentEvidence != null;

    return Column(
      children: [
        if (!captured)
          SizedBox(
            width: double.infinity,
            child:
                FilledButton.icon(
              onPressed:
                  (_capturing ||
                          _verifying ||
                          _initializingCamera)
                      ? null
                      : _captureCurrentStep,
              icon: _capturing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .camera_alt_rounded,
                    ),
              label: Text(
                _capturing
                    ? 'Checking Capture...'
                    : 'Capture $_stepTitle',
              ),
            ),
          ),

        if (captured) ...[
          SizedBox(
            width: double.infinity,
            child:
                FilledButton.icon(
              onPressed:
                  _verifying
                      ? null
                      : _continueToNextStep,
              icon: _verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                      ),
                    )
                  : Icon(
                      _step < 2
                          ? Icons
                              .arrow_forward_rounded
                          : Icons
                              .verified_user_rounded,
                    ),
              label: Text(
                _verifying
                    ? 'Verifying Liveness...'
                    : _step < 2
                        ? 'Continue'
                        : 'Verify Liveness',
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
                      : _captureAgainCurrentStep,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Capture Again',
              ),
            ),
          ),
        ],

        if (_step > 0 &&
            !_verifying) ...[
          const SizedBox(
            height: 10,
          ),

          SizedBox(
            width: double.infinity,
            child:
                TextButton.icon(
              onPressed:
                  _previousStep,
              icon: const Icon(
                Icons
                    .arrow_back_rounded,
              ),
              label: const Text(
                'Previous Challenge',
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // CAPTURE CURRENT AGAIN
  // ============================================================

  Future<void>
      _captureAgainCurrentStep() async {
    if (!mounted) {
      return;
    }

    setState(() {
      switch (_step) {
        case 0:
          _neutralEvidence = null;
          break;

        case 1:
          _blinkEvidence = null;
          break;

        case 2:
          _turnEvidence = null;
          break;
      }

      _brightnessScore = null;
      _sharpnessScore = null;

      _errorMessage = null;
    });
  }

  // ============================================================
  // QUALITY CARD
  // ============================================================

  Widget _buildQualityCard() {
    final brightness =
        _brightnessScore;

    final sharpness =
        _sharpnessScore;

    final brightnessPassed =
        brightness != null &&
            brightness >=
                _minimumBrightness &&
            brightness <=
                _maximumBrightness;

    final sharpnessPassed =
        sharpness != null &&
            sharpness >=
                _minimumSharpness;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'OpenCV Quality Check',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            if (brightness != null)
              _qualityRow(
                label:
                    'Brightness',
                value:
                    brightness
                        .toStringAsFixed(
                  1,
                ),
                passed:
                    brightnessPassed,
              ),

            if (sharpness != null)
              _qualityRow(
                label:
                    'Sharpness',
                value:
                    sharpness
                        .toStringAsFixed(
                  1,
                ),
                passed:
                    sharpnessPassed,
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
        bottom: 7,
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
            width: 9,
          ),

          Expanded(
            child: Text(label),
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
  // ERROR CARD
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
                  'Unable to complete liveness verification.',
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
        result['liveness_verified'] ==
            true;

    final blink =
        result['blink_detected'] ==
            true;

    final turn =
        result[
          'head_turn_detected'
        ] ==
            true;

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
                      ? 'Liveness Verified'
                      : 'Liveness Rejected',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 13,
            ),

            _resultRow(
              'Neutral face',
              result[
                    'neutral_face_detected'
                  ] ==
                  true,
            ),

            _resultRow(
              'Blink',
              blink,
            ),

            _resultRow(
              'Head turn',
              turn,
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Attendance status: '
              '${result['attendance_status'] ?? '-'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(
    String label,
    bool passed,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons
                    .check_circle_outline_rounded
                : Icons
                    .cancel_outlined,
            size: 19,
            color: passed
                ? AppColors.success
                : AppColors.error,
          ),

          const SizedBox(
            width: 9,
          ),

          Text(label),
        ],
      ),
    );
  }
}

// ============================================================
// OPENCV IMAGE QUALITY RESULT
// ============================================================

class _LivenessImageQuality {
  const _LivenessImageQuality({
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