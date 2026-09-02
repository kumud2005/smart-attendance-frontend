import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  final _enrollment = TextEditingController();
  final _rollNumber = TextEditingController();
  final _dateOfBirth = TextEditingController();

  final _employeeId = TextEditingController();
  final _department = TextEditingController();
  final _designation = TextEditingController();

  String _roleName = 'STUDENT';
  bool _loadingOptions = true;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _optionsError;
  String? _submitError;

  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _subjects = [];

  int? _semesterId;
  int? _sectionId;
  final Set<int> _selectedSubjectIds = {};
  final List<Map<String, dynamic>> _facultyAssignments = [];

  bool get _isStudent => _roleName == 'STUDENT';

  List<Map<String, dynamic>> get _filteredSections {
    if (_semesterId == null) return [];
    return _sections
        .where((e) => _asInt(e['semester_id']) == _semesterId)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    if (_semesterId == null) return [];
    return _subjects
        .where((e) => _asInt(e['semester_id']) == _semesterId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _email,
      _phone,
      _password,
      _confirmPassword,
      _enrollment,
      _rollNumber,
      _dateOfBirth,
      _employeeId,
      _department,
      _designation,
    ]) {
      controller.dispose();
    }
    _authService.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });

    try {
      final response = await _authService.getRegistrationOptions();
      if (!mounted) return;
      setState(() {
        _semesters = _mapList(response['semesters']);
        _sections = _mapList(response['sections']);
        _subjects = _mapList(response['subjects']);
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _optionsError = _cleanError(e);
      });
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map(
          (e) => e.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void _changeRole(String role) {
    if (_submitting) return;
    setState(() {
      _roleName = role;
      _semesterId = null;
      _sectionId = null;
      _selectedSubjectIds.clear();
      _submitError = null;
    });
  }

  void _changeSemester(int? value) {
    setState(() {
      _semesterId = value;
      _sectionId = null;
      _selectedSubjectIds.clear();
      _submitError = null;
    });
  }

  void _changeSection(int? value) {
    setState(() {
      _sectionId = value;
      _selectedSubjectIds.clear();
      _submitError = null;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (selected == null || !mounted) return;

    final y = selected.year.toString().padLeft(4, '0');
    final m = selected.month.toString().padLeft(2, '0');
    final d = selected.day.toString().padLeft(2, '0');
    setState(() => _dateOfBirth.text = '$y-$m-$d');
  }

  void _addFacultyAssignments() {
    if (_semesterId == null) {
      _snack('Please select a semester.');
      return;
    }
    if (_sectionId == null) {
      _snack('Please select a section.');
      return;
    }
    if (_selectedSubjectIds.isEmpty) {
      _snack('Please select at least one subject.');
      return;
    }

    var added = 0;
    for (final subjectId in _selectedSubjectIds) {
      final exists = _facultyAssignments.any(
        (a) =>
            a['semester_id'] == _semesterId &&
            a['section_id'] == _sectionId &&
            a['subject_id'] == subjectId,
      );
      if (!exists) {
        _facultyAssignments.add({
          'semester_id': _semesterId!,
          'section_id': _sectionId!,
          'subject_id': subjectId,
        });
        added++;
      }
    }

    setState(() {
      _selectedSubjectIds.clear();
      _submitError = null;
    });

    _snack(
      added == 0
          ? 'Those assignments are already added.'
          : '$added assignment${added == 1 ? '' : 's'} added.',
    );
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_semesterId == null) {
      setState(() => _submitError = 'Please select a semester.');
      return;
    }
    if (_sectionId == null) {
      setState(() => _submitError = 'Please select a section.');
      return;
    }
    if (!_isStudent && _facultyAssignments.isEmpty) {
      setState(() {
        _submitError = 'Please add at least one faculty assignment.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      late final Map<String, dynamic> response;

      if (_isStudent) {
        response = await _authService.registerStudent(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
          phone: _phone.text,
          enrollmentNumber: _enrollment.text,
          rollNumber: _rollNumber.text,
          dateOfBirth: _dateOfBirth.text,
          studentSectionId: _sectionId!,
        );
      } else {
        response = await _authService.registerFaculty(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
          phone: _phone.text,
          employeeId: _employeeId.text,
          department: _department.text,
          designation: _designation.text,
          facultyAssignments: _facultyAssignments
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }

      if (!mounted) return;
      final message = response['message']?.toString().trim();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primary,
            size: 42,
          ),
          title: const Text('Registration Submitted'),
          content: Text(
            '${(message == null || message.isEmpty) ? 'Registration successful. Your account is pending administrator approval.' : message}\n\n'
            'You can sign in after an administrator approves your account.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Back to Sign In'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = _cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: _loadingOptions
            ? const Center(child: CircularProgressIndicator())
            : _optionsError != null
                ? _buildOptionsError()
                : _buildForm(),
      ),
    );
  }

  Widget _buildOptionsError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load registration options',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _optionsError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loadOptions,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildRoleSelector(),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Account Details',
                  icon: Icons.person_outline_rounded,
                  children: [
                    _field(_fullName, 'Full name', Icons.badge_outlined,
                        validator: _required('Please enter your full name.')),
                    _gap(),
                    _field(
                      _email,
                      'Email address',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final email = (v ?? '').trim();
                        if (email.isEmpty) return 'Please enter your email.';
                        if (!email.contains('@')) return 'Please enter a valid email.';
                        return null;
                      },
                    ),
                    _gap(),
                    _field(
                      _phone,
                      'Phone number (optional)',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    _gap(),
                    _field(
                      _password,
                      'Password',
                      Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 8
                          ? 'Password must be at least 8 characters.'
                          : null,
                    ),
                    _gap(),
                    _field(
                      _confirmPassword,
                      'Confirm password',
                      Icons.lock_reset_rounded,
                      obscureText: _obscurePassword,
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Please confirm your password.';
                        if (v != _password.text) return 'Passwords do not match.';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isStudent) _buildStudentCard() else _buildFacultyCard(),
                const SizedBox(height: 16),
                _buildAcademicCard(),
                if (!_isStudent) ...[
                  const SizedBox(height: 16),
                  _buildRequestedAssignments(),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _errorBox(_submitError!),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _register,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      _submitting ? 'Submitting...' : 'Submit Registration',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Already have an account? Sign In'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Administrator accounts cannot be created through public registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(Icons.school_rounded, color: AppColors.primary, size: 27),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GHRCE Smart Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create a Student or Faculty account',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Register as',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'STUDENT', icon: Icon(Icons.school_outlined), label: Text('Student')),
                  ButtonSegment(value: 'FACULTY', icon: Icon(Icons.co_present_outlined), label: Text('Faculty')),
                ],
                selected: {_roleName},
                showSelectedIcon: false,
                onSelectionChanged: _submitting ? null : (s) => _changeRole(s.first),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard() {
    return _sectionCard(
      title: 'Student Details',
      icon: Icons.school_outlined,
      children: [
        _field(
          _enrollment,
          'Enrollment number',
          Icons.numbers_rounded,
          validator: _required('Please enter your enrollment number.'),
        ),
        _gap(),
        _field(
          _rollNumber,
          'Roll number',
          Icons.tag_rounded,
          validator: _required('Please enter your roll number.'),
        ),
        _gap(),
        _field(
          _dateOfBirth,
          'Date of birth',
          Icons.cake_outlined,
          readOnly: true,
          onTap: _pickDateOfBirth,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
          validator: _required('Please select your date of birth.'),
        ),
      ],
    );
  }

  Widget _buildFacultyCard() {
    return _sectionCard(
      title: 'Faculty Details',
      icon: Icons.co_present_outlined,
      children: [
        _field(
          _employeeId,
          'Employee ID',
          Icons.badge_outlined,
          validator: _required('Please enter your employee ID.'),
        ),
        _gap(),
        _field(
          _department,
          'Department',
          Icons.apartment_rounded,
          validator: _required('Please enter your department.'),
        ),
        _gap(),
        _field(
          _designation,
          'Designation',
          Icons.work_outline_rounded,
          validator: _required('Please enter your designation.'),
        ),
      ],
    );
  }

  Widget _buildAcademicCard() {
    return _sectionCard(
      title: _isStudent ? 'Academic Details' : 'Request Academic Assignment',
      icon: Icons.menu_book_rounded,
      children: [
        _dropdown(
          label: 'Semester',
          icon: Icons.layers_outlined,
          value: _semesterId,
          items: _semesters
              .map((s) => _asInt(s['semester_id']))
              .whereType<int>()
              .map((id) => DropdownMenuItem(value: id, child: Text(_semesterLabel(id))))
              .toList(),
          onChanged: _submitting ? null : _changeSemester,
        ),
        const SizedBox(height: 16),
        _dropdown(
          label: 'Section',
          icon: Icons.groups_outlined,
          value: _sectionId,
          items: _filteredSections
              .map((s) => _asInt(s['section_id']))
              .whereType<int>()
              .map((id) => DropdownMenuItem(value: id, child: Text(_sectionLabel(id))))
              .toList(),
          onChanged: _semesterId == null || _submitting ? null : _changeSection,
        ),
        if (!_isStudent) ...[
          const SizedBox(height: 18),
          const Text(
            'Subjects',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_semesterId == null)
            const Text(
              'Select a semester to view subjects.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else if (_filteredSubjects.isEmpty)
            const Text(
              'No active subjects are available for the selected semester.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.18),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _filteredSubjects.map((subject) {
                  final subjectId = _asInt(subject['subject_id']);
                  if (subjectId == null) return const SizedBox.shrink();
                  return CheckboxListTile(
                    value: _selectedSubjectIds.contains(subjectId),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: Text(_subjectLabel(subjectId)),
                    onChanged: _submitting || _sectionId == null
                        ? null
                        : (value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedSubjectIds.add(subjectId);
                              } else {
                                _selectedSubjectIds.remove(subjectId);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _addFacultyAssignments,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Selected Assignment(s)'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can add subjects from more than one semester or section. These are requests only; an administrator must approve them.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequestedAssignments() {
    return _sectionCard(
      title: 'Requested Assignments',
      icon: Icons.assignment_outlined,
      children: [
        if (_facultyAssignments.isEmpty)
          const Text(
            'No assignments added yet.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...List.generate(_facultyAssignments.length, (index) {
            final a = _facultyAssignments[index];
            final semesterId = a['semester_id'] as int;
            final sectionId = a['section_id'] as int;
            final subjectId = a['subject_id'] as int;
            return Container(
              margin: EdgeInsets.only(
                bottom: index == _facultyAssignments.length - 1 ? 0 : 10,
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_semesterLabel(semesterId)} • ${_sectionLabel(sectionId)}\n${_subjectLabel(subjectId)}',
                      style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove assignment',
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _facultyAssignments.removeAt(index)),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?>? onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: Text('Select $label'),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String? Function(String?) _required(String message) {
    return (value) => (value ?? '').trim().isEmpty ? message : null;
  }

  Widget _gap() => const SizedBox(height: 16);

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findById(
    List<Map<String, dynamic>> items,
    String key,
    int id,
  ) {
    for (final item in items) {
      if (_asInt(item[key]) == id) return item;
    }
    return null;
  }

  String _semesterLabel(int id) {
    final row = _findById(_semesters, 'semester_id', id);
    final number = row?['semester_number']?.toString().trim();
    final name = row?['semester_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    if (number != null && number.isNotEmpty) return 'Semester $number';
    return 'Semester $id';
  }

  String _sectionLabel(int id) {
    final row = _findById(_sections, 'section_id', id);
    final name = row?['section_name']?.toString().trim();
    return name == null || name.isEmpty ? 'Section $id' : 'Section $name';
  }

  String _subjectLabel(int id) {
    final row = _findById(_subjects, 'subject_id', id);
    final code = row?['subject_code']?.toString().trim();
    final name = row?['subject_name']?.toString().trim();
    if (code != null && code.isNotEmpty && name != null && name.isNotEmpty) {
      return '$code - $name';
    }
    if (name != null && name.isNotEmpty) return name;
    if (code != null && code.isNotEmpty) return code;
    return 'Subject $id';
  }

  String _cleanError(Object error) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    final lower = message.toLowerCase();
    if (lower.contains('failed to fetch') ||
        lower.contains('clientexception') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network request failed')) {
      return 'Unable to connect to the server. Please check your connection and try again.';
    }
    return message.isEmpty ? 'Something went wrong. Please try again.' : message;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
