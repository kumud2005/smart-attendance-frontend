import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/admin_service.dart';

class AdminRegistrationRequestsScreen
    extends StatefulWidget {
  final String initialRole;

  const AdminRegistrationRequestsScreen({
    super.key,
    this.initialRole = 'STUDENT',
  });

  @override
  State<AdminRegistrationRequestsScreen>
      createState() =>
          _AdminRegistrationRequestsScreenState();
}

class _AdminRegistrationRequestsScreenState
    extends State<AdminRegistrationRequestsScreen> {
  final AdminService _adminService =
      AdminService();

  String _roleName = 'STUDENT';

  bool _isLoading = true;
  bool _isProcessing = false;

  String? _errorMessage;
  String _searchQuery = '';

  List<Map<String, dynamic>> _requests =
      <Map<String, dynamic>>[];

  bool get _isStudent =>
      _roleName == 'STUDENT';

  @override
  void initState() {
    super.initState();

    final initial =
        widget.initialRole
            .trim()
            .toUpperCase();

    _roleName = initial == 'FACULTY'
        ? 'FACULTY'
        : 'STUDENT';

    _loadRequests();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadRequests() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests = _isStudent
          ? await _adminService
              .getStudentRegistrationRequests()
          : await _adminService
              .getFacultyRegistrationRequests();

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = requests;
        _isLoading = false;
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

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>>
      get _filteredRequests {
    final query =
        _searchQuery
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return _requests;
    }

    return _requests.where((request) {
      final assignments =
          request['assignments'];

      final searchable = <String>[
        request['user_id']?.toString() ??
            '',
        request['student_id']
                ?.toString() ??
            '',
        request['faculty_id']
                ?.toString() ??
            '',
        request['full_name']
                ?.toString() ??
            '',
        request['email']?.toString() ??
            '',
        request['phone']?.toString() ??
            '',
        request['enrollment_number']
                ?.toString() ??
            '',
        request['roll_number']
                ?.toString() ??
            '',
        request['employee_id']
                ?.toString() ??
            '',
        request['department']
                ?.toString() ??
            '',
        request['designation']
                ?.toString() ??
            '',
        request['section_name']
                ?.toString() ??
            '',
        request['semester_name']
                ?.toString() ??
            '',
        if (assignments is List)
          ...assignments.map(
            (item) => item.toString(),
          ),
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  // ============================================================
  // ROLE
  // ============================================================

  Future<void> _changeRole(
    String roleName,
  ) async {
    if (_isProcessing ||
        roleName == _roleName) {
      return;
    }

    setState(() {
      _roleName = roleName;
      _searchQuery = '';
      _requests = [];
      _errorMessage = null;
    });

    await _loadRequests();
  }

  // ============================================================
  // APPROVE / REJECT
  // ============================================================

  Future<void> _approve(
    Map<String, dynamic> request,
  ) async {
    final note = await _askForNote(
      title: 'Approve Registration',
      message: _isStudent
          ? 'Approve this Student and assign the requested Section?'
          : 'Approve this Faculty account and activate the requested academic assignments?',
      actionLabel: 'Approve',
      noteHint:
          'Approval note (optional)',
      destructive: false,
    );

    if (note == null) {
      return;
    }

    await _processDecision(
      request: request,
      approve: true,
      note: note,
    );
  }

  Future<void> _reject(
    Map<String, dynamic> request,
  ) async {
    final note = await _askForNote(
      title: 'Reject Registration',
      message:
          'Reject this registration request?',
      actionLabel: 'Reject',
      noteHint:
          'Reason for rejection (optional)',
      destructive: true,
    );

    if (note == null) {
      return;
    }

    await _processDecision(
      request: request,
      approve: false,
      note: note,
    );
  }

  Future<void> _processDecision({
    required Map<String, dynamic>
        request,
    required bool approve,
    required String note,
  }) async {
    final userId =
        _readInt(request['user_id']);

    if (userId == null) {
      _showMessage(
        'This request does not contain a valid User ID.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      late final Map<String, dynamic>
          response;

      if (_isStudent) {
        response = approve
            ? await _adminService
                .approveStudentRegistration(
                userId: userId,
                note: note,
              )
            : await _adminService
                .rejectStudentRegistration(
                userId: userId,
                note: note,
              );
      } else {
        response = approve
            ? await _adminService
                .approveFacultyRegistration(
                userId: userId,
                note: note,
              )
            : await _adminService
                .rejectFacultyRegistration(
                userId: userId,
                note: note,
              );
      }

      if (!mounted) {
        return;
      }

      final message =
          response['message']
              ?.toString()
              .trim();

      _showMessage(
        message == null ||
                message.isEmpty
            ? approve
                ? 'Registration approved successfully.'
                : 'Registration rejected successfully.'
            : message,
      );

      await _loadRequests();
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
          _isProcessing = false;
        });
      }
    }
  }

  Future<String?> _askForNote({
    required String title,
    required String message,
    required String actionLabel,
    required String noteHint,
    required bool destructive,
  }) async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                Text(message),
                const SizedBox(
                  height: 16,
                ),
                TextField(
                  controller:
                      controller,
                  maxLength: 255,
                  maxLines: 3,
                  decoration:
                      InputDecoration(
                    labelText:
                        noteHint,
                    alignLabelWithHint:
                        true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(null);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor:
                          AppColors.error,
                    )
                  : null,
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  controller.text.trim(),
                );
              },
              child: Text(
                actionLabel,
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _showDetails(
    Map<String, dynamic> request,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _isStudent
                ? 'Student Registration'
                : 'Faculty Registration',
          ),
          content: SizedBox(
            width: 650,
            child:
                SingleChildScrollView(
              child: _isStudent
                  ? _buildStudentDetails(
                      request,
                    )
                  : _buildFacultyDetails(
                      request,
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudentDetails(
    Map<String, dynamic> request,
  ) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        _detailRow(
          'User ID',
          _value(request['user_id']),
        ),
        _detailRow(
          'Student ID',
          _value(request['student_id']),
        ),
        _detailRow(
          'Full Name',
          _value(request['full_name']),
        ),
        _detailRow(
          'Email',
          _value(request['email']),
        ),
        _detailRow(
          'Phone',
          _value(request['phone']),
        ),
        _detailRow(
          'Enrollment No.',
          _value(
            request['enrollment_number'],
          ),
        ),
        _detailRow(
          'Roll No.',
          _value(request['roll_number']),
        ),
        _detailRow(
          'Date of Birth',
          _value(
            request['date_of_birth'],
          ),
        ),
        _detailRow(
          'Account Status',
          _value(
            request['account_status'],
          ),
        ),
        _detailRow(
          'Semester',
          _semesterText(request),
        ),
        _detailRow(
          'Section',
          _sectionText(request),
        ),
        _detailRow(
          'Request Status',
          _value(
            request['request_status'],
          ),
        ),
        _detailRow(
          'Requested At',
          _value(
            request['requested_at'],
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyDetails(
    Map<String, dynamic> request,
  ) {
    final assignments =
        _mapList(
      request['assignments'],
    );

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _detailRow(
          'User ID',
          _value(request['user_id']),
        ),
        _detailRow(
          'Faculty ID',
          _value(request['faculty_id']),
        ),
        _detailRow(
          'Full Name',
          _value(request['full_name']),
        ),
        _detailRow(
          'Email',
          _value(request['email']),
        ),
        _detailRow(
          'Phone',
          _value(request['phone']),
        ),
        _detailRow(
          'Employee ID',
          _value(request['employee_id']),
        ),
        _detailRow(
          'Department',
          _value(request['department']),
        ),
        _detailRow(
          'Designation',
          _value(
            request['designation'],
          ),
        ),
        _detailRow(
          'Account Status',
          _value(
            request['account_status'],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Requested Assignments',
          style: TextStyle(
            color:
                AppColors.textPrimary,
            fontSize: 16,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (assignments.isEmpty)
          const Text(
            'No requested assignments were returned.',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          )
        else
          ...assignments.map(
            _buildAssignmentTile,
          ),
      ],
    );
  }

  Widget _buildAssignmentTile(
    Map<String, dynamic> assignment,
  ) {
    final code =
        _value(
      assignment['subject_code'],
    );
    final name =
        _value(
      assignment['subject_name'],
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            AppColors.surfaceSoft,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            code == '-'
                ? name
                : '$code - $name',
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_semesterText(assignment)} • ${_sectionText(assignment)}',
            style:
                const TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Registration Requests',
        ),
        backgroundColor:
            AppColors.primary,
        foregroundColor:
            AppColors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoading ||
                        _isProcessing
                    ? null
                    : _loadRequests,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: AppColors.surface,
      padding:
          const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child:
                SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'STUDENT',
                  icon: Icon(
                    Icons
                        .school_outlined,
                  ),
                  label: Text(
                    'Students',
                  ),
                ),
                ButtonSegment<String>(
                  value: 'FACULTY',
                  icon: Icon(
                    Icons
                        .co_present_outlined,
                  ),
                  label: Text(
                    'Faculty',
                  ),
                ),
              ],
              selected: {
                _roleName,
              },
              showSelectedIcon: false,
              onSelectionChanged:
                  _isProcessing
                      ? null
                      : (selection) {
                          _changeRole(
                            selection
                                .first,
                          );
                        },
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          TextField(
            enabled: !_isProcessing,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration:
                InputDecoration(
              hintText: _isStudent
                  ? 'Search Student requests...'
                  : 'Search Faculty requests...',
              prefixIcon:
                  const Icon(
                Icons.search_rounded,
              ),
              filled: true,
              fillColor:
                  AppColors.surfaceSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final requests =
        _filteredRequests;

    if (requests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding:
            const EdgeInsets.all(
          18,
        ),
        physics:
            const AlwaysScrollableScrollPhysics(),
        itemCount: requests.length,
        separatorBuilder:
            (_, _) =>
                const SizedBox(
          height: 12,
        ),
        itemBuilder:
            (context, index) {
          return _buildRequestCard(
            requests[index],
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request,
  ) {
    final fullName =
        _value(
      request['full_name'],
    );
    final email =
        _value(
      request['email'],
    );

    final subtitle = _isStudent
        ? '${_semesterText(request)} • ${_sectionText(request)}'
        : '${_mapList(request['assignments']).length} requested assignment(s)';

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _showDetails(request),
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        AppColors
                            .surfaceSoft,
                    child: Icon(
                      _isStudent
                          ? Icons
                              .school_rounded
                          : Icons
                              .co_present_rounded,
                      color:
                          AppColors.primary,
                    ),
                  ),
                  const SizedBox(
                    width: 14,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          fullName,
                          style:
                              const TextStyle(
                            color: AppColors
                                .textPrimary,
                            fontSize: 16,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          email,
                          style:
                              const TextStyle(
                            color: AppColors
                                .textSecondary,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Text(
                          subtitle,
                          style:
                              const TextStyle(
                            color: AppColors
                                .textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _pendingChip(),
                ],
              ),
              const SizedBox(
                height: 16,
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment:
                    WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _isProcessing
                            ? null
                            : () =>
                                _showDetails(
                                  request,
                                ),
                    icon:
                        const Icon(
                      Icons
                          .visibility_outlined,
                    ),
                    label:
                        const Text(
                      'Details',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isProcessing
                            ? null
                            : () =>
                                _reject(
                                  request,
                                ),
                    icon:
                        const Icon(
                      Icons
                          .close_rounded,
                    ),
                    label:
                        const Text(
                      'Reject',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _isProcessing
                            ? null
                            : () =>
                                _approve(
                                  request,
                                ),
                    icon:
                        const Icon(
                      Icons
                          .check_rounded,
                    ),
                    label:
                        const Text(
                      'Approve',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingChip() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning
            .withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child:
          const Text(
        'PENDING',
        style: TextStyle(
          color:
              AppColors.warning,
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .task_alt_rounded,
              size: 68,
              color: AppColors
                  .textSecondary,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              _isStudent
                  ? 'No pending Student registrations'
                  : 'No pending Faculty registrations',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: AppColors
                    .textPrimary,
                fontSize: 19,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'There are no registration requests waiting for review.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: AppColors
                    .textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              28,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .cloud_off_rounded,
                  size: 52,
                  color:
                      AppColors.error,
                ),
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'Unable to load registration requests',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: AppColors
                        .textPrimary,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  _errorMessage ??
                      'An unknown error occurred.',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color: AppColors
                        .textSecondary,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                FilledButton.icon(
                  onPressed:
                      _loadRequests,
                  icon:
                      const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style:
                  const TextStyle(
                color: AppColors
                    .textPrimary,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                color: AppColors
                    .textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  List<Map<String, dynamic>>
      _mapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
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

  String _value(dynamic value) {
    final text =
        value?.toString().trim();

    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() ==
            'null') {
      return '-';
    }

    return text;
  }

  String _semesterText(
    Map<String, dynamic> item,
  ) {
    final number =
        _value(
      item['semester_number'],
    );
    final name =
        _value(
      item['semester_name'],
    );

    if (name != '-' &&
        number != '-') {
      return 'Semester $number - $name';
    }

    if (name != '-') {
      return name;
    }

    if (number != '-') {
      return 'Semester $number';
    }

    final semesterId =
        _readInt(
      item['semester_id'],
    );

    return semesterId == null
        ? 'Semester -'
        : 'Semester $semesterId';
  }

  String _sectionText(
    Map<String, dynamic> item,
  ) {
    final name =
        _value(
      item['section_name'],
    );

    if (name != '-') {
      return 'Section $name';
    }

    final sectionId =
        _readInt(
      item['section_id'],
    );

    return sectionId == null
        ? 'Section -'
        : 'Section $sectionId';
  }

  String _cleanErrorMessage(
    Object error,
  ) {
    var message =
        error.toString().trim();

    if (message.startsWith(
      'Exception: ',
    )) {
      message = message
          .substring(
            'Exception: '.length,
          )
          .trim();
    }

    final lower =
        message.toLowerCase();

    if (lower.contains(
          'failed to fetch',
        ) ||
        lower.contains(
          'clientexception',
        ) ||
        lower.contains(
          'xmlhttprequest error',
        ) ||
        lower.contains(
          'socketexception',
        ) ||
        lower.contains(
          'connection refused',
        ) ||
        lower.contains(
          'network request failed',
        )) {
      return 'Unable to connect to the server. '
          'Please check your connection and try again.';
    }

    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError
                  ? AppColors.error
                  : null,
        ),
      );
  }
}
