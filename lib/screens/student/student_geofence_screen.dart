import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_theme.dart';

import '../../services/student_service.dart';
import 'student_face_screen.dart';

class StudentGeofenceScreen extends StatefulWidget {
  const StudentGeofenceScreen({
    super.key,
    required this.attendanceId,
    required this.attendanceData,
  });

  final int attendanceId;
  final Map<String, dynamic> attendanceData;

  @override
  State<StudentGeofenceScreen> createState() =>
      _StudentGeofenceScreenState();
}

class _StudentGeofenceScreenState
    extends State<StudentGeofenceScreen> {
  final StudentService _studentService =
      StudentService();

  bool _checkingLocation = false;
  String? _errorMessage;

  Position? _position;
  Map<String, dynamic>? _geofenceResult;

  @override
  void initState() {
    super.initState();
    _verifyCurrentLocation();
  }

  @override
  void dispose() {
    _studentService.dispose();
    super.dispose();
  }

  // ============================================================
  // VERIFY CURRENT LOCATION
  // ============================================================

  Future<void> _verifyCurrentLocation() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingLocation = true;
      _errorMessage = null;
    });

    try {
      final position =
          await _getCurrentPosition();

      if (!mounted) {
        return;
      }

      setState(() {
        _position = position;
      });

      final result =
          await _studentService.verifyGeofence(
        attendanceId:
            widget.attendanceId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _geofenceResult = result;
        _checkingLocation = false;
      });

      final verified =
          result['geofence_verified'] == true;

      final status =
          result['attendance_status']
              ?.toString()
              .toUpperCase();

      final nextStep =
          result['next_verification_step']
              ?.toString()
              .toUpperCase();

      if (verified &&
          status != 'REJECTED' &&
          nextStep == 'FACE') {
        _showSuccessAndContinue();
        return;
      }

      if (status == 'REJECTED') {
        _showRejectedDialog(result);
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _checkingLocation = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  // ============================================================
  // GET DEVICE LOCATION
  // ============================================================

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. '
        'Please enable GPS and try again.',
      );
    }

    var permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Enable location permission for Smart Attendance '
        'from your device settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccessAndContinue() {
    if (!mounted) {
      return;
    }

    final nextStep =
        _geofenceResult?[
          'next_verification_step'
        ]?.toString().toUpperCase();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppColors.success,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Location Verified',
                ),
              ),
            ],
          ),
          content: Text(
            nextStep == 'FACE'
                ? 'You are inside the classroom geofence. '
                  'Face verification is the next step.'
                : 'Your classroom location has been verified.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                Navigator.of(context)
                    .pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentFaceScreen(
                      attendanceId:
                          widget.attendanceId,
                      attendanceData:
                          widget.attendanceData,
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
  // REJECTED
  // ============================================================

  void _showRejectedDialog(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

    final distance =
        _numberValue(
      result[
        'distance_from_classroom_meters'
      ],
    );

    final radius =
        _numberValue(
      result[
        'geofence_radius_meters'
      ],
    );

    final reason =
        result['rejection_reason']
            ?.toString()
            .trim();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.location_off_rounded,
                color: AppColors.error,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Outside Geofence',
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
                    ? 'You are outside the allowed classroom area.'
                    : reason,
              ),

              const SizedBox(height: 14),

              if (distance != null)
                Text(
                  'Your distance: '
                  '${distance.toStringAsFixed(2)} m',
                ),

              if (radius != null)
                Text(
                  'Allowed radius: '
                  '${radius.toStringAsFixed(2)} m',
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                Navigator.of(
                  context,
                ).pop();
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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

    final currentPosition =
        _position;

    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Location Verification',
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
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
                  'Verify Your Location',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '$subject • Section $section',
                  style: TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                _buildStatusCard(
                  currentPosition,
                ),

                const SizedBox(height: 18),

                if (_errorMessage != null)
                  _buildErrorCard(),

                if (_geofenceResult != null)
                  _buildResultCard(),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _checkingLocation
                            ? null
                            : _verifyCurrentLocation,
                    icon: _checkingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.location_searching_rounded,
                          ),
                    label: Text(
                      _checkingLocation
                          ? 'Checking Location...'
                          : 'Check My Location',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    Position? position,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
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
              child: const Icon(
                Icons.location_on_rounded,
                color:
                    AppColors.primary,
                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _checkingLocation
                        ? 'Obtaining GPS location...'
                        : position == null
                            ? 'Location not available'
                            : 'GPS location obtained',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 5),

                  if (position != null)
                    Text(
                      'Latitude: '
                      '${position.latitude.toStringAsFixed(6)}\n'
                      'Longitude: '
                      '${position.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            AppColors.textSecondary,
                      ),
                    )
                  else
                    Text(
                      'Your device location is required '
                      'to verify classroom presence.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            AppColors.textSecondary,
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

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            AppColors.error.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(12),
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
            Icons.error_outline_rounded,
            color: AppColors.error,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _errorMessage ??
                  'Unable to verify location.',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result =
        _geofenceResult!;

    final verified =
        result['geofence_verified'] ==
            true;

    final distance =
        _numberValue(
      result[
        'distance_from_classroom_meters'
      ],
    );

    final radius =
        _numberValue(
      result[
        'geofence_radius_meters'
      ],
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
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

                const SizedBox(width: 10),

                Text(
                  verified
                      ? 'Geofence Verified'
                      : 'Geofence Rejected',
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (distance != null)
              Text(
                'Distance from classroom: '
                '${distance.toStringAsFixed(2)} meters',
              ),

            if (radius != null)
              Text(
                'Allowed radius: '
                '${radius.toStringAsFixed(2)} meters',
              ),

            const SizedBox(height: 8),

            Text(
              'Attendance status: '
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