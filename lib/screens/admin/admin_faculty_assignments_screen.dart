import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_action_styles.dart';
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
  final Set<int> _selectedSubjectIds = <int>{};

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
    final sectionId =
        _selectedSectionId;

    if (semesterId == null) {
      return <Map<String, dynamic>>[];
    }

    final section = sectionId == null
        ? null
        : _findById(
            _sections,
            'section_id',
            sectionId,
          );

    final sectionProgramId =
        _readInt(section?['program_id']);
    final sectionBranchId =
        _readInt(section?['branch_id']);

    return _subjects.where((item) {
      if (_readInt(item['semester_id']) !=
          semesterId) {
        return false;
      }

      final subjectProgramId =
          _readInt(item['program_id']);
      final subjectBranchId =
          _readInt(item['branch_id']);

      if (sectionProgramId != null &&
          subjectProgramId != null &&
          subjectProgramId != sectionProgramId) {
        return false;
      }

      if (sectionBranchId != null &&
          subjectBranchId != null &&
          subjectBranchId != sectionBranchId) {
        return false;
      }

      return true;
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
      _selectedSubjectIds.clear();
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

    final validSubjectIds =
        _filteredSubjects
            .map(
              (item) =>
                  _readInt(
                item['subject_id'],
              ),
            )
            .whereType<int>()
            .toSet();

    final subjectIds =
        _selectedSubjectIds
            .where(
              validSubjectIds.contains,
            )
            .toList()
          ..sort();

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

    if (subjectIds.isEmpty) {
      _showMessage(
        'Please select at least one Subject.',
        isError: true,
      );
      return;
    }

    final activeExistingIds =
        _assignments
            .where(
              (item) =>
                  _readBool(
                    item['is_active'],
                  ) &&
                  _readInt(
                        item['faculty_id'],
                      ) ==
                      facultyId &&
                  _readInt(
                        item['section_id'],
                      ) ==
                      sectionId,
            )
            .map(
              (item) =>
                  _readInt(
                item['subject_id'],
              ),
            )
            .whereType<int>()
            .toSet();

    final idsToSave =
        subjectIds
            .where(
              (id) =>
                  !activeExistingIds
                      .contains(id),
            )
            .toList();

    final alreadyAssignedCount =
        subjectIds.length -
            idsToSave.length;

    if (idsToSave.isEmpty) {
      _showMessage(
        'All selected subjects are already actively assigned '
        'to this Faculty and Section.',
        isError: true,
      );
      return;
    }

    final previewLines =
        idsToSave
            .take(8)
            .map(
              (id) =>
                  '• ${_subjectLabel(id)}',
            )
            .join('\n');

    final remaining =
        idsToSave.length - 8;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            idsToSave.length == 1
                ? 'Confirm Faculty Assignment'
                : 'Confirm ${idsToSave.length} Subject Assignments',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 560,
            ),
            child: SingleChildScrollView(
              child: Text(
                '${_facultyLabel(facultyId)}\n'
                '${_semesterLabel(semesterId)} • '
                '${_sectionLabel(sectionId)}\n\n'
                '$previewLines'
                '${remaining > 0 ? '\n• +$remaining more subject(s)' : ''}'
                '${alreadyAssignedCount > 0 ? '\n\n$alreadyAssignedCount already-active subject(s) will be skipped.' : ''}'
                '\n\nAssign the selected subjects to this Faculty member?',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: Text(
                idsToSave.length == 1
                    ? 'Assign'
                    : 'Assign ${idsToSave.length}',
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

    var successCount = 0;
    final failedSubjects = <String>[];

    try {
      for (final subjectId in idsToSave) {
        try {
          await _adminService
              .createFacultyAssignment(
            facultyId: facultyId,
            semesterId: semesterId,
            sectionId: sectionId,
            subjectId: subjectId,
          );

          successCount++;
        } catch (error) {
          failedSubjects.add(
            '${_subjectLabel(subjectId)}: '
            '${_cleanErrorMessage(error)}',
          );
        }
      }

      if (!mounted) {
        return;
      }

      await _reloadAssignments();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSubjectIds.clear();
      });

      if (failedSubjects.isEmpty) {
        final skippedText =
            alreadyAssignedCount > 0
                ? ' $alreadyAssignedCount already-active assignment(s) were skipped.'
                : '';

        _showMessage(
          '$successCount subject assignment(s) saved successfully.'
          '$skippedText',
        );
      } else {
        _showMessage(
          '$successCount assignment(s) saved. '
          '${failedSubjects.length} failed. '
          '${failedSubjects.first}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  Future<void>
      _openSubjectMultiSelect() async {
    if (_selectedSemesterId == null) {
      _showMessage(
        'Please select a Semester first.',
        isError: true,
      );
      return;
    }

    if (_selectedSectionId == null) {
      _showMessage(
        'Please select a Section first.',
        isError: true,
      );
      return;
    }

    final available =
        _filteredSubjects;

    if (available.isEmpty) {
      _showMessage(
        'No active subjects are available for this Section and Semester.',
        isError: true,
      );
      return;
    }

    final availableIds =
        available
            .map(
              (item) =>
                  _readInt(
                item['subject_id'],
              ),
            )
            .whereType<int>()
            .toSet();

    final initialSelection =
        _selectedSubjectIds
            .where(
              availableIds.contains,
            )
            .toSet();

    final result =
        await showDialog<Set<int>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final selected =
            Set<int>.from(
          initialSelection,
        );

        var query = '';

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final normalizedQuery =
                query.trim().toLowerCase();

            final visible =
                available.where(
              (item) {
                if (normalizedQuery.isEmpty) {
                  return true;
                }

                final searchable =
                    '${item['subject_code'] ?? ''} '
                    '${item['subject_name'] ?? ''}'
                        .toLowerCase();

                return searchable.contains(
                  normalizedQuery,
                );
              },
            ).toList();

            final allVisibleSelected =
                visible.isNotEmpty &&
                    visible.every(
                      (item) {
                        final id =
                            _readInt(
                          item['subject_id'],
                        );

                        return id != null &&
                            selected.contains(
                              id,
                            );
                      },
                    );

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select Subjects',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Search by subject code or name',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed:
                              visible.isEmpty
                                  ? null
                                  : () {
                                      setDialogState(
                                        () {
                                          if (allVisibleSelected) {
                                            for (final item
                                                in visible) {
                                              final id =
                                                  _readInt(
                                                item['subject_id'],
                                              );

                                              if (id != null) {
                                                selected.remove(id);
                                              }
                                            }
                                          } else {
                                            for (final item
                                                in visible) {
                                              final id =
                                                  _readInt(
                                                item['subject_id'],
                                              );

                                              if (id != null) {
                                                selected.add(id);
                                              }
                                            }
                                          }
                                        },
                                      );
                                    },
                          icon: Icon(
                            allVisibleSelected
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                          ),
                          label: Text(
                            allVisibleSelected
                                ? 'Deselect visible'
                                : 'Select visible',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${selected.length} selected',
                          style:
                              const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(
                      height: 1,
                    ),
                    Expanded(
                      child:
                          visible.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching subjects.',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      visible.length,
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    final item =
                                        visible[index];

                                    final id =
                                        _readInt(
                                      item['subject_id'],
                                    );

                                    if (id == null) {
                                      return const SizedBox.shrink();
                                    }

                                    final checked =
                                        selected.contains(id);

                                    return CheckboxListTile(
                                      value: checked,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        _value(
                                          item['subject_code'],
                                        ),
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _value(
                                          item['subject_name'],
                                        ),
                                      ),
                                      onChanged:
                                          (value) {
                                        setDialogState(
                                          () {
                                            if (value == true) {
                                              selected.add(id);
                                            } else {
                                              selected.remove(id);
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
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
                    ).pop();
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                TextButton(
                  onPressed:
                      selected.isEmpty
                          ? null
                          : () {
                              setDialogState(
                                () {
                                  selected.clear();
                                },
                              );
                            },
                  child: const Text(
                    'Clear',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop(
                      Set<int>.from(
                        selected,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: Text(
                    'Apply (${selected.length})',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted ||
        result == null) {
      return;
    }

    setState(() {
      _selectedSubjectIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void>
      _addSection() async {
    final semesterId =
        _selectedSemesterId;

    if (semesterId == null) {
      _showMessage(
        'Please select a Semester first.',
        isError: true,
      );
      return;
    }

    int? sourceSectionId =
        _selectedSectionId;

    if (sourceSectionId == null &&
        _filteredSections.length == 1) {
      sourceSectionId =
          _readInt(
        _filteredSections.first['section_id'],
      );
    }

    if (sourceSectionId == null) {
      _showMessage(
        _filteredSections.isEmpty
            ? 'No existing Section is available to copy this academic scope from.'
            : 'Select an existing Section first. The new Section will copy its Program, Branch, Academic Year and Semester.',
        isError: true,
      );
      return;
    }

    final sourceLabel =
        _sectionLabel(
      sourceSectionId,
    );

    final controller =
        TextEditingController();

    final newName =
        await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? error;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Add Section',
              ),
              content:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 460,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'The new section will use the same academic scope as '
                      '$sourceLabel (${_semesterLabel(semesterId)}).',
                      style:
                          const TextStyle(
                        color:
                            AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    TextField(
                      controller:
                          controller,
                      autofocus: true,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration:
                          InputDecoration(
                        labelText:
                            'Section',
                        hintText:
                            'e.g. B',
                        prefixText:
                            'Section ',
                        errorText:
                            error,
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
                    ).pop();
                  },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final value =
                        controller.text.trim();

                    if (value.isEmpty) {
                      setDialogState(
                        () {
                          error =
                              'Enter a section name.';
                        },
                      );
                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(value);
                  },
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add Section',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (!mounted ||
        newName == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response =
          await _adminService
              .createFacultyAssignmentSection(
        sourceSectionId:
            sourceSectionId,
        sectionName:
            newName,
      );

      final newSectionId =
          _readInt(
        response['section_id'],
      );

      final options =
          await _adminService
              .getFacultyAssignmentOptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _semesters =
            _readMapList(
          options['semesters'],
        );
        _sections =
            _readMapList(
          options['sections'],
        );
        _subjects =
            _readMapList(
          options['subjects'],
        );

        if (newSectionId != null) {
          _selectedSectionId =
              newSectionId;
        }

        _selectedSubjectIds.clear();
      });

      _showMessage(
        response['message']
                ?.toString() ??
            'Section added successfully.',
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
          _isSaving = false;
        });
      }
    }
  }


  Future<void> _activate(
    Map<String, dynamic> assignment,
  ) async {
    final assignmentId =
        _readInt(assignment['assignment_id']);

    if (assignmentId == null) {
      _showMessage(
        'Invalid assignment ID.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Activate Assignment'),
        content: Text(
          'Activate this Faculty subject allotment?\n\n'
          '${_value(assignment['faculty_name'])}\n'
          '${_semesterFromAssignment(assignment)} • '
          'Section ${_value(assignment['section_name'])}\n'
          '${_value(assignment['subject_code'])} - '
          '${_value(assignment['subject_name'])}',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: SemanticActionStyles.filled(
              SemanticActionStyles.positive,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.play_circle_rounded),
            label: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final response = await _adminService
          .activateFacultyAssignment(assignmentId);

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ??
            'Faculty assignment activated successfully.',
      );

      await _reloadAssignments();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAssignment(
    Map<String, dynamic> assignment,
  ) async {
    final assignmentId =
        _readInt(assignment['assignment_id']);

    if (assignmentId == null) {
      _showMessage(
        'Invalid assignment ID.',
        isError: true,
      );
      return;
    }

    if (_readBool(assignment['is_active'])) {
      _showMessage(
        'Deactivate this assignment before deleting it permanently.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Assignment Permanently?'),
        content: Text(
          'Delete this unused Faculty subject allotment permanently?\n\n'
          '${_value(assignment['faculty_name'])}\n'
          '${_semesterFromAssignment(assignment)} • '
          'Section ${_value(assignment['section_name'])}\n'
          '${_value(assignment['subject_code'])} - '
          '${_value(assignment['subject_name'])}\n\n'
          'Assignments that have attendance-session history cannot be deleted. '
          'They must remain deactivated to preserve history.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: SemanticActionStyles.filled(
              SemanticActionStyles.destructive,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final response = await _adminService
          .deleteFacultyAssignment(assignmentId);

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ??
            'Faculty assignment deleted permanently.',
      );

      await _reloadAssignments();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
              style: SemanticActionStyles.filled(
                SemanticActionStyles.caution,
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
              'Choose one active Faculty member and academic scope, then select one or more Subjects.',
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
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _dropdown(
                    label: 'Section',
                    value:
                        _selectedSectionId,
                    items:
                        _filteredSections
                            .map(
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
                                setState(
                                  () {
                                    _selectedSectionId =
                                        value;
                                    _selectedSubjectIds
                                        .clear();
                                  },
                                );
                              },
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                SizedBox(
                  height: 48,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _selectedSemesterId ==
                                    null ||
                                _isSaving ||
                                _filteredSections
                                    .isEmpty
                            ? null
                            : _addSection,
                    icon: const Icon(
                      Icons.add_rounded,
                    ),
                    label: const Text(
                      'Add',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            _subjectMultiSelectField(),
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
              'Select multiple Subjects in one popup and assign them together. Use Add beside Section to create another section in the same academic scope.',
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
          _buildAssignmentTree(assignments),
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
                    'Faculty Subject Allotment Tree',
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

  Widget _buildAssignmentTree(
    List<Map<String, dynamic>> assignments,
  ) {
    final facultyGroups =
        <int, List<Map<String, dynamic>>>{};

    for (final item in assignments) {
      final facultyId = _readInt(item['faculty_id']);
      if (facultyId == null) continue;
      facultyGroups.putIfAbsent(
        facultyId,
        () => <Map<String, dynamic>>[],
      ).add(item);
    }

    final facultyIds = facultyGroups.keys.toList()
      ..sort((a, b) {
        final aName = _value(
          facultyGroups[a]!.first['faculty_name'],
        ).toLowerCase();
        final bName = _value(
          facultyGroups[b]!.first['faculty_name'],
        ).toLowerCase();
        return aName.compareTo(bName);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0;
            index < facultyIds.length;
            index++)
          Padding(
            padding: EdgeInsets.only(
              bottom:
                  index == facultyIds.length - 1 ? 0 : 10,
            ),
            child: _buildFacultyTreeNode(
              facultyIds[index],
              facultyGroups[facultyIds[index]]!,
            ),
          ),
      ],
    );
  }

  Widget _buildFacultyTreeNode(
    int facultyId,
    List<Map<String, dynamic>> items,
  ) {
    final first = items.first;
    final facultyName = _value(first['faculty_name']);
    final employeeId = _value(first['employee_id']);
    final activeCount = items
        .where((item) => _readBool(item['is_active']))
        .length;

    final semesterGroups =
        <int, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final semesterId = _readInt(item['semester_id']);
      if (semesterId == null) continue;
      semesterGroups.putIfAbsent(
        semesterId,
        () => <Map<String, dynamic>>[],
      ).add(item);
    }

    final semesterIds = semesterGroups.keys.toList()
      ..sort((a, b) {
        final aNumber = _readInt(
              semesterGroups[a]!.first['semester_number'],
            ) ??
            999;
        final bNumber = _readInt(
              semesterGroups[b]!.first['semester_number'],
            ) ??
            999;
        return aNumber.compareTo(bNumber);
      });

    return Card(
      elevation: 0,
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'faculty-allotment-$facultyId',
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceSoft,
          child: const Icon(
            Icons.co_present_rounded,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          facultyName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Employee ID: $employeeId • '
          '${items.length} allotment(s) • $activeCount active',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        childrenPadding: const EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 12,
        ),
        children: [
          for (final semesterId in semesterIds)
            _buildSemesterTreeNode(
              facultyId,
              semesterId,
              semesterGroups[semesterId]!,
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterTreeNode(
    int facultyId,
    int semesterId,
    List<Map<String, dynamic>> items,
  ) {
    final semesterLabel =
        _semesterFromAssignment(items.first);

    final sectionGroups =
        <int, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final sectionId = _readInt(item['section_id']);
      if (sectionId == null) continue;
      sectionGroups.putIfAbsent(
        sectionId,
        () => <Map<String, dynamic>>[],
      ).add(item);
    }

    final sectionIds = sectionGroups.keys.toList()
      ..sort((a, b) {
        final aName = _value(
          sectionGroups[a]!.first['section_name'],
        ).toLowerCase();
        final bName = _value(
          sectionGroups[b]!.first['section_name'],
        ).toLowerCase();
        return aName.compareTo(bName);
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'faculty-$facultyId-semester-$semesterId',
        ),
        leading: const Icon(
          Icons.calendar_view_month_rounded,
          color: AppColors.primary,
        ),
        title: Text(
          semesterLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${items.length} subject allotment(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          for (final sectionId in sectionIds)
            _buildSectionTreeNode(
              facultyId,
              semesterId,
              sectionId,
              sectionGroups[sectionId]!,
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTreeNode(
    int facultyId,
    int semesterId,
    int sectionId,
    List<Map<String, dynamic>> items,
  ) {
    final sectionName =
        _value(items.first['section_name']);

    items.sort((a, b) {
      final aCode =
          _value(a['subject_code']).toLowerCase();
      final bCode =
          _value(b['subject_code']).toLowerCase();
      return aCode.compareTo(bCode);
    });

    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: ExpansionTile(
          key: PageStorageKey<String>(
            'faculty-$facultyId-semester-$semesterId-section-$sectionId',
          ),
          leading: const Icon(
            Icons.groups_rounded,
            color: AppColors.primary,
          ),
          title: Text(
            'Section $sectionName',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${items.length} subject(s)',
            style: const TextStyle(fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            12,
            0,
            12,
            12,
          ),
          children: [
            for (final item in items)
              _buildAssignmentLeaf(item),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentLeaf(
    Map<String, dynamic> item,
  ) {
    final active = _readBool(item['is_active']);
    final subjectCode = _value(item['subject_code']);
    final subjectName = _value(item['subject_name']);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$subjectCode — $subjectName',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _statusChip(active),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (active)
                OutlinedButton.icon(
                  style: SemanticActionStyles.outlined(
                    SemanticActionStyles.caution,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => _deactivate(item),
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                  ),
                  label: const Text('Deactivate'),
                )
              else
                OutlinedButton.icon(
                  style: SemanticActionStyles.outlined(
                    SemanticActionStyles.positive,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => _activate(item),
                  icon: const Icon(
                    Icons.play_circle_outline_rounded,
                  ),
                  label: const Text('Activate'),
                ),
              OutlinedButton.icon(
                style: SemanticActionStyles.outlined(
                  SemanticActionStyles.destructive,
                ),
                onPressed: _isSaving
                    ? null
                    : () => _deleteAssignment(item),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                ),
                label: const Text('Delete'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 10),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _statusChip(bool active) {
    final color = active
        ? SemanticActionStyles.positive
        : SemanticActionStyles.caution;

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


  Widget _subjectMultiSelectField() {
    final enabled =
        _selectedSemesterId != null &&
            _selectedSectionId != null &&
            !_isSaving;

    final selectedCount =
        _selectedSubjectIds.length;

    return InkWell(
      onTap:
          enabled
              ? _openSubjectMultiSelect
              : null,
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration:
            InputDecoration(
          labelText: 'Subjects',
          enabled: enabled,
          prefixIcon: const Icon(
            Icons.menu_book_rounded,
          ),
          suffixIcon: const Icon(
            Icons.open_in_new_rounded,
          ),
        ),
        child: Text(
          selectedCount == 0
              ? 'Select subjects'
              : selectedCount == 1
                  ? '1 subject selected'
                  : '$selectedCount subjects selected',
          style: TextStyle(
            color: enabled
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight:
                selectedCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
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

    if (number != '-') {
      return 'Semester $number';
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
