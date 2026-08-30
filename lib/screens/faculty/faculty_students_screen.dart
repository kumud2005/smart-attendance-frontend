import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../services/faculty_service.dart';

class FacultyStudentsScreen extends StatefulWidget {
  const FacultyStudentsScreen({super.key});

  @override
  State<FacultyStudentsScreen> createState() =>
      _FacultyStudentsScreenState();
}

class _FacultyStudentsScreenState
    extends State<FacultyStudentsScreen> {
  final FacultyService _service = FacultyService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students =
          await _service.getStudents();

      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Students')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Card(
                          color: AppColors.error.withValues(alpha: 0.06),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _students.isEmpty
                      ? ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 160),
                            Center(
                              child: Text(
                                'No students found.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _students.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = _students[index];

                            final name =
                                item['full_name']?.toString() ??
                                    'Student';
                            final enrollment =
                                item['enrollment_number']
                                        ?.toString() ??
                                    '-';
                            final roll =
                                item['roll_number']?.toString() ??
                                    '-';
                            final section =
                                item['section_name']?.toString() ??
                                    '-';

                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.surfaceSoft,
                                  foregroundColor: AppColors.primary,
                                  child:
                                      Icon(Icons.school_rounded),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Enrollment: $enrollment\n'
                                  'Roll: $roll • Section: $section',
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
