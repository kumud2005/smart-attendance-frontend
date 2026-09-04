import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/admin_service.dart';

class AdminSubjectsScreen extends StatefulWidget {
  const AdminSubjectsScreen({
    super.key,
  });

  @override
  State<AdminSubjectsScreen> createState() =>
      _AdminSubjectsScreenState();
}

class _AdminSubjectsScreenState
    extends State<AdminSubjectsScreen> {
  final AdminService _adminService = AdminService();

  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _subjects = [];

  bool _isLoading = true;
  String? _errorMessage;

  int? _programId;
  int? _branchId;
  int? _semesterId;

  String _statusFilter = 'ALL';
  String _searchQuery = '';

  int? _busySubjectId;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _availableBranches {
    if (_programId == null) {
      return _branches;
    }

    return _branches.where((branch) {
      return _asInt(branch['program_id']) == _programId;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    final query = _searchQuery.trim().toLowerCase();

    return _subjects.where((subject) {
      final active = subject['is_active'] == true;

      if (_statusFilter == 'ACTIVE' && !active) {
        return false;
      }

      if (_statusFilter == 'INACTIVE' && active) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        subject['subject_id'],
        subject['subject_code'],
        subject['subject_name'],
        subject['program_code'],
        subject['program_name'],
        subject['branch_code'],
        subject['branch_name'],
        subject['semester_number'],
        subject['semester_name'],
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  Future<void> _loadPage() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final options =
          await _adminService.getSubjectManagementOptions();

      final programs = _mapList(options['programs']);
      final branches = _mapList(options['branches']);
      final semesters = _mapList(options['semesters']);

      int? programId = _programId;
      int? branchId = _branchId;

      if (programId == null && programs.isNotEmpty) {
        programId = _asInt(programs.first['program_id']);
      }

      final availableBranches = branches.where((branch) {
        return programId == null ||
            _asInt(branch['program_id']) == programId;
      }).toList();

      if (branchId == null ||
          !availableBranches.any(
            (branch) => _asInt(branch['branch_id']) == branchId,
          )) {
        branchId = availableBranches.isEmpty
            ? null
            : _asInt(availableBranches.first['branch_id']);
      }

      final subjects = await _adminService.getSubjects(
        programId: programId,
        branchId: branchId,
        semesterId: _semesterId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _programs = programs;
        _branches = branches;
        _semesters = semesters;
        _programId = programId;
        _branchId = branchId;
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _reloadSubjects() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subjects = await _adminService.getSubjects(
        programId: _programId,
        branchId: _branchId,
        semesterId: _semesterId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _changeProgram(int? value) async {
    setState(() {
      _programId = value;
      final branches = _availableBranches;
      _branchId = branches.isEmpty
          ? null
          : _asInt(branches.first['branch_id']);
    });

    await _reloadSubjects();
  }

  Future<void> _openAddSubjectDialog() async {
    if (_programs.isEmpty ||
        _branches.isEmpty ||
        _semesters.isEmpty) {
      _showMessage(
        'Program, branch and semester master data must exist first.',
        error: true,
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddSubjectDialog(
        adminService: _adminService,
        programs: _programs,
        branches: _branches,
        semesters: _semesters,
        initialProgramId: _programId,
        initialBranchId: _branchId,
        initialSemesterId: _semesterId,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _showMessage(
      result['message']?.toString() ??
          'Subject added successfully.',
    );

    setState(() {
      _programId = _asInt(result['program_id']);
      _branchId = _asInt(result['branch_id']);
      _semesterId = _asInt(result['semester_id']);
    });

    await _reloadSubjects();
  }

  Future<void> _changeActiveStatus(
    Map<String, dynamic> subject,
  ) async {
    final subjectId = _asInt(subject['subject_id']);

    if (subjectId <= 0) {
      _showMessage('Invalid subject ID.', error: true);
      return;
    }

    final active = subject['is_active'] == true;

    if (active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Deactivate Subject'),
            content: Text(
              'Deactivate ${_subjectTitle(subject)}?\n\n'
              'The subject will be kept in the database and all existing '
              'academic or attendance history will remain preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                child: const Text('Deactivate'),
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
      _busySubjectId = subjectId;
    });

    try {
      final response = active
          ? await _adminService.deactivateSubject(subjectId)
          : await _adminService.activateSubject(subjectId);

      if (!mounted) {
        return;
      }

      _showMessage(
        response['message']?.toString() ??
            (active
                ? 'Subject deactivated successfully.'
                : 'Subject activated successfully.'),
      );

      await _reloadSubjects();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanError(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busySubjectId = null;
        });
      }
    }
  }

  Future<void> _deleteSubject(
    Map<String, dynamic> subject,
  ) async {
    final subjectId = _asInt(subject['subject_id']);

    if (subjectId <= 0) {
      _showMessage('Invalid subject ID.', error: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permanently Delete Subject'),
          content: Text(
            'Delete ${_subjectTitle(subject)} permanently?\n\n'
            'The server will allow this only when the subject has never '
            'been used in a faculty assignment, faculty request or '
            'attendance session. If it is already referenced, deletion '
            'will be blocked and you should deactivate it instead.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busySubjectId = subjectId;
    });

    try {
      final response =
          await _adminService.deleteSubject(subjectId);

      if (!mounted) {
        return;
      }

      _showMessage(
        response['message']?.toString() ??
            'Subject deleted successfully.',
      );

      await _reloadSubjects();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanError(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busySubjectId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subject Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh subjects',
            onPressed: _isLoading ? null : _loadPage,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            return RefreshIndicator(
              onRefresh: _loadPage,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(compact ? 14 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1350),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(compact: compact),
                        const SizedBox(height: 18),
                        _buildAcademicFilters(compact: compact),
                        const SizedBox(height: 14),
                        _buildSearchFilters(compact: compact),
                        const SizedBox(height: 18),
                        if (_isLoading)
                          const _LoadingCard()
                        else if (_errorMessage != null)
                          _buildErrorCard()
                        else
                          _buildSubjectContent(compact: compact),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    final activeCount = _subjects
        .where((subject) => subject['is_active'] == true)
        .length;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage Subjects',
          style: TextStyle(
            fontSize: compact ? 22 : 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add and manage subjects under Program → Branch → Semester.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (!_isLoading && _errorMessage == null) ...[
          const SizedBox(height: 8),
          Text(
            '${_subjects.length} loaded • $activeCount active',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final button = FilledButton.icon(
      onPressed: _isLoading ? null : _openAddSubjectDialog,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Subject'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          info,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: button),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: info),
        const SizedBox(width: 20),
        button,
      ],
    );
  }

  Widget _buildAcademicFilters({required bool compact}) {
    final program = DropdownButtonFormField<int>(
      key: ValueKey('subject-program-${_programId ?? 0}'),
      initialValue: _programId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Program',
        border: OutlineInputBorder(),
      ),
      items: _programs.map((item) {
        final id = _asInt(item['program_id']);
        return DropdownMenuItem<int>(
          value: id,
          child: Text(
            '${item['program_code'] ?? ''} - ${item['program_name'] ?? ''}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _isLoading ? null : _changeProgram,
    );

    final branch = DropdownButtonFormField<int>(
      key: ValueKey(
        'subject-branch-${_programId ?? 0}-${_branchId ?? 0}',
      ),
      initialValue: _branchId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Branch / Department',
        border: OutlineInputBorder(),
      ),
      items: _availableBranches.map((item) {
        final id = _asInt(item['branch_id']);
        return DropdownMenuItem<int>(
          value: id,
          child: Text(
            '${item['branch_code'] ?? ''} - ${item['branch_name'] ?? ''}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _isLoading
          ? null
          : (value) async {
              setState(() {
                _branchId = value;
              });
              await _reloadSubjects();
            },
    );

    final semester = DropdownButtonFormField<int>(
      key: ValueKey('subject-semester-${_semesterId ?? 0}'),
      initialValue: _semesterId ?? 0,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Semester',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: 0,
          child: Text('All Semesters'),
        ),
        ..._semesters.map((item) {
          final id = _asInt(item['semester_id']);
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              item['semester_name']?.toString() ??
                  'Semester ${item['semester_number'] ?? ''}',
            ),
          );
        }),
      ],
      onChanged: _isLoading
          ? null
          : (value) async {
              setState(() {
                _semesterId = value == null || value == 0 ? null : value;
              });
              await _reloadSubjects();
            },
    );

    if (compact) {
      return Column(
        children: [
          program,
          const SizedBox(height: 12),
          branch,
          const SizedBox(height: 12),
          semester,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: program),
        const SizedBox(width: 12),
        Expanded(child: branch),
        const SizedBox(width: 12),
        Expanded(child: semester),
      ],
    );
  }

  Widget _buildSearchFilters({required bool compact}) {
    final search = TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: const InputDecoration(
        labelText: 'Search subjects',
        hintText: 'Subject code or name',
        prefixIcon: Icon(Icons.search_rounded),
        border: OutlineInputBorder(),
      ),
    );

    final status = DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'ALL', child: Text('All')),
        DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _statusFilter = value;
        });
      },
    );

    if (compact) {
      return Column(
        children: [
          search,
          const SizedBox(height: 12),
          status,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: search),
        const SizedBox(width: 12),
        Expanded(child: status),
      ],
    );
  }

  Widget _buildSubjectContent({required bool compact}) {
    final subjects = _filteredSubjects;

    if (subjects.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 52,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No subjects found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subjects.isEmpty
                      ? 'Add a subject for this academic scope.'
                      : 'No subjects match the current search or status filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (compact) {
      return Column(
        children: [
          for (int index = 0;
              index < subjects.length;
              index++) ...[
            _buildSubjectCard(subjects[index]),
            if (index != subjects.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      );
    }

    return _buildDesktopTable(subjects);
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final subjectId = _asInt(subject['subject_id']);
    final active = subject['is_active'] == true;
    final busy = _busySubjectId == subjectId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject['subject_code']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subject['subject_name']?.toString() ?? '-',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(active),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${subject['program_code'] ?? ''} • '
              '${subject['branch_code'] ?? ''} • '
              '${subject['semester_name'] ?? 'Semester ${subject['semester_number'] ?? ''}'}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Credits: ${_credits(subject['credits'])} • Subject ID: $subjectId',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy
                        ? null
                        : () => _changeActiveStatus(subject),
                    icon: busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            active
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                          ),
                    label: Text(active ? 'Deactivate' : 'Activate'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Delete subject',
                  onPressed: busy ? null : () => _deleteSubject(subject),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> subjects) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Semester')),
            DataColumn(label: Text('Credits')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: subjects.map((subject) {
            final subjectId = _asInt(subject['subject_id']);
            final active = subject['is_active'] == true;
            final busy = _busySubjectId == subjectId;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    subject['subject_code']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 360,
                    child: Text(
                      subject['subject_name']?.toString() ?? '-',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    subject['semester_name']?.toString() ??
                        'Semester ${subject['semester_number'] ?? ''}',
                  ),
                ),
                DataCell(Text(_credits(subject['credits']))),
                DataCell(_buildStatusChip(active)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => _changeActiveStatus(subject),
                        icon: Icon(
                          active
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(active ? 'Deactivate' : 'Activate'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Delete permanently',
                        onPressed: busy
                            ? null
                            : () => _deleteSubject(subject),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (active ? AppColors.success : AppColors.textSecondary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: active ? AppColors.success : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load subjects.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _subjectTitle(Map<String, dynamic> subject) {
    final code = subject['subject_code']?.toString().trim() ?? '';
    final name = subject['subject_name']?.toString().trim() ?? '';

    if (code.isNotEmpty && name.isNotEmpty) {
      return '$code - $name';
    }

    return code.isNotEmpty ? code : name;
  }

  String _credits(dynamic value) {
    if (value == null) {
      return '-';
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) {
      return value.toString();
    }

    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }

    return parsed.toStringAsFixed(1);
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
        ),
      );
  }
}

class _AddSubjectDialog extends StatefulWidget {
  const _AddSubjectDialog({
    required this.adminService,
    required this.programs,
    required this.branches,
    required this.semesters,
    required this.initialProgramId,
    required this.initialBranchId,
    required this.initialSemesterId,
  });

  final AdminService adminService;
  final List<Map<String, dynamic>> programs;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> semesters;
  final int? initialProgramId;
  final int? initialBranchId;
  final int? initialSemesterId;

  @override
  State<_AddSubjectDialog> createState() =>
      _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<_AddSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController();

  int? _programId;
  int? _branchId;
  int? _semesterId;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _programId = widget.initialProgramId ??
        (widget.programs.isEmpty
            ? null
            : _asInt(widget.programs.first['program_id']));

    final branches = _availableBranches;
    final requestedBranch = widget.initialBranchId;

    _branchId = requestedBranch != null &&
            branches.any(
              (branch) =>
                  _asInt(branch['branch_id']) == requestedBranch,
            )
        ? requestedBranch
        : (branches.isEmpty
            ? null
            : _asInt(branches.first['branch_id']));

    _semesterId = widget.initialSemesterId ??
        (widget.semesters.isEmpty
            ? null
            : _asInt(widget.semesters.first['semester_id']));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _availableBranches {
    return widget.branches.where((branch) {
      return _programId == null ||
          _asInt(branch['program_id']) == _programId;
    }).toList();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    if (_programId == null ||
        _branchId == null ||
        _semesterId == null) {
      setState(() {
        _errorMessage = 'Select program, branch and semester.';
      });
      return;
    }

    final creditsText = _creditsController.text.trim();
    final credits = creditsText.isEmpty
        ? null
        : double.tryParse(creditsText);

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.adminService.createSubject(
        programId: _programId!,
        branchId: _branchId!,
        semesterId: _semesterId!,
        subjectCode: _codeController.text,
        subjectName: _nameController.text,
        credits: credits,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(response);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage =
            error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Subject'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _programId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Program',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.programs.map((item) {
                    final id = _asInt(item['program_id']);
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        '${item['program_code'] ?? ''} - ${item['program_name'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _programId = value;
                            final branches = _availableBranches;
                            _branchId = branches.isEmpty
                                ? null
                                : _asInt(
                                    branches.first['branch_id'],
                                  );
                          });
                        },
                  validator: (value) =>
                      value == null ? 'Select a program.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    'add-subject-branch-${_programId ?? 0}-${_branchId ?? 0}',
                  ),
                  initialValue: _branchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Branch / Department',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableBranches.map((item) {
                    final id = _asInt(item['branch_id']);
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        '${item['branch_code'] ?? ''} - ${item['branch_name'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _branchId = value;
                          });
                        },
                  validator: (value) =>
                      value == null ? 'Select a branch.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _semesterId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.semesters.map((item) {
                    final id = _asInt(item['semester_id']);
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        item['semester_name']?.toString() ??
                            'Semester ${item['semester_number'] ?? ''}',
                      ),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _semesterId = value;
                          });
                        },
                  validator: (value) =>
                      value == null ? 'Select a semester.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Subject Code',
                    hintText: 'e.g. 23BTCSL401',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 30,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter subject code.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 150,
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Enter subject name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _creditsController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Credits (optional)',
                    hintText: 'e.g. 3 or 1.0',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return null;
                    }
                    final credits = double.tryParse(text);
                    if (credits == null || credits < 0 || credits > 30) {
                      return 'Enter credits between 0 and 30.';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: Text(_saving ? 'Adding...' : 'Add Subject'),
        ),
      ],
    );
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(34),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
