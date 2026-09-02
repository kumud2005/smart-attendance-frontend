import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/admin_service.dart';

class AdminFacultyAssignmentsScreen
    extends StatefulWidget {
  const AdminFacultyAssignmentsScreen({
    super.key,
  });

  @override
  State<AdminFacultyAssignmentsScreen>
      createState() =>
          _AdminFacultyAssignmentsScreenState();
}

class _AdminFacultyAssignmentsScreenState
    extends State<AdminFacultyAssignmentsScreen> {
  final AdminService _adminService =
      AdminService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _activeOnly = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _faculties =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _semesters =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _sections =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _subjects =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _assignments =
      <Map<String, dynamic>>[];

  int? _selectedFacultyId;
  int? _selectedSemesterId;
  int? _selectedSectionId;
  int? _selectedSubjectId;

  String _searchQuery = '';

  List<Map<String, dynamic>>
      get _filteredSections {
    final semesterId =
        _selectedSemesterId;

    if (semesterId == null) {
      return <Map<String, dynamic>>[];
    }

    return _sections.where((item) {
      return _readInt(
            item['semester_id'],
          ) ==
          semesterId;
    }).toList();
  }

  List<Map<String, dynamic>>
      get _filteredSubjects {
    final semesterId =
        _selectedSemesterId;

    if (semesterId == null) {
      return <Map<String, dynamic>>[];
    }

    return _subjects.where((item) {
      return _readInt(
            item['semester_id'],
          ) ==
          semesterId;
    }).toList();
  }

  List<Map<String, dynamic>>
      get _visibleAssignments {
    final query =
        _searchQuery
            .trim()
            .toLowerCase();

    return _assignments.where((item) {
      final active =
          _readBool(item['is_active']);

      if (_activeOnly && !active) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        item['assignment_id'],
        item['faculty_name'],
        item['employee_id'],
        item['semester_number'],
        item['semester_name'],
        item['section_name'],
        item['subject_code'],
        item['subject_name'],
        active ? 'active' : 'inactive',
      ].map(
        (value) =>
            value?.toString() ?? '',
      ).join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final optionsFuture =
          _adminService
              .getFacultyAssignmentOptions();

      final assignmentsFuture =
          _adminService
              .getFacultyAssignments();

      final results = await Future.wait([
        optionsFuture,
        assignmentsFuture,
      ]);

      final options =
          results[0]
              as Map<String, dynamic>;

      final assignments =
          results[1]
              as List<Map<String, dynamic>>;

      if (!mounted) {
        return;
      }

      setState(() {
        _faculties = _readMapList(
          options['faculties'],
        );
        _semesters = _readMapList(
          options['semesters'],
        );
        _sections = _readMapList(
          options['sections'],
        );
        _subjects = _readMapList(
          options['subjects'],
        );
        _assignments = assignments;

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

  Future<void>
      _reloadAssignments() async {
    try {
      final assignments =
          await _adminService
              .getFacultyAssignments();

      if (!mounted) {
        return;
      }

      setState(() {
        _assignments = assignments;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    }
  }

  // ============================================================
  // FORM
  // ============================================================

  void _selectSemester(int? value) {
    setState(() {
      _selectedSemesterId = value;
      _selectedSectionId = null;
      _selectedSubjectId = null;
    });
  }

  Future<void>
      _createAssignment() async {
    final facultyId =
        _selectedFacultyId;
    final semesterId =
        _selectedSemesterId;
    final sectionId =
        _selectedSectionId;
    final subjectId =
        _selectedSubjectId;

    if (facultyId == null) {
      _showMessage(
        'Please select a Faculty member.',
        isError: true,
      );
      return;
    }

    if (semesterId == null) {
      _showMessage(
        'Please select a Semester.',
        isError: true,
      );
      return;
    }

    if (sectionId == null) {
      _showMessage(
        'Please select a Section.',
        isError: true,
      );
      return;
    }

    if (subjectId == null) {
      _showMessage(
        'Please select a Subject.',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Confirm Faculty Assignment',
          ),
          content: Text(
            '${_facultyLabel(facultyId)}\n\n'
            '${_semesterLabel(semesterId)}\n'
            '${_sectionLabel(sectionId)}\n'
            '${_subjectLabel(subjectId)}\n\n'
            'Assign this academic scope to the selected Faculty member?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text('Assign'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response =
          await _adminService
              .createFacultyAssignment(
        facultyId: facultyId,
        semesterId: semesterId,
        sectionId: sectionId,
        subjectId: subjectId,
      );

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
            ? 'Faculty assignment saved successfully.'
            : message,
      );

      setState(() {
        _selectedSectionId = null;
        _selectedSubjectId = null;
      });

      await _reloadAssignments();
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
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deactivate(
    Map<String, dynamic> assignment,
  ) async {
    final assignmentId =
        _readInt(
      assignment['assignment_id'],
    );

    if (assignmentId == null) {
      _showMessage(
        'Invalid assignment ID.',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Deactivate Assignment',
          ),
          content: Text(
            'Deactivate this Faculty assignment?\n\n'
            '${_value(assignment['faculty_name'])}\n'
            '${_semesterFromAssignment(assignment)} • '
            'Section ${_value(assignment['section_name'])}\n'
            '${_value(assignment['subject_code'])} - '
            '${_value(assignment['subject_name'])}\n\n'
            'The assignment record will remain in history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.error,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text(
                'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response =
          await _adminService
              .deactivateFacultyAssignment(
        assignmentId,
      );

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
            ? 'Faculty assignment deactivated successfully.'
            : message,
      );

      await _reloadAssignments();
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
          _isSaving = false;
        });
      }
    }
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
          'Faculty Assignments',
        ),
        backgroundColor:
            AppColors.primary,
        foregroundColor:
            AppColors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoading || _isSaving
                    ? null
                    : _loadData,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final wide =
            constraints.maxWidth >= 1050;

        if (wide) {
          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 430,
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  child:
                      _buildAssignmentForm(),
                ),
              ),
              const VerticalDivider(
                width: 1,
              ),
              Expanded(
                child:
                    _buildAssignmentList(),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child:
              SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                _buildAssignmentForm(),
                const SizedBox(
                  height: 18,
                ),
                _buildAssignmentList(
                  embedded: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentForm() {
    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons
                      .assignment_ind_outlined,
                  color:
                      AppColors.primary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Assign Academic Scope',
                    style:
                        TextStyle(
                      color: AppColors
                          .textPrimary,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Choose one active Faculty member, Semester, Section and Subject.',
              style: TextStyle(
                color: AppColors
                    .textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            _dropdown(
              label: 'Faculty',
              value:
                  _selectedFacultyId,
              items: _faculties.map(
                (item) {
                  final id =
                      _readInt(
                    item['faculty_id'],
                  );

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int>(
                    value: id,
                    child: Text(
                      _facultyLabel(id),
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  );
                },
              ).whereType<
                  DropdownMenuItem<
                      int>>().toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedFacultyId =
                            value;
                      });
                    },
            ),
            const SizedBox(
              height: 16,
            ),
            _dropdown(
              label: 'Semester',
              value:
                  _selectedSemesterId,
              items: _semesters.map(
                (item) {
                  final id =
                      _readInt(
                    item['semester_id'],
                  );

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int>(
                    value: id,
                    child: Text(
                      _semesterLabel(id),
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  );
                },
              ).whereType<
                  DropdownMenuItem<
                      int>>().toList(),
              onChanged: _isSaving
                  ? null
                  : _selectSemester,
            ),
            const SizedBox(
              height: 16,
            ),
            _dropdown(
              label: 'Section',
              value:
                  _selectedSectionId,
              items:
                  _filteredSections.map(
                (item) {
                  final id =
                      _readInt(
                    item['section_id'],
                  );

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int>(
                    value: id,
                    child: Text(
                      _sectionLabel(id),
                    ),
                  );
                },
              ).whereType<
                  DropdownMenuItem<
                      int>>().toList(),
              onChanged:
                  _selectedSemesterId ==
                              null ||
                          _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedSectionId =
                                value;
                          });
                        },
            ),
            const SizedBox(
              height: 16,
            ),
            _dropdown(
              label: 'Subject',
              value:
                  _selectedSubjectId,
              items:
                  _filteredSubjects.map(
                (item) {
                  final id =
                      _readInt(
                    item['subject_id'],
                  );

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int>(
                    value: id,
                    child: Text(
                      _subjectLabel(id),
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  );
                },
              ).whereType<
                  DropdownMenuItem<
                      int>>().toList(),
              onChanged:
                  _selectedSemesterId ==
                              null ||
                          _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedSubjectId =
                                value;
                          });
                        },
            ),
            const SizedBox(
              height: 20,
            ),
            SizedBox(
              height: 50,
              child:
                  FilledButton.icon(
                onPressed: _isSaving
                    ? null
                    : _createAssignment,
                icon: _isSaving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2.3,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .add_task_rounded,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : 'Assign to Faculty',
                ),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'To give the same Faculty multiple subjects or sections, save each assignment separately. Existing inactive combinations can be reactivated by the backend.',
              style: TextStyle(
                color: AppColors
                    .textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList({
    bool embedded = false,
  }) {
    final assignments =
        _visibleAssignments;

    final content = Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildListControls(),
        if (assignments.isEmpty)
          _buildEmptyState()
        else
          ...List.generate(
            assignments.length,
            (index) {
              return Padding(
                padding:
                    EdgeInsets.only(
                  bottom: index ==
                          assignments
                                  .length -
                              1
                      ? 0
                      : 10,
                ),
                child:
                    _buildAssignmentCard(
                  assignments[index],
                ),
              );
            },
          ),
      ],
    );

    if (embedded) {
      return content;
    }

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(18),
      child: content,
    );
  }

  Widget _buildListControls() {
    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Assignment History',
                    style:
                        TextStyle(
                      color: AppColors
                          .textPrimary,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: _activeOnly,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _activeOnly =
                                value;
                          });
                        },
                ),
                const Text(
                  'Active only',
                  style: TextStyle(
                    color: AppColors
                        .textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              enabled: !_isSaving,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration:
                  const InputDecoration(
                hintText:
                    'Search Faculty, subject, section...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(
    Map<String, dynamic> item,
  ) {
    final active =
        _readBool(item['is_active']);

    final facultyName =
        _value(item['faculty_name']);
    final employeeId =
        _value(item['employee_id']);
    final subjectCode =
        _value(item['subject_code']);
    final subjectName =
        _value(item['subject_name']);
    final sectionName =
        _value(item['section_name']);

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppColors
                          .surfaceSoft,
                  child: const Icon(
                    Icons
                        .co_present_rounded,
                    color:
                        AppColors.primary,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        facultyName,
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
                        height: 3,
                      ),
                      Text(
                        'Employee ID: $employeeId',
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
                _statusChip(active),
              ],
            ),
            const SizedBox(
              height: 14,
            ),
            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color: AppColors
                    .surfaceSoft,
                borderRadius:
                    BorderRadius
                        .circular(12),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    '$subjectCode - $subjectName',
                    style:
                        const TextStyle(
                      color: AppColors
                          .textPrimary,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    '${_semesterFromAssignment(item)} • Section $sectionName',
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
            if (active) ...[
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child:
                    OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () =>
                          _deactivate(
                            item,
                          ),
                  icon: const Icon(
                    Icons
                        .remove_circle_outline_rounded,
                  ),
                  label: const Text(
                    'Deactivate',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool active) {
    final color = active
        ? AppColors.success
        : AppColors.textSecondary;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(36),
        child: Column(
          children: [
            Icon(
              Icons
                  .assignment_outlined,
              size: 58,
              color: AppColors
                  .textSecondary,
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'No faculty assignments found',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: AppColors
                    .textPrimary,
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              'Create a new assignment or change the current filters.',
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
                  'Unable to load Faculty assignments',
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
                  onPressed: _loadData,
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

  Widget _dropdown({
    required String label,
    required int? value,
    required List<
            DropdownMenuItem<int>>
        items,
    required ValueChanged<int?>?
        onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  // ============================================================
  // LABELS / PARSING
  // ============================================================

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final text =
        value?.toString()
            .trim()
            .toLowerCase();

    return text == 'true' ||
        text == '1';
  }

  List<Map<String, dynamic>>
      _readMapList(dynamic value) {
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

  Map<String, dynamic>? _findById(
    List<Map<String, dynamic>> items,
    String key,
    int id,
  ) {
    for (final item in items) {
      if (_readInt(item[key]) == id) {
        return item;
      }
    }

    return null;
  }

  String _facultyLabel(int id) {
    final item = _findById(
      _faculties,
      'faculty_id',
      id,
    );

    if (item == null) {
      return 'Faculty $id';
    }

    final name =
        _value(item['full_name']);
    final employeeId =
        _value(item['employee_id']);

    return '$name ($employeeId)';
  }

  String _semesterLabel(int id) {
    final item = _findById(
      _semesters,
      'semester_id',
      id,
    );

    if (item == null) {
      return 'Semester $id';
    }

    final number =
        _value(
      item['semester_number'],
    );
    final name =
        _value(
      item['semester_name'],
    );

    if (number != '-' &&
        name != '-') {
      return 'Semester $number - $name';
    }

    if (number != '-') {
      return 'Semester $number';
    }

    if (name != '-') {
      return name;
    }

    return 'Semester $id';
  }

  String _sectionLabel(int id) {
    final item = _findById(
      _sections,
      'section_id',
      id,
    );

    final name =
        _value(
      item?['section_name'],
    );

    return name == '-'
        ? 'Section $id'
        : 'Section $name';
  }

  String _subjectLabel(int id) {
    final item = _findById(
      _subjects,
      'subject_id',
      id,
    );

    if (item == null) {
      return 'Subject $id';
    }

    final code =
        _value(item['subject_code']);
    final name =
        _value(item['subject_name']);

    if (code != '-' &&
        name != '-') {
      return '$code - $name';
    }

    return name != '-'
        ? name
        : code != '-'
            ? code
            : 'Subject $id';
  }

  String _semesterFromAssignment(
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

    if (number != '-' &&
        name != '-') {
      return 'Semester $number - $name';
    }

    if (number != '-') {
      return 'Semester $number';
    }

    return name != '-'
        ? name
        : 'Semester ${_value(item['semester_id'])}';
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
