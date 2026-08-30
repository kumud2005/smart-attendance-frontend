import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../core/theme/app_theme.dart';

import '../../services/face_embedding_service.dart';
import '../../services/student_service.dart';

class StudentFaceProfileScreen extends StatefulWidget {
  const StudentFaceProfileScreen({
    super.key,
  });

  @override
  State<StudentFaceProfileScreen> createState() =>
      _StudentFaceProfileScreenState();
}

class _StudentFaceProfileScreenState
    extends State<StudentFaceProfileScreen>
    with WidgetsBindingObserver {
  final StudentService _studentService =
      StudentService();

  final FaceEmbeddingService _faceEmbeddingService =
      FaceEmbeddingService();

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;

  bool _initializingCamera = true;
  bool _loadingStatus = true;
  bool _capturing = false;
  bool _registering = false;

  String? _capturedImagePath;
  String? _errorMessage;

  Map<String, dynamic>? _faceStatus;
  Map<String, dynamic>? _registrationResult;

  double? _brightnessScore;
  double? _sharpnessScore;

  // ============================================================
  // IMAGE QUALITY SETTINGS
  // ============================================================

  static const double _minimumBrightness = 55.0;
  static const double _maximumBrightness = 215.0;

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

    _loadFaceStatus();
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
  // LOAD FACE STATUS
  // ============================================================

  Future<void> _loadFaceStatus() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingStatus = true;
    });

    try {
      final result =
          await _studentService.getFaceStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _faceStatus = result;
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingStatus = false;
      });

      // A missing face profile may be a normal state for
      // a student who has not registered yet.
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

      final previousController =
          _cameraController;

      if (previousController != null) {
        await previousController.dispose();
      }

      final controller =
          CameraController(
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
        // Front cameras may not support flash configuration.
      }

      try {
        await controller.setFocusMode(
          FocusMode.auto,
        );
      } catch (_) {
        // Not supported on every device.
      }

      try {
        await controller.setExposureMode(
          ExposureMode.auto,
        );
      } catch (_) {
        // Not supported on every device.
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
  // CAPTURE FACE
  // ============================================================

  Future<void> _captureFace() async {
    if (_capturing ||
        _registering) {
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

      _registrationResult = null;
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

      final previousPath =
          _capturedImagePath;

      if (previousPath != null &&
          previousPath != image.path) {
        await _deleteFileSafely(
          previousPath,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedImagePath =
            image.path;

        _brightnessScore =
            quality.brightness;

        _sharpnessScore =
            quality.sharpness;

        _capturing = false;
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
  // OPENCV QUALITY CHECK
  // ============================================================

  Future<_FaceRegistrationImageQuality>
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
        return const _FaceRegistrationImageQuality(
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
        return _FaceRegistrationImageQuality(
          accepted: false,
          width: source.width,
          height: source.height,
          message:
              'Image resolution is too low. '
              'Capture your face again.',
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
        return _FaceRegistrationImageQuality(
          accepted: false,
          brightness: brightness,
          width: source.width,
          height: source.height,
          message:
              'The image is too dark. '
              'Move to a brighter location.',
        );
      }

      if (brightness >
          _maximumBrightness) {
        return _FaceRegistrationImageQuality(
          accepted: false,
          brightness: brightness,
          width: source.width,
          height: source.height,
          message:
              'The image is too bright. '
              'Avoid strong light directly on your face.',
        );
      }

      // --------------------------------------------------------
      // SHARPNESS
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
        return _FaceRegistrationImageQuality(
          accepted: false,
          brightness: brightness,
          sharpness: sharpness,
          width: source.width,
          height: source.height,
          message:
              'The image appears blurry. '
              'Hold the phone steady and capture again.',
        );
      }

      return _FaceRegistrationImageQuality(
        accepted: true,
        brightness: brightness,
        sharpness: sharpness,
        width: source.width,
        height: source.height,
        message:
            'Image quality is suitable for registration.',
      );
    } catch (error) {
      return _FaceRegistrationImageQuality(
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
  // REGISTER FACE
  // ============================================================

  Future<void> _registerFace() async {
    final imagePath =
        _capturedImagePath;

    if (imagePath == null) {
      _showMessage(
        'Capture your face first.',
      );

      return;
    }

    if (_registering) {
      return;
    }

    setState(() {
      _registering = true;
      _errorMessage = null;
      _registrationResult = null;
    });

    try {
      // --------------------------------------------------------
      // GENERATE THE FACE EMBEDDING LOCALLY
      // --------------------------------------------------------

      final embeddingResult =
          await _faceEmbeddingService.generateEmbedding(
        imagePath: imagePath,
      );

      // --------------------------------------------------------
      // SEND ONLY THE 512D EMBEDDING TO FASTAPI
      // --------------------------------------------------------

      final result =
          await _studentService.registerFace(
        faceEmbedding:
            embeddingResult.embedding,
      );

      if (!mounted) {
        return;
      }

      // The captured image never leaves the device.
      // Delete the temporary camera file after registration.
      await _deleteFileSafely(
        imagePath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedImagePath = null;
        _registering = false;
        _registrationResult = result;
      });

      await _loadFaceStatus();

      if (!mounted) {
        return;
      }

      _showRegistrationSuccess(
        result,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _registering = false;
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

      _errorMessage = null;
      _registrationResult = null;
    });
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  void _showRegistrationSuccess(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

    final verified =
        result['is_verified'] == true;

    final dimensions =
        result['embedding_dimensions']
            ?.toString();

    final message =
        result['message']
            ?.toString()
            .trim();

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
                  'Face Registered',
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
                message == null ||
                        message.isEmpty
                    ? 'Your face profile was registered successfully.'
                    : message,
              ),

              const SizedBox(
                height: 14,
              ),

              _dialogInformationRow(
                'Verified',
                verified
                    ? 'Yes'
                    : 'No',
              ),

              if (dimensions != null)
                _dialogInformationRow(
                  'Embedding dimensions',
                  dimensions,
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
                    .pop(true);
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

  Widget _dialogInformationRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(value),
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
      final file =
          File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary image cleanup failure is not critical.
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
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Face Profile',
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
                    'Register Your Face',
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
                    'Your face is processed locally. Only a numeric '
                    'embedding is sent for registration.',
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildFaceStatusCard(),

                  const SizedBox(
                    height: 16,
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

                  if (_registrationResult !=
                      null) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    _buildRegistrationResultCard(),
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
  // FACE STATUS
  // ============================================================

  Widget _buildFaceStatusCard() {
    if (_loadingStatus) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(
            18,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Checking face profile...',
              ),
            ],
          ),
        ),
      );
    }

    final status =
        _faceStatus;

    final registered =
        status?['is_registered'] ==
                true ||
            status?['registered'] ==
                true ||
            status?['face_profile_id'] !=
                null;

    final verified =
        status?['is_verified'] ==
            true;

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
                color: registered
                    ? AppColors.success
                        .withValues(
                        alpha: 0.10,
                      )
                    : AppColors.surfaceSoft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                registered
                    ? Icons
                        .verified_user_rounded
                    : Icons.face_rounded,
                color: registered
                    ? AppColors.success
                    : AppColors.primary,
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
                    registered
                        ? 'Face Profile Registered'
                        : 'Face Profile Not Registered',
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    registered
                        ? verified
                            ? 'Your registered face is verified and active.'
                            : 'A face profile exists but is not verified.'
                        : 'Capture a clear face to create your profile.',
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

    final capturedPath =
        _capturedImagePath;

    if (capturedPath != null) {
      return Card(
        clipBehavior:
            Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          height: 430,
          child: Image.file(
            File(capturedPath),
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
      );
    }

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: 430,
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
                  width: 18,
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
                  'Center your face inside the guide',
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
                      : 'Camera ready',
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
              'Registration guidelines',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _instruction(
              Icons.face_rounded,
              'Look directly at the camera.',
            ),

            _instruction(
              Icons.light_mode_rounded,
              'Use clear and even lighting.',
            ),

            _instruction(
              Icons.center_focus_strong_rounded,
              'Keep your entire face inside the guide.',
            ),

            _instruction(
              Icons.pan_tool_alt_rounded,
              'Hold the device steady.',
            ),

            _instruction(
              Icons.group_off_rounded,
              'Only one face should be visible.',
            ),

            _instruction(
              Icons.visibility_rounded,
              'Keep your eyes open during registration.',
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
                      _registering ||
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
                _registering
                    ? null
                    : _registerFace,
            icon: _registering
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
                        .person_add_alt_1_rounded,
                  ),
            label: Text(
              _registering
                  ? 'Registering Face...'
                  : 'Register Face',
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
                _registering
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
                  'Unable to register face.',
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
  // REGISTRATION RESULT
  // ============================================================

  Widget _buildRegistrationResultCard() {
    final result =
        _registrationResult!;

    final verified =
        result['is_verified'] ==
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
                          .info_rounded,
                  color: verified
                      ? AppColors.success
                      : AppColors.warning,
                ),

                const SizedBox(
                  width: 10,
                ),

                const Text(
                  'Registration Result',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              'Verified: '
              '${verified ? 'Yes' : 'No'}',
            ),

            if (result[
                    'embedding_dimensions'] !=
                null)
              Text(
                'Embedding dimensions: '
                '${result['embedding_dimensions']}',
              ),

            if (result['message'] !=
                null) ...[
              const SizedBox(
                height: 8,
              ),

              Text(
                result['message']
                    .toString(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OPENCV QUALITY RESULT
// ============================================================

class _FaceRegistrationImageQuality {
  const _FaceRegistrationImageQuality({
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