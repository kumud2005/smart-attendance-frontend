import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_action_styles.dart';
import '../../services/admin_service.dart';

class AdminSubjectsScreen extends StatefulWidget {
  const AdminSubjectsScreen({super.key});

  @override
  State<AdminSubjectsScreen> createState() =>
      _AdminSubjectsScreenState();
}

class _AdminSubjectsScreenState extends State<AdminSubjectsScreen> {
  final AdminService _adminService = AdminService();
  final PublicFileSaver _fileSaver = PublicFileSaver();

  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _subjects = [];

  bool _isLoading = true;
  bool _isImporting = false;
  bool _isExporting = false;
  String? _errorMessage;

  // null means ALL for all three academic filters.
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

  // ============================================================
  // LOCAL ACADEMIC FILTERS
  // ============================================================

  List<Map<String, dynamic>> get _availableBranches {
    if (_programId == null) return _branches;

    return _branches.where((branch) {
      return _asInt(branch['program_id']) == _programId;
    }).toList();
  }

  List<Map<String, dynamic>> get _availableSemesters {
    List<Map<String, dynamic>> branchesInScope;

    if (_branchId != null) {
      branchesInScope = _branches.where((item) {
        return _asInt(item['branch_id']) == _branchId;
      }).toList();
    } else if (_programId != null) {
      branchesInScope = _branches.where((item) {
        return _asInt(item['program_id']) == _programId;
      }).toList();
    } else {
      branchesInScope = _branches;
    }

    if (branchesInScope.isEmpty) return _semesters;

    var maxSemester = 0;
    for (final branch in branchesInScope) {
      final count = _asInt(branch['total_semesters']);
      if (count > maxSemester) maxSemester = count;
    }

    if (maxSemester <= 0) return _semesters;

    return _semesters.where((semester) {
      final number = _asInt(semester['semester_number']);
      return number > 0 && number <= maxSemester;
    }).toList();
  }

  bool _matchesAcademicScope(
    Map<String, dynamic> subject, {
    bool includeSemester = true,
  }) {
    if (_programId != null &&
        _asInt(subject['program_id']) != _programId) {
      return false;
    }

    if (_branchId != null &&
        _asInt(subject['branch_id']) != _branchId) {
      return false;
    }

    if (includeSemester &&
        _semesterId != null &&
        _asInt(subject['semester_id']) != _semesterId) {
      return false;
    }

    return true;
  }

  bool _matchesStatus(Map<String, dynamic> subject) {
    final active = subject['is_active'] == true;
    if (_statusFilter == 'ACTIVE') return active;
    if (_statusFilter == 'INACTIVE') return !active;
    return true;
  }

  List<Map<String, dynamic>> get _scopeSubjects {
    return _subjects.where((subject) {
      return _matchesAcademicScope(subject) &&
          _matchesStatus(subject);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    final query = _searchQuery.trim().toLowerCase();

    return _scopeSubjects.where((subject) {
      if (query.isEmpty) return true;

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
        subject['credits'],
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _programSummarySubjects() {
    return _subjects.where((subject) {
      if (!_matchesStatus(subject)) return false;
      return _programId == null ||
          _asInt(subject['program_id']) == _programId;
    }).toList();
  }

  List<Map<String, dynamic>> _branchSummarySubjects() {
    return _subjects.where((subject) {
      if (!_matchesStatus(subject)) return false;
      if (_programId != null &&
          _asInt(subject['program_id']) != _programId) {
        return false;
      }
      return _branchId == null ||
          _asInt(subject['branch_id']) == _branchId;
    }).toList();
  }

  List<Map<String, dynamic>> _semesterSummarySubjects() {
    return _subjects.where((subject) {
      return _matchesAcademicScope(subject) &&
          _matchesStatus(subject);
    }).toList();
  }

  String _summaryText(List<Map<String, dynamic>> items) {
    final credits = items.fold<double>(
      0,
      (sum, item) => sum + _creditValue(item['credits']),
    );
    return '${items.length} subject${items.length == 1 ? '' : 's'} • ${_formatCreditNumber(credits)} credits';
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadPage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final options =
          await _adminService.getSubjectManagementOptions();
      final subjects = await _adminService.getSubjects();

      if (!mounted) return;

      setState(() {
        _programs = _mapList(options['programs']);
        _branches = _mapList(options['branches']);
        _semesters = _mapList(options['semesters']);
        _subjects = subjects;

        // Drop selections that no longer exist.
        if (_programId != null &&
            !_programs.any(
              (item) => _asInt(item['program_id']) == _programId,
            )) {
          _programId = null;
        }
        if (_branchId != null &&
            !_branches.any(
              (item) => _asInt(item['branch_id']) == _branchId,
            )) {
          _branchId = null;
        }
        if (_semesterId != null &&
            !_semesters.any(
              (item) => _asInt(item['semester_id']) == _semesterId,
            )) {
          _semesterId = null;
        }

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _reloadSubjects() async {
    try {
      final subjects = await _adminService.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error), error: true);
    }
  }

  // ============================================================
  // FILTER CHANGES
  // ============================================================

  void _changeProgram(int? value) {
    setState(() {
      _programId = value == null || value == 0 ? null : value;
      _branchId = null;
      _semesterId = null;
    });
  }

  void _changeBranch(int? value) {
    setState(() {
      _branchId = value == null || value == 0 ? null : value;
      _semesterId = null;
    });
  }

  void _changeSemester(int? value) {
    setState(() {
      _semesterId = value == null || value == 0 ? null : value;
    });
  }

  // ============================================================
  // ADD ONE SUBJECT
  // ============================================================

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

    if (!mounted || result == null) return;

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

  // ============================================================
  // FILE IMPORT
  // ============================================================

  Future<void> _pickAndImportSubjectFile() async {
    if (_isImporting || _isLoading) return;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'pdf'],
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      _showMessage(
        'Unable to read the selected file.',
        error: true,
      );
      return;
    }

    if (bytes.length > 10 * 1024 * 1024) {
      _showMessage(
        'File must be 10 MB or smaller.',
        error: true,
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final preview = await _adminService.previewSubjectImport(
        fileName: file.name,
        bytes: bytes,
      );

      if (!mounted) return;

      final confirmed = await _showImportPreview(preview);
      if (confirmed != true || !mounted) return;

      final response = await _adminService.importSubjectCatalog(
        fileName: file.name,
        bytes: bytes,
      );

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ??
            'Subject catalog imported successfully.',
      );

      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<bool?> _showImportPreview(
    Map<String, dynamic> preview,
  ) {
    final errors = _mapList(preview['errors']);
    final previewRows = _mapList(preview['preview_rows']);
    final errorCount = _asInt(preview['error_count']);
    final ready = _asInt(preview['ready_to_import']);
    final skipped = _asInt(preview['skipped_existing']);
    final totalRows = _asInt(preview['total_rows']);
    final credits = _creditValue(preview['total_credits_to_import']);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('Subject Import Preview')),
            ],
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    preview['file_name']?.toString() ?? 'Selected file',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _previewChip('Rows', totalRows.toString()),
                      _previewChip('New', ready.toString()),
                      _previewChip('Skipped', skipped.toString()),
                      _previewChip(
                        'New Credits',
                        _formatCreditNumber(credits),
                      ),
                      _previewChip(
                        'Errors',
                        errorCount.toString(),
                        error: errorCount > 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    preview['message']?.toString() ?? '',
                    style: TextStyle(
                      color: errorCount > 0
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Validation errors',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...errors.take(10).map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Row ${item['row_number'] ?? '-'}: '
                          '${item['message'] ?? 'Invalid row'}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }),
                    if (errors.length > 10)
                      Text(
                        '+ ${errors.length - 10} more error(s)',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                  if (previewRows.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'First rows',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Row')),
                          DataColumn(label: Text('Program')),
                          DataColumn(label: Text('Branch')),
                          DataColumn(label: Text('Sem')),
                          DataColumn(label: Text('Code')),
                          DataColumn(label: Text('Subject')),
                          DataColumn(label: Text('Cr')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: previewRows.take(12).map((row) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${row['row_number'] ?? '-'}')),
                              DataCell(Text('${row['program'] ?? '-'}')),
                              DataCell(Text('${row['branch'] ?? '-'}')),
                              DataCell(Text('${row['semester_number'] ?? '-'}')),
                              DataCell(Text('${row['subject_code'] ?? '-'}')),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    '${row['subject_name'] ?? '-'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(_credits(row['credits']))),
                              DataCell(Text('${row['action'] ?? '-'}')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Accepted columns: Program, Branch, Semester, Subject Code, '
                    'Subject Name, Credits. Program and Branch may contain an '
                    'existing code or exact name. PDF must contain a text-based table.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(errorCount > 0 ? 'Close' : 'Cancel'),
            ),
            if (errorCount == 0 && ready > 0)
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.upload_rounded),
                label: Text('Import $ready Subject${ready == 1 ? '' : 's'}'),
              ),
          ],
        );
      },
    );
  }

  Widget _previewChip(
    String label,
    String value, {
    bool error = false,
  }) {
    final color = error ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // SUBJECT ACTIONS
  // ============================================================


  Future<void> _openEditSubjectDialog(
    Map<String, dynamic> subject,
  ) async {
    final subjectId = _asInt(subject['subject_id']);

    if (subjectId <= 0) {
      _showMessage(
        'Invalid subject ID.',
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
        initialProgramId: _asInt(subject['program_id']),
        initialBranchId: _asInt(subject['branch_id']),
        initialSemesterId: _asInt(subject['semester_id']),
        initialSubject: subject,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _showMessage(
      result['message']?.toString() ??
          'Subject updated successfully.',
    );

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
        builder: (dialogContext) => AlertDialog(
          title: const Text('Deactivate Subject'),
          content: Text(
            'Deactivate ${_subjectTitle(subject)}?\n\n'
            'Academic and attendance history will remain preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: SemanticActionStyles.filled(
                SemanticActionStyles.caution,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _busySubjectId = subjectId);

    try {
      final response = active
          ? await _adminService.deactivateSubject(subjectId)
          : await _adminService.activateSubject(subjectId);
      if (!mounted) return;
      _showMessage(
        response['message']?.toString() ??
            (active
                ? 'Subject deactivated successfully.'
                : 'Subject activated successfully.'),
      );
      await _reloadSubjects();
    } catch (error) {
      if (mounted) _showMessage(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _busySubjectId = null);
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently Delete Subject'),
        content: Text(
          'Delete ${_subjectTitle(subject)} permanently?\n\n'
          'The server will block deletion if the subject is referenced by '
          'faculty assignments, registration requests or attendance history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: SemanticActionStyles.filled(
              SemanticActionStyles.destructive,
            ),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busySubjectId = subjectId);

    try {
      final response = await _adminService.deleteSubject(subjectId);
      if (!mounted) return;
      _showMessage(
        response['message']?.toString() ??
            'Subject deleted successfully.',
      );
      await _reloadSubjects();
    } catch (error) {
      if (mounted) _showMessage(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _busySubjectId = null);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subject Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh subjects',
            onPressed: _isLoading || _isImporting ? null : _loadPage,
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


  Future<void> _exportSubjects(String format) async {
    if (_isExporting) return;

    if (_filteredSubjects.isEmpty) {
      _showMessage(
        'There are no subjects in the current filtered view to export.',
        error: true,
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      late final Uint8List bytes;
      late final String extension;
      late final String mimeType;

      switch (format) {
        case 'csv':
          bytes = await _adminService.downloadSubjectsCsv(
            programId: _programId,
            branchId: _branchId,
            semesterId: _semesterId,
            statusFilter: _statusFilter,
            search: _searchQuery,
          );
          extension = 'csv';
          mimeType = 'text/csv';
          break;

        case 'pdf':
          bytes = await _adminService.downloadSubjectsPdf(
            programId: _programId,
            branchId: _branchId,
            semesterId: _semesterId,
            statusFilter: _statusFilter,
            search: _searchQuery,
          );
          extension = 'pdf';
          mimeType = 'application/pdf';
          break;

        case 'excel':
        default:
          bytes = await _adminService.downloadSubjectsExcel(
            programId: _programId,
            branchId: _branchId,
            semesterId: _semesterId,
            statusFilter: _statusFilter,
            search: _searchQuery,
          );
          extension = 'xlsx';
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
      }

      final result = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: _subjectExportFileName(extension),
        mimeType: mimeType,
      );

      if (!mounted) return;

      // On Flutter Web, public_file_saver can trigger the browser
      // download successfully while still returning a null/non-success
      // result. The browser owns the actual save/download action there,
      // so absence of a thrown exception is the reliable signal.
      //
      // On native platforms, keep validating the saver result normally.
      if (!kIsWeb &&
          (result == null || !result.isSuccess)) {
        throw Exception(
          'The subject export could not be saved.',
        );
      }

      _showMessage(
        kIsWeb
            ? 'Subject ${extension.toUpperCase()} download started successfully.'
            : 'Subject ${extension.toUpperCase()} export saved successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _subjectExportFileName(String extension) {
    final now = DateTime.now();

    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    return 'subject_catalog_$stamp.$extension';
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
          'Add subjects manually or import a CSV, Excel (.xlsx) or text-table PDF.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (!_isLoading && _errorMessage == null) ...[
          const SizedBox(height: 8),
          Text(
            '${_subjects.length} total • $activeCount active',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final canExport = !_isLoading &&
        !_isImporting &&
        !_isExporting &&
        _filteredSubjects.isNotEmpty;

    final exportButton = PopupMenuButton<String>(
      enabled: canExport,
      tooltip: canExport
          ? 'Export subjects'
          : 'No subjects available to export',
      onSelected: _exportSubjects,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'excel',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.table_view_rounded),
            title: Text('Export Excel (.xlsx)'),
          ),
        ),
        PopupMenuItem(
          value: 'csv',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.data_object_rounded),
            title: Text('Export CSV (.csv)'),
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Export PDF (.pdf)'),
          ),
        ),
      ],
      child: Opacity(
        opacity: canExport ? 1 : 0.45,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isExporting)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.download_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                _isExporting ? 'Exporting...' : 'Export',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_isExporting) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final importButton = OutlinedButton.icon(
      onPressed: _isLoading || _isImporting
          ? null
          : _pickAndImportSubjectFile,
      icon: _isImporting
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file_rounded),
      label: Text(_isImporting ? 'Checking File...' : 'Import File'),
    );

    final addButton = FilledButton.icon(
      onPressed: _isLoading || _isImporting
          ? null
          : _openAddSubjectDialog,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Subject'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          info,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: exportButton),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: importButton),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: addButton),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: info),
        const SizedBox(width: 20),
        exportButton,
        const SizedBox(width: 10),
        importButton,
        const SizedBox(width: 10),
        addButton,
      ],
    );
  }

  Widget _buildAcademicFilters({required bool compact}) {
    final programSummary = _summaryText(_programSummarySubjects());
    final branchSummary = _summaryText(_branchSummarySubjects());
    final semesterSummary = _summaryText(_semesterSummarySubjects());

    final program = DropdownButtonFormField<int>(
      key: ValueKey('subject-program-${_programId ?? 0}'),
      initialValue: _programId ?? 0,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Program',
        helperText: programSummary,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: 0,
          child: Text('All Programs'),
        ),
        ..._programs.map((item) {
          final id = _asInt(item['program_id']);
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              '${item['program_code'] ?? ''} - ${item['program_name'] ?? ''}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: _isLoading ? null : _changeProgram,
    );

    final branch = DropdownButtonFormField<int>(
      key: ValueKey('subject-branch-${_programId ?? 0}-${_branchId ?? 0}'),
      initialValue: _branchId ?? 0,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Branch / Course',
        helperText: branchSummary,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: 0,
          child: Text('All Branches / Courses'),
        ),
        ..._availableBranches.map((item) {
          final id = _asInt(item['branch_id']);
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              '${item['branch_code'] ?? ''} - ${item['branch_name'] ?? ''}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: _isLoading ? null : _changeBranch,
    );

    final semester = DropdownButtonFormField<int>(
      key: ValueKey('subject-semester-${_semesterId ?? 0}'),
      initialValue: _semesterId ?? 0,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Semester',
        helperText: semesterSummary,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: 0,
          child: Text('All Semesters — Tree View'),
        ),
        ..._availableSemesters.map((item) {
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
      onChanged: _isLoading ? null : _changeSemester,
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: const InputDecoration(
        labelText: 'Search subjects',
        hintText: 'Program, branch, semester, code or name',
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
        if (value != null) setState(() => _statusFilter = value);
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
                      ? 'Add subjects manually or use Import File.'
                      : 'No subjects match the selected academic scope, search or status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // User requested hierarchy/tree whenever All Semesters is selected.
    if (_semesterId == null) {
      return _buildTreeView(subjects);
    }

    if (compact) {
      return Column(
        children: [
          for (int index = 0; index < subjects.length; index++) ...[
            _buildSubjectCard(subjects[index]),
            if (index != subjects.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      );
    }

    return _buildDesktopTable(subjects);
  }

  // ============================================================
  // TREE VIEW: PROGRAM -> BRANCH -> SEMESTER -> SUBJECT
  // ============================================================

  Widget _buildTreeView(List<Map<String, dynamic>> subjects) {
    final byProgram = <int, List<Map<String, dynamic>>>{};
    for (final subject in subjects) {
      final id = _asInt(subject['program_id']);
      byProgram.putIfAbsent(id, () => []).add(subject);
    }

    final programIds = byProgram.keys.toList()
      ..sort((a, b) => _programLabel(a).compareTo(_programLabel(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.account_tree_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Academic Subject Tree',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              _summaryText(subjects),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final programId in programIds)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildProgramTreeNode(
              programId,
              byProgram[programId]!,
            ),
          ),
      ],
    );
  }

  Widget _buildProgramTreeNode(
    int programId,
    List<Map<String, dynamic>> subjects,
  ) {
    final byBranch = <int, List<Map<String, dynamic>>>{};
    for (final subject in subjects) {
      final id = _asInt(subject['branch_id']);
      byBranch.putIfAbsent(id, () => []).add(subject);
    }

    final branchIds = byBranch.keys.toList()
      ..sort((a, b) => _branchLabel(a).compareTo(_branchLabel(b)));

    return Card(
      elevation: 0,
      child: ExpansionTile(
        initiallyExpanded: _programId != null,
        leading: const Icon(Icons.school_rounded, color: AppColors.primary),
        title: Text(
          _programLabel(programId),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_summaryText(subjects)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          for (final branchId in branchIds)
            _buildBranchTreeNode(
              branchId,
              byBranch[branchId]!,
            ),
        ],
      ),
    );
  }

  Widget _buildBranchTreeNode(
    int branchId,
    List<Map<String, dynamic>> subjects,
  ) {
    final bySemester = <int, List<Map<String, dynamic>>>{};
    for (final subject in subjects) {
      final number = _asInt(subject['semester_number']);
      bySemester.putIfAbsent(number, () => []).add(subject);
    }

    final semesterNumbers = bySemester.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: _branchId != null,
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(
          _branchLabel(branchId),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_summaryText(subjects)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final semesterNumber in semesterNumbers)
            _buildSemesterTreeNode(
              semesterNumber,
              bySemester[semesterNumber]!,
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterTreeNode(
    int semesterNumber,
    List<Map<String, dynamic>> subjects,
  ) {
    final sorted = [...subjects]
      ..sort((a, b) =>
          '${a['subject_code']}'.compareTo('${b['subject_code']}'));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.layers_outlined, size: 21),
        title: Text(
          'Semester $semesterNumber',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_summaryText(subjects)),
        children: [
          for (final subject in sorted)
            ListTile(
              dense: true,
              title: Text(
                '${subject['subject_code'] ?? '-'} — ${subject['subject_name'] ?? '-'}',
              ),
              subtitle: Text(
                subject['is_active'] == true ? 'Active' : 'Inactive',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_credits(subject['credits'])} cr',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Subject actions',
                    enabled:
                        _busySubjectId != _asInt(subject['subject_id']),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openEditSubjectDialog(subject);
                      } else if (value == 'toggle') {
                        _changeActiveStatus(subject);
                      } else if (value == 'delete') {
                        _deleteSubject(subject);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.edit_outlined,
                            color: SemanticActionStyles.primary,
                          ),
                          title: Text(
                            'Edit',
                            style: TextStyle(
                              color: SemanticActionStyles.primary,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            subject['is_active'] == true
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            color: subject['is_active'] == true
                                ? SemanticActionStyles.caution
                                : SemanticActionStyles.positive,
                          ),
                          title: Text(
                            subject['is_active'] == true
                                ? 'Deactivate'
                                : 'Activate',
                            style: TextStyle(
                              color: subject['is_active'] == true
                                  ? SemanticActionStyles.caution
                                  : SemanticActionStyles.positive,
                            ),
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: SemanticActionStyles.destructive,
                          ),
                          title: Text(
                            'Delete permanently',
                            style: TextStyle(
                              color: SemanticActionStyles.destructive,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () => _openEditSubjectDialog(subject),
            ),
        ],
      ),
    );
  }

  String _programLabel(int programId) {
    final item = _programs.firstWhere(
      (e) => _asInt(e['program_id']) == programId,
      orElse: () => <String, dynamic>{},
    );
    final code = item['program_code']?.toString() ?? '';
    final name = item['program_name']?.toString() ?? '';
    if (code.isEmpty) return name.isEmpty ? 'Program $programId' : name;
    return name.isEmpty ? code : '$code — $name';
  }

  String _branchLabel(int branchId) {
    final item = _branches.firstWhere(
      (e) => _asInt(e['branch_id']) == branchId,
      orElse: () => <String, dynamic>{},
    );
    final code = item['branch_code']?.toString() ?? '';
    final name = item['branch_name']?.toString() ?? '';
    if (code.isEmpty) return name.isEmpty ? 'Branch $branchId' : name;
    return name.isEmpty ? code : '$code — $name';
  }

  // ============================================================
  // FLAT SUBJECT VIEWS
  // ============================================================

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
                    style: SemanticActionStyles.tonal(
                      active
                          ? SemanticActionStyles.caution
                          : SemanticActionStyles.positive,
                    ),
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
                  tooltip: 'Edit subject',
                  onPressed:
                      busy ? null : () => _openEditSubjectDialog(subject),
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  style: SemanticActionStyles.icon(
                    SemanticActionStyles.destructive,
                  ),
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
            DataColumn(label: Text('Program')),
            DataColumn(label: Text('Branch')),
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

            return DataRow(cells: [
              DataCell(Text('${subject['program_code'] ?? '-'}')),
              DataCell(Text('${subject['branch_code'] ?? '-'}')),
              DataCell(
                Text(
                  subject['subject_code']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 330,
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
                      tooltip: 'Edit subject',
                      onPressed: busy
                          ? null
                          : () => _openEditSubjectDialog(subject),
                      icon: const Icon(Icons.edit_outlined),
                    ),
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
            ]);
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

  // ============================================================
  // HELPERS
  // ============================================================

  String _subjectTitle(Map<String, dynamic> subject) {
    final code = subject['subject_code']?.toString().trim() ?? '';
    final name = subject['subject_name']?.toString().trim() ?? '';
    if (code.isNotEmpty && name.isNotEmpty) return '$code - $name';
    return code.isNotEmpty ? code : name;
  }

  double _creditValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCreditNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  String _credits(dynamic value) {
    if (value == null) return '-';
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return _formatCreditNumber(parsed);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
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
    this.initialSubject,
  });

  final AdminService adminService;
  final List<Map<String, dynamic>> programs;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> semesters;
  final int? initialProgramId;
  final int? initialBranchId;
  final int? initialSemesterId;
  final Map<String, dynamic>? initialSubject;

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

    final subject = widget.initialSubject;

    if (subject != null) {
      _codeController.text =
          subject['subject_code']?.toString() ?? '';
      _nameController.text =
          subject['subject_name']?.toString() ?? '';

      final credits = subject['credits'];
      if (credits != null) {
        final parsed = double.tryParse(credits.toString());
        _creditsController.text = parsed == null
            ? credits.toString()
            : (parsed == parsed.roundToDouble()
                ? parsed.toInt().toString()
                : parsed.toString());
      }
    }

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

    final requestedSemester = widget.initialSemesterId;
    final allowedSemesters = _availableSemesters;

    _semesterId = requestedSemester != null &&
            allowedSemesters.any(
              (semester) =>
                  _asInt(semester['semester_id']) ==
                  requestedSemester,
            )
        ? requestedSemester
        : (allowedSemesters.isEmpty
            ? null
            : _asInt(allowedSemesters.first['semester_id']));
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

  List<Map<String, dynamic>> get _availableSemesters {
    if (_branchId == null) {
      return [];
    }

    final branch = widget.branches.firstWhere(
      (item) => _asInt(item['branch_id']) == _branchId,
      orElse: () => <String, dynamic>{},
    );

    final totalSemesters =
        _asInt(branch['total_semesters']);

    return widget.semesters.where((semester) {
      final number =
          _asInt(semester['semester_number']);

      return number > 0 &&
          (totalSemesters <= 0 ||
              number <= totalSemesters);
    }).toList();
  }

  void _selectFirstAllowedSemester() {
    final semesters = _availableSemesters;

    _semesterId = semesters.isEmpty
        ? null
        : _asInt(semesters.first['semester_id']);
  }

  bool get _isEditing => widget.initialSubject != null;

  int get _editingSubjectId =>
      _asInt(widget.initialSubject?['subject_id']);

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
      final response = _isEditing
          ? await widget.adminService.updateSubject(
              subjectId: _editingSubjectId,
              programId: _programId!,
              branchId: _branchId!,
              semesterId: _semesterId!,
              subjectCode: _codeController.text,
              subjectName: _nameController.text,
              credits: credits,
            )
          : await widget.adminService.createSubject(
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
      title: Text(_isEditing ? 'Edit Subject' : 'Add Subject'),
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
                            _selectFirstAllowedSemester();
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
                            _selectFirstAllowedSemester();
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
                  items: _availableSemesters.map((item) {
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
                if (_isEditing) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Note: Code, name and credits can be corrected even '
                      'after use. Program, branch or semester can be moved '
                      'only while the subject has no assignment or attendance '
                      'history.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
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
              : Icon(
                  _isEditing
                      ? Icons.save_outlined
                      : Icons.add_rounded,
                ),
          label: Text(
            _saving
                ? (_isEditing ? 'Saving...' : 'Adding...')
                : (_isEditing ? 'Save Changes' : 'Add Subject'),
          ),
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
