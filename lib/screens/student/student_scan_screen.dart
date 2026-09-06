import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';

import '../../services/student_service.dart';
import 'student_face_screen.dart';
import 'student_geofence_screen.dart';
import 'student_liveness_screen.dart';

class StudentScanScreen extends StatefulWidget {
  const StudentScanScreen({
    super.key,
  });

  @override
  State<StudentScanScreen> createState() =>
      _StudentScanScreenState();
}

class _StudentScanScreenState
    extends State<StudentScanScreen> {
  final StudentService _studentService =
      StudentService();

  final MobileScannerController _scannerController =
      MobileScannerController();

  bool _processing = false;
  bool _flashEnabled = false;

  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _studentService.dispose();
    super.dispose();
  }

  // ============================================================
  // HANDLE QR DETECTION
  // ============================================================

  Future<void> _handleDetection(
    BarcodeCapture capture,
  ) async {
    if (_processing) {
      return;
    }

    String? qrData;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;

      if (rawValue != null &&
          rawValue.trim().isNotEmpty) {
        qrData = rawValue.trim();
        break;
      }
    }

    if (qrData == null) {
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    await _scannerController.stop();

    try {
      final attendance =
          await _studentService.markAttendance(
        qrData: qrData,
      );

      if (!mounted) {
        return;
      }

      final attendanceId =
          _toInt(attendance['attendance_id']);

      final nextStep =
          attendance['next_verification_step']
              ?.toString()
              .toUpperCase();

      final attendanceStatus =
          attendance['attendance_status']
              ?.toString()
              .toUpperCase();

      if (attendanceId <= 0) {
        throw Exception(
          'Invalid attendance record received from server.',
        );
      }

      if (attendanceStatus == 'REJECTED') {
        _showResultAndReturn(
          title: 'Attendance Rejected',
          message:
              attendance['rejection_reason']
                  ?.toString() ??
              'Attendance could not be marked.',
          success: false,
        );
        return;
      }

      if (nextStep == 'GEOFENCE') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                StudentGeofenceScreen(
              attendanceId: attendanceId,
              attendanceData: attendance,
            ),
          ),
        );

        return;
      }

      if (nextStep == 'FACE') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                StudentFaceScreen(
              attendanceId: attendanceId,
              attendanceData: attendance,
            ),
          ),
        );

        return;
      }

      if (nextStep == 'LIVENESS') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                StudentLivenessScreen(
              attendanceId: attendanceId,
            ),
          ),
        );

        return;
      }

      _showResultAndReturn(
        title: 'Attendance Updated',
        message:
            'Attendance status: '
            '${attendanceStatus ?? 'PENDING'}',
        success: attendanceStatus == 'PRESENT',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _scannerController.start();

      setState(() {
        _processing = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  // ============================================================
  // CAMERA TOGGLE
  // ============================================================

  Future<void> _toggleFlash() async {
    await _scannerController.toggleTorch();

    if (!mounted) {
      return;
    }

    setState(() {
      _flashEnabled = !_flashEnabled;
    });
  }

  Future<void> _switchCamera() async {
    await _scannerController.switchCamera();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  void _showResultAndReturn({
    required String title,
    required String message,
    required bool success,
  }) {
    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: success
                    ? AppColors.success
                    : AppColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop();

                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        title: const Text(
          'Scan Attendance QR',
        ),
        actions: [
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _processing
                ? null
                : _switchCamera,
            icon: const Icon(
              Icons.cameraswitch_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Flash',
            onPressed: _processing
                ? null
                : _toggleFlash,
            icon: Icon(
              _flashEnabled
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller:
                _scannerController,
            onDetect: _handleDetection,
          ),

          // ----------------------------------------------------
          // SCANNER FRAME
          // ----------------------------------------------------

          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent,
                  width: 3,
                ),
              ),
            ),
          ),

          // ----------------------------------------------------
          // TOP INSTRUCTION
          // ----------------------------------------------------

          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryDark
                    .withValues(
                  alpha: 0.78,
                ),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Text(
                'Point your camera at the attendance QR code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // ----------------------------------------------------
          // PROCESSING
          // ----------------------------------------------------

          if (_processing)
            Positioned.fill(
              child: Container(
                color: Colors.black
                    .withValues(
                  alpha: 0.65,
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Verifying attendance...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ----------------------------------------------------
          // ERROR
          // ----------------------------------------------------

          if (_errorMessage != null &&
              !_processing)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error
                      .withValues(
                    alpha: 0.92,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage =
                              null;
                        });
                      },
                      color: Colors.white,
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}