import 'package:flutter/material.dart';
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_theme.dart';

import '../../services/faculty_service.dart';

class FacultyReportsScreen extends StatefulWidget {
  const FacultyReportsScreen({
    super.key,
  });

  @override
  State<FacultyReportsScreen> createState() =>
      _FacultyReportsScreenState();
}

class _FacultyReportsScreenState
    extends State<FacultyReportsScreen> {
  final FacultyService _facultyService =
      FacultyService();

  final PublicFileSaver _fileSaver =
      PublicFileSaver();

  bool _isLoading = true;
  bool _isLoadingSections = false;
  bool _isLoadingSubjects = false;
  bool _isDownloadingExcel = false;
  bool _isDownloadingPdf = false;

  String? _errorMessage;

  Map<String, dynamic>? _report;

  List<Map<String, dynamic>> _semesters =
      const [];
  List<Map<String, dynamic>> _sections =
      const [];
  List<Map<String, dynamic>> _subjects =
      const [];

  int? _selectedSemesterId;
  int? _selectedSectionId;
  int? _selectedSubjectId;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _facultyService.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final semesters =
          await _facultyService.getSemesters();

      final report =
          await _facultyService.getAttendanceReport();

      if (!mounted) {
        return;
      }

      setState(() {
        _semesters = semesters;
        _report = report;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _loadReport() async {
    if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      _showMessage(
        'Date From cannot be later than Date To.',
        isError: true,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report =
          await _facultyService.getAttendanceReport(
        semesterId: _selectedSemesterId,
        sectionId: _selectedSectionId,
        subjectId: _selectedSubjectId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _report = report;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _onSemesterChanged(
    int? semesterId,
  ) async {
    setState(() {
      _selectedSemesterId = semesterId;
      _selectedSectionId = null;
      _selectedSubjectId = null;
      _sections = const [];
      _subjects = const [];
    });

    if (semesterId == null) {
      return;
    }

    setState(() {
      _isLoadingSections = true;
    });

    try {
      final sections =
          await _facultyService
              .getSectionsForSemester(
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

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSections = false;
        });
      }
    }
  }

  Future<void> _onSectionChanged(
    int? sectionId,
  ) async {
    setState(() {
      _selectedSectionId = sectionId;
      _selectedSubjectId = null;
      _subjects = const [];
    });

    final semesterId =
        _selectedSemesterId;

    if (semesterId == null ||
        sectionId == null) {
      return;
    }

    setState(() {
      _isLoadingSubjects = true;
    });

    try {
      final subjects =
          await _facultyService
              .getSubjectsForSection(
        semesterId: semesterId,
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

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSubjects = false;
        });
      }
    }
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedSemesterId = null;
      _selectedSectionId = null;
      _selectedSubjectId = null;
      _dateFrom = null;
      _dateTo = null;
      _sections = const [];
      _subjects = const [];
    });

    await _loadReport();
  }

  Future<void> _pickDateFrom() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateFrom = picked;
    });
  }

  Future<void> _pickDateTo() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateTo = picked;
    });
  }

  Future<void> _downloadExcel() async {
    if (_isDownloadingExcel) {
      return;
    }

    if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      _showMessage(
        'Date From cannot be later than Date To.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isDownloadingExcel = true;
    });

    try {
      final bytes =
          await _facultyService
              .downloadAttendanceReportExcel(
        semesterId: _selectedSemesterId,
        sectionId: _selectedSectionId,
        subjectId: _selectedSubjectId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      final result =
          await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: _exportFileName('xlsx'),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) {
        return;
      }

      if (result == null ||
          !result.isSuccess) {
        throw Exception(
          'The Excel report could not be saved.',
        );
      }

      _showMessage(
        'Excel report saved successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingExcel = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloadingPdf) {
      return;
    }

    if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      _showMessage(
        'Date From cannot be later than Date To.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isDownloadingPdf = true;
    });

    try {
      final bytes =
          await _facultyService
              .downloadAttendanceReportPdf(
        semesterId: _selectedSemesterId,
        sectionId: _selectedSectionId,
        subjectId: _selectedSubjectId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      final result =
          await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: _exportFileName('pdf'),
        mimeType: 'application/pdf',
      );

      if (!mounted) {
        return;
      }

      if (result == null ||
          !result.isSuccess) {
        throw Exception(
          'The PDF report could not be saved.',
        );
      }

      _showMessage(
        'PDF report saved successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  String _exportFileName(String extension) {
    final now = DateTime.now();

    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    return 'faculty_attendance_report_$stamp.$extension';
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(
        'Exception: '.length,
      );
    }

    return text;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.error : null,
      ),
    );
  }

  Map<String, dynamic> _map(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  String _resultExplanation(
    Map<String, dynamic> row,
  ) {
    final attendanceStatus =
        _text(
      row['attendance_status'],
    ).toUpperCase();

    final qrStatus =
        _text(
      row['qr_status'] ??
          row['session_status'],
    ).toUpperCase();

    final rejectionReason =
        _text(
      row['rejection_reason'],
    );

    if (qrStatus == 'CANCELLED') {
      return 'QR/session was cancelled by faculty. '
          'This row is audit-only and does not reduce attendance.';
    }

    if (attendanceStatus == 'PRESENT') {
      return 'QR, geofence, face and liveness checks passed.';
    }

    if (attendanceStatus == 'REJECTED') {
      if (rejectionReason != '-') {
        return rejectionReason;
      }

      if (!_bool(row['qr_verified'])) {
        return 'Rejected: QR verification failed.';
      }
      if (!_bool(row['geofence_verified'])) {
        return 'Rejected: geofence verification failed.';
      }
      if (!_bool(row['face_verified'])) {
        return 'Rejected: face verification failed.';
      }
      if (!_bool(row['liveness_verified'])) {
        return 'Rejected: liveness verification failed.';
      }

      return 'Attendance attempt was rejected.';
    }

    if (attendanceStatus == 'PENDING') {
      if (!_bool(row['qr_verified'])) {
        return 'Pending at QR verification.';
      }
      if (!_bool(row['geofence_verified'])) {
        return 'QR passed; geofence verification pending.';
      }
      if (!_bool(row['face_verified'])) {
        return 'QR and geofence passed; face verification pending.';
      }
      if (!_bool(row['liveness_verified'])) {
        return 'QR, geofence and face passed; liveness pending.';
      }

      return 'Verification is still in progress.';
    }

    if (attendanceStatus == 'NOT_MARKED') {
      if (qrStatus == 'COMPLETED') {
        return 'QR/session completed before attendance was marked.';
      }

      if (qrStatus == 'ACTIVE') {
        return 'QR/session is active; attendance is not marked yet.';
      }

      return 'No successful attendance attempt was recorded.';
    }

    return 'Attendance result recorded by the system.';
  }

  String _text(
    dynamic value, {
    String fallback = '-',
  }) {
    if (value == null) {
      return fallback;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  int _int(dynamic value) {
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

  double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  bool _bool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value?.toString().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  String _percentage(dynamic value) {
    return '${_double(value).toStringAsFixed(2)}%';
  }

  String _formatDateValue(
    dynamic value,
  ) {
    final text = _text(
      value,
      fallback: '',
    );

    if (text.isEmpty) {
      return '-';
    }

    final parsed =
        DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    return '${parsed.day.toString().padLeft(2, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.year}';
  }

  String _formatDateTimeValue(
    dynamic value,
  ) {
    final text = _text(
      value,
      fallback: '',
    );

    if (text.isEmpty) {
      return '-';
    }

    final parsed =
        DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    return '${parsed.day.toString().padLeft(2, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.year} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _selectedDateText(
    DateTime? value,
  ) {
    if (value == null) {
      return 'All dates';
    }

    return '${value.day.toString().padLeft(2, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final report = _report ?? {};
    final faculty =
        _map(report['faculty']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        surfaceTintColor: AppColors.primary,
        title: const Text(
          'Attendance Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed:
                _isLoading ? null : _loadReport,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1500,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildHeader(faculty),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    _buildErrorBanner(),
                  if (_errorMessage != null)
                    const SizedBox(height: 16),
                  if (_isLoading)
                    _buildLoadingState()
                  else
                    _buildReportContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    Map<String, dynamic> faculty,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor:
                    Color(0xFFE8EAF8),
                child: Icon(
                  Icons.assessment_rounded,
                  color: Color(0xFF4658B7),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Faculty Attendance Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
          _headerValue(
            'Faculty',
            _text(faculty['full_name']),
          ),
          _headerValue(
            'Employee ID',
            _text(faculty['employee_id']),
          ),
          _headerValue(
            'Department',
            _text(faculty['department']),
          ),
        ],
      ),
    );
  }

  Widget _headerValue(
    String label,
    String value,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Filters',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child:
                    DropdownButtonFormField<int?>(
                  initialValue: _selectedSemesterId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Semester',
                    border:
                        OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'All Semesters',
                      ),
                    ),
                    ..._semesters.map(
                      (semester) =>
                          DropdownMenuItem<int?>(
                        value: _int(
                          semester[
                              'semester_id'],
                        ),
                        child: Text(
                          _semesterLabel(
                            semester,
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged:
                      _isLoadingSections
                          ? null
                          : _onSemesterChanged,
                ),
              ),
              SizedBox(
                width: 220,
                child:
                    DropdownButtonFormField<int?>(
                  initialValue: _selectedSectionId,
                  isExpanded: true,
                  decoration:
                      InputDecoration(
                    labelText:
                        _isLoadingSections
                            ? 'Loading sections...'
                            : 'Section',
                    border:
                        const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'All Sections',
                      ),
                    ),
                    ..._sections.map(
                      (section) =>
                          DropdownMenuItem<int?>(
                        value: _int(
                          section['section_id'],
                        ),
                        child: Text(
                          _text(
                            section[
                                'section_name'],
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged:
                      _selectedSemesterId == null ||
                              _isLoadingSections
                          ? null
                          : _onSectionChanged,
                ),
              ),
              SizedBox(
                width: 260,
                child:
                    DropdownButtonFormField<int?>(
                  initialValue: _selectedSubjectId,
                  isExpanded: true,
                  decoration:
                      InputDecoration(
                    labelText:
                        _isLoadingSubjects
                            ? 'Loading subjects...'
                            : 'Subject',
                    border:
                        const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'All Subjects',
                      ),
                    ),
                    ..._subjects.map(
                      (subject) =>
                          DropdownMenuItem<int?>(
                        value: _int(
                          subject['subject_id'],
                        ),
                        child: Text(
                          '${_text(subject['subject_code'])} - '
                          '${_text(subject['subject_name'])}',
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged:
                      _selectedSectionId == null ||
                              _isLoadingSubjects
                          ? null
                          : (value) {
                              setState(() {
                                _selectedSubjectId =
                                    value;
                              });
                            },
                ),
              ),
              _dateFilterButton(
                label: 'Date From',
                value:
                    _selectedDateText(_dateFrom),
                onTap: _pickDateFrom,
                onClear: _dateFrom == null
                    ? null
                    : () {
                        setState(() {
                          _dateFrom = null;
                        });
                      },
              ),
              _dateFilterButton(
                label: 'Date To',
                value:
                    _selectedDateText(_dateTo),
                onTap: _pickDateTo,
                onClear: _dateTo == null
                    ? null
                    : () {
                        setState(() {
                          _dateTo = null;
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed:
                    _isLoading ? null : _loadReport,
                icon: const Icon(
                  Icons.filter_alt_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Apply Filters',
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _isLoading ? null : _clearFilters,
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Clear Filters',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    _isDownloadingExcel
                        ? null
                        : _downloadExcel,
                icon: _isDownloadingExcel
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.table_view_rounded,
                        size: 19,
                      ),
                label: Text(
                  _isDownloadingExcel
                      ? 'Saving Excel...'
                      : 'Download Excel',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    _isDownloadingPdf
                        ? null
                        : _downloadPdf,
                icon: _isDownloadingPdf
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 19,
                      ),
                label: Text(
                  _isDownloadingPdf
                      ? 'Saving PDF...'
                      : 'Download PDF',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _semesterLabel(
    Map<String, dynamic> semester,
  ) {
    final name = _text(
      semester['semester_name'],
      fallback: '',
    );

    final number = _text(
      semester['semester_number'],
      fallback: '',
    );

    if (name.isNotEmpty) {
      return name;
    }

    if (number.isNotEmpty) {
      return 'Semester $number';
    }

    return 'Semester ${_int(semester['semester_id'])}';
  }

  Widget _dateFilterButton({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return SizedBox(
      width: 190,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border:
                const OutlineInputBorder(),
            isDense: true,
            suffixIcon: onClear == null
                ? const Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                  )
                : IconButton(
                    tooltip: 'Clear $label',
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                    ),
                  ),
          ),
          child: Text(
            value,
            overflow:
                TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 80,
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.error.withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ??
                  'Unable to load report.',
              style: const TextStyle(
                color: AppColors.error,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadReport,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final report = _report ?? {};
    final summary =
        _map(report['summary']);
    final subjectWise =
        _list(report['subject_wise']);
    final sectionWise =
        _list(report['section_wise']);
    final dayWise =
        _list(report['day_wise']);
    final sessionWise =
        _list(report['session_wise']);
    final records =
        _list(report['records']);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildSummary(summary),
        const SizedBox(height: 16),
        _reportCard(
          title: 'Subject Wise',
          subtitle:
              'Attendance performance grouped by subject.',
          child: _buildGroupedTable(
            rows: subjectWise,
            leadingColumns: const [
              _ReportColumn(
                keyName: 'subject_code',
                label: 'Code',
              ),
              _ReportColumn(
                keyName: 'subject_name',
                label: 'Subject',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _reportCard(
          title: 'Section Wise',
          subtitle:
              'Attendance performance grouped by class section.',
          child: _buildGroupedTable(
            rows: sectionWise,
            leadingColumns: const [
              _ReportColumn(
                keyName: 'semester_id',
                label: 'Semester ID',
              ),
              _ReportColumn(
                keyName: 'section_name',
                label: 'Section',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _reportCard(
          title: 'Day Wise',
          subtitle:
              'Attendance performance for each attendance date.',
          child: _buildGroupedTable(
            rows: dayWise,
            leadingColumns: const [
              _ReportColumn(
                keyName: 'date',
                label: 'Date',
                isDate: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _reportCard(
          title: 'Session Wise',
          subtitle:
              'Attendance performance for each individual session.',
          child:
              _buildSessionTable(sessionWise),
        ),
        const SizedBox(height: 16),
        _reportCard(
          title: 'Detailed Records',
          subtitle:
              'One row for every expected student/session attendance opportunity. '
              'NOT_MARKED means no attendance record exists for that session.',
          child:
              _buildDetailedTable(records),
        ),
      ],
    );
  }

  Widget _buildSummary(
    Map<String, dynamic> summary,
  ) {
    final cards =
        <Widget>[
      _summaryCard(
        'Sessions',
        _int(
          summary['total_sessions'],
        ).toString(),
        Icons.event_note_rounded,
      ),
      _summaryCard(
        'Students',
        _int(
          summary['total_students'],
        ).toString(),
        Icons.groups_rounded,
      ),
      _summaryCard(
        'Opportunities',
        _int(
          summary[
              'attendance_opportunities'],
        ).toString(),
        Icons.fact_check_rounded,
      ),
      _summaryCard(
        'Records',
        _int(
          summary['attendance_records'],
        ).toString(),
        Icons.receipt_long_rounded,
      ),
      _summaryCard(
        'Present',
        _int(
          summary['present'],
        ).toString(),
        Icons.check_circle_rounded,
      ),
      _summaryCard(
        'Pending',
        _int(
          summary['pending'],
        ).toString(),
        Icons.pending_actions_rounded,
      ),
      _summaryCard(
        'Rejected',
        _int(
          summary['rejected'],
        ).toString(),
        Icons.cancel_rounded,
      ),
      _summaryCard(
        'Not Marked',
        _int(
          summary['not_marked'],
        ).toString(),
        Icons.remove_circle_outline_rounded,
      ),
      _summaryCard(
        'Attendance',
        _percentage(
          summary['attendance_percentage'],
        ),
        Icons.percent_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth;

        final itemWidth = width >= 1200
            ? (width - 48) / 5
            : width >= 800
                ? (width - 36) / 4
                : width >= 520
                    ? (width - 12) / 2
                    : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: itemWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  AppColors.surfaceSoft,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 21,
              color:
                  AppColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildGroupedTable({
    required List<Map<String, dynamic>>
        rows,
    required List<_ReportColumn>
        leadingColumns,
  }) {
    if (rows.isEmpty) {
      return _emptyTableMessage();
    }

    const metricColumns = [
      _ReportColumn(
        keyName: 'session_count',
        label: 'Sessions',
      ),
      _ReportColumn(
        keyName: 'attendance_opportunities',
        label: 'Opportunities',
      ),
      _ReportColumn(
        keyName: 'attendance_records',
        label: 'Records',
      ),
      _ReportColumn(
        keyName: 'present',
        label: 'Present',
      ),
      _ReportColumn(
        keyName: 'pending',
        label: 'Pending',
      ),
      _ReportColumn(
        keyName: 'rejected',
        label: 'Rejected',
      ),
      _ReportColumn(
        keyName: 'not_marked',
        label: 'Not Marked',
      ),
      _ReportColumn(
        keyName: 'attendance_percentage',
        label: 'Attendance %',
        isPercentage: true,
      ),
    ];

    final columns = [
      ...leadingColumns,
      ...metricColumns,
    ];

    return _horizontalTable(
      DataTable(
        columns: [
          for (final column in columns)
            DataColumn(
              label: Text(column.label),
            ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final column
                    in columns)
                  DataCell(
                    Text(
                      column.isPercentage
                          ? _percentage(
                              row[column.keyName],
                            )
                          : column.isDate
                              ? _formatDateValue(
                                  row[column.keyName],
                                )
                              : _text(
                                  row[column.keyName],
                                  fallback: '0',
                                ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionTable(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return _emptyTableMessage();
    }

    return _horizontalTable(
      DataTable(
        columns: const [
          DataColumn(
            label: Text('Date'),
          ),
          DataColumn(
            label: Text('Session'),
          ),
          DataColumn(
            label: Text('Subject'),
          ),
          DataColumn(
            label: Text('Section'),
          ),
          DataColumn(
            label: Text('QR Status'),
          ),
          DataColumn(
            label: Text('Expected'),
          ),
          DataColumn(
            label: Text('Records'),
          ),
          DataColumn(
            label: Text('Present'),
          ),
          DataColumn(
            label: Text('Pending'),
          ),
          DataColumn(
            label: Text('Rejected'),
          ),
          DataColumn(
            label: Text('Not Marked'),
          ),
          DataColumn(
            label: Text('Attendance %'),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    _formatDateValue(
                      row['date'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['session_id'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_text(row['subject_code'])} - '
                    '${_text(row['subject_name'])}',
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['section_name'],
                    ),
                  ),
                ),
                DataCell(
                  _statusBadge(
                    _text(
                      row['qr_status'] ??
                          row['session_status'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['expected_students'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['attendance_records'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['present'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['pending'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['rejected'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['not_marked'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _percentage(
                      row[
                          'attendance_percentage'],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedTable(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return _emptyTableMessage();
    }

    return _horizontalTable(
      DataTable(
        columns: const [
          DataColumn(
            label: Text('Date'),
          ),
          DataColumn(
            label: Text('Session'),
          ),
          DataColumn(
            label: Text('Subject'),
          ),
          DataColumn(
            label: Text('Section'),
          ),
          DataColumn(
            label: Text('Student'),
          ),
          DataColumn(
            label: Text('Enrollment'),
          ),
          DataColumn(
            label: Text('Roll No.'),
          ),
          DataColumn(
            label: Text('QR Status'),
          ),
          DataColumn(
            label: Text('Attendance Status'),
          ),
          DataColumn(
            label: Text('QR Verified'),
          ),
          DataColumn(
            label: Text('Geofence'),
          ),
          DataColumn(
            label: Text('Face'),
          ),
          DataColumn(
            label: Text('Liveness'),
          ),
          DataColumn(
            label: Text('Marked At'),
          ),
          DataColumn(
            label: Text('Distance (m)'),
          ),
          DataColumn(
            label: Text('Rejection Reason'),
          ),
          DataColumn(
            label: Text('Result Explanation'),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    _formatDateValue(
                      row['date'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['session_id'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_text(row['subject_code'])} - '
                    '${_text(row['subject_name'])}',
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['section_name'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['student_name'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row[
                          'enrollment_number'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['roll_number'],
                    ),
                  ),
                ),
                DataCell(
                  _statusBadge(
                    _text(
                      row['qr_status'] ??
                          row['session_status'],
                    ),
                  ),
                ),
                DataCell(
                  _attendanceStatusBadge(
                    attendanceStatus:
                        _text(
                      row['attendance_status'],
                    ),
                    qrStatus:
                        _text(
                      row['qr_status'] ??
                          row['session_status'],
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _bool(
                      row['qr_verified'],
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _bool(
                      row['geofence_verified'],
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _bool(
                      row['face_verified'],
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _bool(
                      row['liveness_verified'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _formatDateTimeValue(
                      row['marked_at'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    row[
                                'distance_from_classroom_meters'] ==
                            null
                        ? '-'
                        : _double(
                            row[
                                'distance_from_classroom_meters'],
                          ).toStringAsFixed(
                            2,
                          ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Text(
                      _text(
                        row[
                            'rejection_reason'],
                      ),
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      _resultExplanation(
                        row,
                      ),
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _horizontalTable(
    Widget table,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      ),
    );
  }

  Widget _emptyTableMessage() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 24,
      ),
      alignment: Alignment.center,
      child: Text(
        'No report data found for the selected filters.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _verificationIcon(
    bool verified,
  ) {
    return Tooltip(
      message:
          verified ? 'Verified' : 'Not verified',
      child: Icon(
        verified
            ? Icons.check_circle_rounded
            : Icons.remove_circle_outline_rounded,
        size: 20,
        color: verified
            ? AppColors.success
            : AppColors.textSecondary,
      ),
    );
  }

  Widget _attendanceStatusBadge({
    required String attendanceStatus,
    required String qrStatus,
  }) {
    if (qrStatus.toUpperCase() ==
            'CANCELLED' &&
        attendanceStatus.toUpperCase() ==
            'NOT_MARKED') {
      return Tooltip(
        message:
            'This QR/session was cancelled by faculty. '
            'The NOT_MARKED row is shown only for audit '
            'and does not reduce attendance.',
        child: _statusBadge(
          attendanceStatus,
        ),
      );
    }

    return _statusBadge(
      attendanceStatus,
    );
  }

  Widget _statusBadge(
    String status,
  ) {
    final normalized =
        status.toUpperCase();

    Color foreground;
    Color background;

    switch (normalized) {
      case 'PRESENT':
      case 'ACTIVE':
      case 'COMPLETED':
        foreground =
            AppColors.success;
        background =
            AppColors.success.withValues(alpha: 0.08);
        break;

      case 'PENDING':
        foreground =
            AppColors.warning;
        background =
            AppColors.warning.withValues(alpha: 0.10);
        break;

      case 'REJECTED':
      case 'CANCELLED':
        foreground =
            AppColors.error;
        background =
            AppColors.error.withValues(alpha: 0.08);
        break;

      case 'NOT_MARKED':
        foreground =
            AppColors.textSecondary;
        background =
            AppColors.surfaceSoft;
        break;

      default:
        foreground =
            AppColors.textSecondary;
        background =
            AppColors.surfaceSoft;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        normalized.replaceAll('_', ' '),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius:
          BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.border,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    );
  }
}

class _ReportColumn {
  const _ReportColumn({
    required this.keyName,
    required this.label,
    this.isPercentage = false,
    this.isDate = false,
  });

  final String keyName;
  final String label;
  final bool isPercentage;
  final bool isDate;
}
