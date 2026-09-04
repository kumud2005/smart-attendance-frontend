import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/admin_service.dart';

class AdminAcademicStructureScreen extends StatefulWidget {
  const AdminAcademicStructureScreen({super.key});

  @override
  State<AdminAcademicStructureScreen> createState() =>
      _AdminAcademicStructureScreenState();
}

class _AdminAcademicStructureScreenState
    extends State<AdminAcademicStructureScreen> {
  final AdminService _adminService = AdminService();

  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _branches = [];

  bool _loading = true;
  String? _errorMessage;
  String _programStatus = 'ALL';
  String _branchStatus = 'ALL';
  String _programSearch = '';
  String _branchSearch = '';
  int? _branchProgramId;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPrograms {
    final query = _programSearch.trim().toLowerCase();
    return _programs.where((item) {
      final active = item['is_active'] == true;
      if (_programStatus == 'ACTIVE' && !active) return false;
      if (_programStatus == 'INACTIVE' && active) return false;
      if (query.isEmpty) return true;
      return [
        item['program_id'],
        item['program_code'],
        item['program_name'],
        item['description'],
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredBranches {
    final query = _branchSearch.trim().toLowerCase();
    return _branches.where((item) {
      final active = item['is_active'] == true;
      if (_branchStatus == 'ACTIVE' && !active) return false;
      if (_branchStatus == 'INACTIVE' && active) return false;
      if (_branchProgramId != null &&
          _asInt(item['program_id']) != _branchProgramId) {
        return false;
      }
      if (query.isEmpty) return true;
      return [
        item['branch_id'],
        item['branch_code'],
        item['branch_name'],
        item['program_code'],
        item['program_name'],
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _activePrograms =>
      _programs.where((item) => item['is_active'] == true).toList();

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final programs = await _adminService.getPrograms();
      final branches = await _adminService.getBranches();
      if (!mounted) return;
      setState(() {
        _programs = programs;
        _branches = branches;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _openAddProgramDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Program'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Program Code',
                          hintText: 'Example: BTECH, MTECH, MCA',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Program code is required.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Program Name',
                          hintText: 'Example: Master of Technology',
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? 'Program name is required.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final result = await _adminService.createProgram(
                              programCode: codeController.text,
                              programName: nameController.text,
                              description: descriptionController.text,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                            _showMessage(
                              result['message']?.toString() ??
                                  'Program added successfully.',
                            );
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(_cleanError(error))),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Add Program'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _openAddBranchDialog() async {
    if (_activePrograms.isEmpty) {
      _showMessage('Create or activate a program first.', error: true);
      return;
    }

    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int selectedProgramId =
        _asInt(_activePrograms.first['program_id']) ?? 0;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Course / Branch'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey('program-$selectedProgramId'),
                        initialValue: selectedProgramId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Program',
                        ),
                        items: _activePrograms.map((program) {
                          final id = _asInt(program['program_id']) ?? 0;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              '${program['program_code']} — ${program['program_name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => selectedProgramId = value,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Course / Branch Code',
                          hintText: 'Example: CSE, IT, AIML',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Course / branch code is required.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Course / Branch Name',
                          hintText: 'Example: Artificial Intelligence and ML',
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? 'Course / branch name is required.'
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final result = await _adminService.createBranch(
                              programId: selectedProgramId,
                              branchCode: codeController.text,
                              branchName: nameController.text,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                            _showMessage(
                              result['message']?.toString() ??
                                  'Course / branch added successfully.',
                            );
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(_cleanError(error))),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Add Course / Branch'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _toggleProgram(Map<String, dynamic> item) async {
    final id = _asInt(item['program_id']);
    if (id == null) return;
    final active = item['is_active'] == true;
    await _runAction(
      'program-$id',
      () => active
          ? _adminService.deactivateProgram(id)
          : _adminService.activateProgram(id),
    );
  }

  Future<void> _deleteProgram(Map<String, dynamic> item) async {
    final id = _asInt(item['program_id']);
    if (id == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Program?',
      message:
          'Permanently delete ${item['program_code']} — ${item['program_name']}?\n\nDeletion is allowed only when it has no linked courses/branches or subjects.',
    );
    if (!confirmed) return;
    await _runAction(
      'program-$id',
      () => _adminService.deleteProgram(id),
    );
  }

  Future<void> _toggleBranch(Map<String, dynamic> item) async {
    final id = _asInt(item['branch_id']);
    if (id == null) return;
    final active = item['is_active'] == true;
    await _runAction(
      'branch-$id',
      () => active
          ? _adminService.deactivateBranch(id)
          : _adminService.activateBranch(id),
    );
  }

  Future<void> _deleteBranch(Map<String, dynamic> item) async {
    final id = _asInt(item['branch_id']);
    if (id == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Course / Branch?',
      message:
          'Permanently delete ${item['branch_code']} — ${item['branch_name']}?\n\nDeletion is blocked if subjects, students, faculty or sections already reference it.',
    );
    if (!confirmed) return;
    await _runAction(
      'branch-$id',
      () => _adminService.deleteBranch(id),
    );
  }

  Future<void> _runAction(
    String key,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = key);
    try {
      final result = await action();
      _showMessage(result['message']?.toString() ?? 'Updated successfully.');
      await _loadAll();
    } catch (error) {
      _showMessage(_cleanError(error), error: true);
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
      barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Delete Permanently'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Academic Structure'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.school_rounded), text: 'Programs'),
              Tab(
                icon: Icon(Icons.account_tree_rounded),
                text: 'Courses / Branches',
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildError()
                : TabBarView(
                    children: [
                      _buildProgramsTab(),
                      _buildBranchesTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unable to load academic structure.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramsTab() {
    final items = _filteredPrograms;
    return _managementPage(
      title: 'Programs',
      description:
          'Manage degree programs such as B.Tech, M.Tech, BCA or MCA.',
      addLabel: 'Add Program',
      onAdd: _openAddProgramDialog,
      filters: _buildProgramFilters(),
      emptyText: 'No programs match the selected filters.',
      children: items.map(_programCard).toList(),
    );
  }

  Widget _buildBranchesTab() {
    final items = _filteredBranches;
    return _managementPage(
      title: 'Courses / Branches',
      description:
          'Create courses or branches under a selected program, such as CSE, IT or AIML.',
      addLabel: 'Add Course / Branch',
      onAdd: _openAddBranchDialog,
      filters: _buildBranchFilters(),
      emptyText: 'No courses / branches match the selected filters.',
      children: items.map(_branchCard).toList(),
    );
  }

  Widget _managementPage({
    required String title,
    required String description,
    required String addLabel,
    required VoidCallback onAdd,
    required Widget filters,
    required String emptyText,
    required List<Widget> children,
  }) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 18,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 620,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(description),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(addLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          filters,
          const SizedBox(height: 14),
          if (children.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(emptyText)),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _buildProgramFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search Programs',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _programSearch = value),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                key: ValueKey('program-status-$_programStatus'),
                initialValue: _programStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _programStatus = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search Courses / Branches',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _branchSearch = value),
              ),
            ),
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<int?>(
                key: ValueKey('branch-program-${_branchProgramId ?? 0}'),
                initialValue: _branchProgramId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Program'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Programs'),
                  ),
                  ..._programs.map((program) => DropdownMenuItem<int?>(
                        value: _asInt(program['program_id']),
                        child: Text(
                          '${program['program_code']} — ${program['program_name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (value) => setState(() => _branchProgramId = value),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                key: ValueKey('branch-status-$_branchStatus'),
                initialValue: _branchStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _branchStatus = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _programCard(Map<String, dynamic> item) {
    final id = _asInt(item['program_id']) ?? 0;
    final active = item['is_active'] == true;
    final busy = _busyKey == 'program-$id';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item['program_code']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _statusChip(active),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['program_name']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if ((item['description']?.toString().trim() ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(item['description'].toString()),
                    ),
                ],
              ),
            ),
            _actions(
              active: active,
              busy: busy,
              onToggle: () => _toggleProgram(item),
              onDelete: () => _deleteProgram(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchCard(Map<String, dynamic> item) {
    final id = _asInt(item['branch_id']) ?? 0;
    final active = item['is_active'] == true;
    final busy = _busyKey == 'branch-$id';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item['branch_code']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _statusChip(active),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['branch_name']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Program: ${item['program_code']} — ${item['program_name']}',
                  ),
                ],
              ),
            ),
            _actions(
              active: active,
              busy: busy,
              onToggle: () => _toggleBranch(item),
              onDelete: () => _deleteBranch(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions({
    required bool active,
    required bool busy,
    required VoidCallback onToggle,
    required VoidCallback onDelete,
  }) {
    if (busy) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onToggle,
          icon: Icon(active ? Icons.pause_circle_rounded : Icons.play_circle_rounded),
          label: Text(active ? 'Deactivate' : 'Activate'),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _statusChip(bool active) {
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle_rounded : Icons.cancel_rounded,
        size: 18,
      ),
      label: Text(active ? 'Active' : 'Inactive'),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
