import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/attendance_session.dart';
import '../../services/faculty_service.dart';

class FacultyAttendanceScreen extends StatefulWidget {
  const FacultyAttendanceScreen({
    super.key,
  });

  @override
  State<FacultyAttendanceScreen> createState() =>
      _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState
    extends State<FacultyAttendanceScreen> {
  final FacultyService _facultyService = FacultyService();

  bool _loading = true;
  bool _startingSession = false;
  bool _completingSession = false;
  bool _cancellingSession = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _classrooms = [];

  int? _selectedSemesterId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  int? _selectedClassroomId;

  int _qrValidityMinutes = 5;
  double _geofenceRadiusMeters = 50.0;

  AttendanceSession? _session;
  AttendanceSessionQR? _qr;

  Timer? _countdownTimer;
  final ValueNotifier<Duration> _remainingNotifier =
      ValueNotifier<Duration>(Duration.zero);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _remainingNotifier.dispose();
    _facultyService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final semesters =
          await _facultyService.getSemesters();

      final classrooms =
          await _facultyService.getClassrooms();

      final activeSessionData =
          await _facultyService
              .getActiveAttendanceSession();

      AttendanceSession? activeSession;
      AttendanceSessionQR? activeQr;

      List<Map<String, dynamic>> sections = [];
      List<Map<String, dynamic>> subjects = [];

      int? semesterId;
      int? sectionId;
      int? subjectId;
      int? classroomId;

      int qrValidityMinutes =
          _qrValidityMinutes;

      double geofenceRadiusMeters =
          _geofenceRadiusMeters;

      if (activeSessionData != null) {
        activeSession =
            AttendanceSession.fromJson(
          activeSessionData,
        );

        semesterId =
            _toInt(
          activeSessionData['semester_id'],
        );

        sectionId =
            _toInt(
          activeSessionData['section_id'],
        );

        subjectId =
            _toInt(
          activeSessionData['subject_id'],
        );

        classroomId =
            _toInt(
          activeSessionData['classroom_id'],
        );

        geofenceRadiusMeters =
            _toDouble(
          activeSessionData[
              'geofence_radius_meters'],
          fallback: 50.0,
        );

        final startedAt =
            DateTime.tryParse(
          activeSessionData['started_at']
                  ?.toString() ??
              '',
        );

        final expiresAt =
            DateTime.tryParse(
          activeSessionData['qr_expires_at']
                  ?.toString() ??
              '',
        );

        if (startedAt != null &&
            expiresAt != null) {
          final calculatedMinutes =
              (expiresAt
                          .difference(startedAt)
                          .inSeconds /
                      60)
                  .round();

          if (calculatedMinutes < 1) {
            qrValidityMinutes = 1;
          } else if (calculatedMinutes > 15) {
            qrValidityMinutes = 15;
          } else {
            qrValidityMinutes =
                calculatedMinutes;
          }
        }

        if (semesterId > 0) {
          sections =
              await _facultyService
                  .getSectionsForSemester(
            semesterId,
          );
        }

        if (semesterId > 0 &&
            sectionId > 0) {
          subjects =
              await _facultyService
                  .getSubjectsForSection(
            semesterId: semesterId,
            sectionId: sectionId,
          );
        }

        activeQr =
            await _facultyService
                .generateAttendanceSessionQr(
          activeSession.sessionId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _semesters = semesters;
        _classrooms = classrooms;

        _sections = sections;
        _subjects = subjects;

        _selectedSemesterId =
            semesterId != null &&
                    semesterId > 0
                ? semesterId
                : null;

        _selectedSectionId =
            sectionId != null &&
                    sectionId > 0
                ? sectionId
                : null;

        _selectedSubjectId =
            subjectId != null &&
                    subjectId > 0
                ? subjectId
                : null;

        _selectedClassroomId =
            classroomId != null &&
                    classroomId > 0
                ? classroomId
                : _selectedClassroomId;

        _qrValidityMinutes =
            qrValidityMinutes;

        _geofenceRadiusMeters =
            geofenceRadiusMeters;

        _session = activeSession;
        _qr = activeQr;

        _loading = false;
      });

      if (activeQr != null) {
        _startCountdown(
          activeQr.qrExpiresAt,
        );
      } else {
        _countdownTimer?.cancel();
        _remainingNotifier.value =
            Duration.zero;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _onSemesterChanged(
    int? semesterId,
  ) async {
    if (semesterId == null) {
      return;
    }

    setState(() {
      _selectedSemesterId = semesterId;
      _selectedSectionId = null;
      _selectedSubjectId = null;

      _sections = [];
      _subjects = [];

      _errorMessage = null;
    });

    try {
      final sections =
          await _facultyService.getSectionsForSemester(
        semesterId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sections = sections;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _onSectionChanged(
    int? sectionId,
  ) async {
    if (sectionId == null ||
        _selectedSemesterId == null) {
      return;
    }

    setState(() {
      _selectedSectionId = sectionId;
      _selectedSubjectId = null;
      _subjects = [];
      _errorMessage = null;
    });

    try {
      final subjects =
          await _facultyService.getSubjectsForSection(
        semesterId: _selectedSemesterId!,
        sectionId: sectionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = subjects;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanErrorMessage(error);
      });
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  Future<void> _startSession() async {
    if (_selectedSemesterId == null) {
      _showMessage('Please select a semester.');
      return;
    }

    if (_selectedSectionId == null) {
      _showMessage('Please select a section.');
      return;
    }

    if (_selectedSubjectId == null) {
      _showMessage('Please select a subject.');
      return;
    }

    if (_selectedClassroomId == null) {
      _showMessage('Please select a classroom.');
      return;
    }

    setState(() {
      _startingSession = true;
      _errorMessage = null;
    });

    try {
      final session =
          await _facultyService.createAttendanceSession(
        semesterId: _selectedSemesterId!,
        subjectId: _selectedSubjectId!,
        sectionId: _selectedSectionId!,
        classroomId: _selectedClassroomId!,
        qrValidityMinutes: _qrValidityMinutes,
        geofenceRadiusMeters: _geofenceRadiusMeters,
      );

      final qr =
          await _facultyService.generateAttendanceSessionQr(
        session.sessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _qr = qr;
        _startingSession = false;
      });

      _startCountdown(qr.qrExpiresAt);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _startingSession = false;
        _errorMessage = _cleanErrorMessage(error);
      });
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();

    void updateCountdown() {
      final remaining =
          expiresAt.toLocal().difference(
        DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      if (remaining <= Duration.zero) {
        _countdownTimer?.cancel();
        _remainingNotifier.value =
            Duration.zero;

        if (!_completingSession &&
            !_cancellingSession &&
            _session != null) {
          unawaited(
            _completeSession(
              automatic: true,
            ),
          );
        }

        return;
      }

      _remainingNotifier.value =
          remaining;
    }

    updateCountdown();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateCountdown(),
    );
  }

  Future<void> _completeSession({
    bool automatic = false,
  }) async {
    final session = _session;

    if (session == null ||
        _completingSession ||
        _cancellingSession) {
      return;
    }

    if (!automatic) {
      final confirmed =
          await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Complete attendance session?',
            ),
            content: const Text(
              'This will end the active attendance session and '
              'immediately invalidate the QR code. '
              'The session will be saved as COMPLETED.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child: const Text(
                  'Keep Session Active',
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                icon: const Icon(
                  Icons.check_circle_rounded,
                ),
                label: const Text(
                  'Complete Session',
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _completingSession = true;
      _errorMessage = null;
    });

    try {
      await _facultyService
          .completeAttendanceSession(
        session.sessionId,
      );

      _countdownTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _qr = null;
        _remainingNotifier.value =
            Duration.zero;
        _completingSession = false;
      });

      _showMessage(
        automatic
            ? 'Attendance session completed automatically because the QR validity ended.'
            : 'Attendance session completed. QR is now invalid.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _completingSession = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _cancelSession() async {
    final session = _session;

    if (session == null ||
        _completingSession) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel attendance session?'),
          content: const Text(
            'The generated QR code will immediately become invalid. '
            'Students will no longer be able to use this session.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep Session'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Cancel Session'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _cancellingSession = true;
      _errorMessage = null;
    });

    try {
      await _facultyService.cancelAttendanceSession(
        session.sessionId,
      );

      _countdownTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _qr = null;
        _remainingNotifier.value = Duration.zero;
        _cancellingSession = false;
      });

      _showMessage(
        'Attendance session cancelled. QR is now invalid.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cancellingSession = false;
        _errorMessage = _cleanErrorMessage(error);
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(
    dynamic value, {
    required double fallback,
  }) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  String _subjectLabel(Map<String, dynamic> item) {
    final code = item['subject_code']?.toString().trim() ?? '';
    final name = item['subject_name']?.toString().trim() ?? '';

    if (code.isEmpty) {
      return name.isEmpty
          ? 'Subject ${item['subject_id']}'
          : name;
    }

    if (name.isEmpty) {
      return code;
    }

    return '$code - $name';
  }

  String _classroomLabel(Map<String, dynamic> item) {
    final building =
        item['building_name']?.toString().trim() ?? '';
    final room =
        item['room_number']?.toString().trim() ?? '';

    final classroomId = item['classroom_id'];

    if (building.isEmpty && room.isEmpty) {
      return 'Classroom $classroomId';
    }

    if (room.isEmpty) {
      return building;
    }

    if (building.isEmpty) {
      return 'Room $room';
    }

    return '$building - Room $room';
  }

  String _formatRemaining(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Attendance'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  if (_errorMessage != null)
                    const SizedBox(height: 16),
                  _buildSessionForm(),
                  const SizedBox(height: 20),
                  if (_session != null && _qr != null)
                    _buildActiveSession(),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Unable to load data.',
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

  Widget _buildSessionForm() {
    final hasActiveSession =
        _session != null && _qr != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start Attendance Session',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // SEMESTER
            // --------------------------------------------------

            DropdownButtonFormField<int>(
              initialValue: _selectedSemesterId,
              decoration: const InputDecoration(
                labelText: 'Semester',
                border: OutlineInputBorder(),
              ),
              items: _semesters
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: _toInt(item['semester_id']),
                      child: Text(
                        item['semester_name']?.toString() ??
                            'Semester ${item['semester_number'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: hasActiveSession
                  ? null
                  : _onSemesterChanged,
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // SECTION
            // --------------------------------------------------

            DropdownButtonFormField<int>(
              initialValue: _selectedSectionId,
              decoration: InputDecoration(
                labelText: 'Section',
                helperText: _selectedSemesterId == null
                    ? 'Select a semester first.'
                    : 'Only sections from the selected semester are shown.',
                border: const OutlineInputBorder(),
              ),
              items: _sections
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: _toInt(item['section_id']),
                      child: Text(
                        '${item['section_name'] ?? '-'} '
                        '(${item['student_count'] ?? 0} students)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged:
                  _selectedSemesterId == null || hasActiveSession
                      ? null
                      : _onSectionChanged,
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // SUBJECT
            // --------------------------------------------------

            DropdownButtonFormField<int>(
              initialValue: _selectedSubjectId,
              decoration: InputDecoration(
                labelText: 'Subject',
                helperText: _selectedSectionId == null
                    ? 'Select a section first.'
                    : 'Only your subjects for the selected semester and section are shown.',
                border: const OutlineInputBorder(),
              ),
              items: _subjects
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: _toInt(item['subject_id']),
                      child: Text(
                        _subjectLabel(item),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged:
                  _selectedSectionId == null || hasActiveSession
                      ? null
                      : (value) {
                          setState(() {
                            _selectedSubjectId = value;
                          });
                        },
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // CLASSROOM
            // --------------------------------------------------

            DropdownButtonFormField<int>(
              initialValue: _selectedClassroomId,
              decoration: const InputDecoration(
                labelText: 'Classroom',
                border: OutlineInputBorder(),
              ),
              items: _classrooms
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: _toInt(item['classroom_id']),
                      child: Text(
                        _classroomLabel(item),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: hasActiveSession
                  ? null
                  : (value) {
                      setState(() {
                        _selectedClassroomId = value;
                      });
                    },
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // QR VALIDITY
            // --------------------------------------------------

            DropdownButtonFormField<int>(
              initialValue: _qrValidityMinutes,
              decoration: const InputDecoration(
                labelText: 'QR validity',
                helperText:
                    'Faculty can choose from 1 to 15 minutes.',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                15,
                (index) {
                  final minutes = index + 1;

                  return DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(
                      '$minutes minute'
                      '${minutes == 1 ? '' : 's'}',
                    ),
                  );
                },
              ),
              onChanged: hasActiveSession
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _qrValidityMinutes = value;
                      });
                    },
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // GEOFENCE RANGE
            // --------------------------------------------------

            DropdownButtonFormField<double>(
              initialValue: _geofenceRadiusMeters,
              decoration: const InputDecoration(
                labelText: 'Geofence range',
                helperText:
                    'Students must be within this distance of the classroom.',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<double>(
                  value: 10.0,
                  child: Text('10 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 25.0,
                  child: Text('25 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 50.0,
                  child: Text('50 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 75.0,
                  child: Text('75 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 100.0,
                  child: Text('100 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 150.0,
                  child: Text('150 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 200.0,
                  child: Text('200 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 300.0,
                  child: Text('300 meters'),
                ),
                DropdownMenuItem<double>(
                  value: 500.0,
                  child: Text('500 meters'),
                ),
              ],
              onChanged: hasActiveSession
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _geofenceRadiusMeters = value;
                      });
                    },
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_startingSession || hasActiveSession)
                        ? null
                        : _startSession,
                icon: _startingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.play_arrow_rounded,
                      ),
                label: Text(
                  _startingSession
                      ? 'Starting...'
                      : 'Start Attendance',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSession() {
    final session = _session;
    final qr = _qr;

    if (session == null || qr == null) {
      return const SizedBox.shrink();
    }

    Widget qrWidget;

    try {
      qrWidget = Image.memory(
        base64Decode(qr.qrCodeBase64),
        width: 280,
        height: 280,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Text(
            'Unable to display QR image.',
          );
        },
      );
    } catch (_) {
      qrWidget = const Text(
        'Unable to display QR image.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Attendance Session Active',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                ValueListenableBuilder<Duration>(
                  valueListenable: _remainingNotifier,
                  builder: (context, remaining, child) {
                    final isQrValid = remaining > Duration.zero;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isQrValid
                            ? AppColors.success.withValues(alpha: 0.10)
                            : AppColors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isQrValid
                            ? _formatRemaining(remaining)
                            : 'COMPLETING',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isQrValid
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              '${qr.subjectName} • Section ${qr.sectionName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            qrWidget,

            const SizedBox(height: 18),

            ValueListenableBuilder<Duration>(
              valueListenable: _remainingNotifier,
              builder: (context, remaining, child) {
                final isQrValid = remaining > Duration.zero;

                return Text(
                  isQrValid
                      ? 'QR valid for ${_formatRemaining(remaining)}'
                      : 'Completing session...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isQrValid
                        ? AppColors.success
                        : AppColors.error,
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: 0.06,
                ),
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(
                    alpha: 0.16,
                  ),
                ),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This active QR is linked to your faculty account. '
                      'If you press Back, open Attendance again to restore '
                      'the same active session and QR until it completes.',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semester: '
                    '${_selectedSemesterId ?? '-'}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'QR validity: '
                    '$_qrValidityMinutes minute'
                    '${_qrValidityMinutes == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Geofence range: '
                    '${_geofenceRadiusMeters.toStringAsFixed(0)} meters',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Session ID: ${session.sessionId}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Classroom ID: ${session.classroomId}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status: ${session.sessionStatus}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_completingSession ||
                            _cancellingSession)
                        ? null
                        : _completeSession,
                icon: _completingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_rounded,
                      ),
                label: Text(
                  _completingSession
                      ? 'Completing...'
                      : 'Complete Session',
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    (_cancellingSession ||
                            _completingSession)
                        ? null
                        : _cancelSession,
                icon: _cancellingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.cancel_outlined,
                      ),
                label: Text(
                  _cancellingSession
                      ? 'Cancelling...'
                      : 'Cancel Session (Started by Mistake)',
                ),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
