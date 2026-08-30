import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../models/faculty_profile.dart';
import '../../services/faculty_service.dart';

class FacultyProfileScreen extends StatefulWidget {
  const FacultyProfileScreen({super.key});

  @override
  State<FacultyProfileScreen> createState() =>
      _FacultyProfileScreenState();
}

class _FacultyProfileScreenState
    extends State<FacultyProfileScreen> {
  final FacultyService _service = FacultyService();

  FacultyProfile? _profile;
  bool _loading = true;
  String? _error;

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
      final profile = await _service.getProfile();
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
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
                  if (profile != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.surfaceSoft,
                              foregroundColor: AppColors.primary,
                              child: Icon(
                                Icons.person_rounded,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _row(
                              'Employee ID',
                              profile.employeeId,
                            ),
                            _row(
                              'Name',
                              profile.fullName,
                            ),
                            _row(
                              'Email',
                              profile.email,
                            ),
                            _row(
                              'Phone',
                              profile.phone ?? '',
                            ),
                            _row(
                              'Department',
                              profile.department ?? '',
                            ),
                            _row(
                              'Designation',
                              profile.designation ?? '',
                            ),
                            _row(
                              'Role',
                              profile.roleName,
                            ),
                            _row(
                              'Status',
                              profile.accountStatus,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
