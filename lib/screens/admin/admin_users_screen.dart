import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_action_styles.dart';

import '../../models/admin_user.dart';
import '../../services/admin_service.dart';
import 'admin_registration_requests_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  final String? initialStatus;
  final String? initialRole;
  final String? title;

  const AdminUsersScreen({
    super.key,
    this.initialStatus,
    this.initialRole,
    this.title,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();

  List<AdminUser> _users = [];

  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedStatus;
  String? _selectedRole;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _selectedStatus = widget.initialStatus;
    _selectedRole = widget.initialRole;

    _loadUsers();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD USERS
  // ============================================================

  Future<void> _loadUsers() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<AdminUser> users;

      if (_selectedStatus == 'PENDING') {
        users = await _adminService.getPendingUsers();
      } else {
        users = await _adminService.getUsers(
          roleName: _selectedRole,
          accountStatus: _selectedStatus,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // FILTERED USERS
  // ============================================================

  List<AdminUser> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _users;
    }

    return _users.where((user) {
      final searchableText = [
        user.userId.toString(),
        user.email,
        user.fullName,
        user.phone ?? '',
        user.roleName,
        user.accountStatus,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  // ============================================================
  // USER ID
  // ============================================================

  int _getUserId(AdminUser user) {
    return user.userId;
  }

  // ============================================================
  // USER NAME
  // ============================================================

  String _getUserName(AdminUser user) {
    if (user.fullName.trim().isNotEmpty) {
      return user.fullName;
    }

    if (user.email.trim().isNotEmpty) {
      return user.email;
    }

    return 'Unknown User';
  }

  // ============================================================
  // REVIEW PUBLIC REGISTRATION
  // ============================================================

  Future<void> _reviewRegistration(
    AdminUser user,
  ) async {
    final role =
        user.roleName.trim().toUpperCase();

    if (role != 'STUDENT' &&
        role != 'FACULTY') {
      _showMessage(
        'This pending account is not a Student or Faculty registration request.',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdminRegistrationRequestsScreen(
          initialRole: role,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadUsers();
  }

  // ============================================================
  // STUDENT FACE PROFILE
  // ============================================================

  int? _findIntByKey(
    dynamic value,
    String key,
  ) {
    if (value is Map) {
      if (value.containsKey(key)) {
        final raw = value[key];

        if (raw is int) {
          return raw;
        }

        if (raw is num) {
          return raw.toInt();
        }

        final parsed = int.tryParse(
          raw?.toString() ?? '',
        );

        if (parsed != null) {
          return parsed;
        }
      }

      for (final nested in value.values) {
        final result = _findIntByKey(
          nested,
          key,
        );

        if (result != null) {
          return result;
        }
      }
    }

    if (value is List) {
      for (final nested in value) {
        final result = _findIntByKey(
          nested,
          key,
        );

        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  Future<Map<String, dynamic>>
      _loadStudentFaceProfile(
    AdminUser user,
  ) async {
    final details = await _adminService
        .getUserDetails(user.userId);

    final studentId = _findIntByKey(
      details,
      'student_id',
    );

    if (studentId == null ||
        studentId <= 0) {
      throw Exception(
        'Student profile ID could not be found for this account.',
      );
    }

    return _adminService.getStudentFaceProfile(
      studentId,
    );
  }

  bool _adminFaceRegistered(
    Map<String, dynamic> data,
  ) {
    return data['registered'] == true ||
        data['is_registered'] == true ||
        data['face_profile_id'] != null;
  }

  String _faceText(
    Map<String, dynamic> data,
    String key, {
    String fallback = '-',
  }) {
    final value = data[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty
        ? fallback
        : text;
  }

  String _formatFaceDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) {
      return raw;
    }

    final local = parsed.toLocal();

    String twoDigits(int number) =>
        number.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  Future<void> _showStudentFaceProfile(
    AdminUser user,
  ) async {
    final role =
        user.roleName.trim().toUpperCase();

    if (role != 'STUDENT') {
      _showMessage(
        'Face-profile management is available only for Student accounts.',
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _loadStudentFaceProfile(user),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Student Face Profile'),
                content: SizedBox(
                  height: 90,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text(
                  'Student Face Profile',
                ),
                content: Text(
                  snapshot.error
                          ?.toString()
                          .replaceFirst(
                            'Exception: ',
                            '',
                          ) ??
                      'Unable to load face profile.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final data =
                snapshot.data ?? <String, dynamic>{};
            final registered =
                _adminFaceRegistered(data);
            final studentId = _findIntByKey(
              data,
              'student_id',
            );

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    registered
                        ? Icons.verified_user_rounded
                        : Icons.face_retouching_off,
                    color: registered
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Student Face Profile',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: registered
                              ? AppColors.success.withValues(
                                  alpha: 0.08,
                                )
                              : AppColors.surfaceSoft,
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(
                          registered
                              ? 'REGISTERED'
                              : 'NOT REGISTERED',
                          style: TextStyle(
                            color: registered
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildDetailRow(
                        'Student',
                        _faceText(
                          data,
                          'full_name',
                          fallback: _getUserName(user),
                        ),
                      ),
                      _buildDetailRow(
                        'Student ID',
                        studentId?.toString() ?? '-',
                      ),
                      _buildDetailRow(
                        'Enrollment',
                        _faceText(
                          data,
                          'enrollment_number',
                        ),
                      ),
                      if (registered) ...[
                        _buildDetailRow(
                          'Face Profile ID',
                          _faceText(
                            data,
                            'face_profile_id',
                          ),
                        ),
                        _buildDetailRow(
                          'Model',
                          _faceText(
                            data,
                            'embedding_model',
                          ),
                        ),
                        _buildDetailRow(
                          'Dimensions',
                          _faceText(
                            data,
                            'embedding_dimensions',
                          ),
                        ),
                        _buildDetailRow(
                          'Verified',
                          data['is_verified'] == true
                              ? 'Yes'
                              : 'No',
                        ),
                        _buildDetailRow(
                          'Active',
                          data['is_active'] == true
                              ? 'Yes'
                              : 'No',
                        ),
                        _buildDetailRow(
                          'Registered At',
                          _formatFaceDateTime(
                            data['face_created_at'] ??
                                data['created_at'],
                          ),
                        ),
                        _buildDetailRow(
                          'Updated At',
                          _formatFaceDateTime(
                            data['face_updated_at'] ??
                                data['updated_at'],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        registered
                            ? 'Reset removes only the Student face profile. The account and attendance history remain unchanged.'
                            : 'This Student can register a face profile from the Student mobile app.',
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
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Close'),
                ),
                if (registered &&
                    studentId != null &&
                    studentId > 0)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _confirmResetStudentFace(
                        user: user,
                        studentId: studentId,
                      );
                    },
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                    ),
                    label: const Text(
                      'Reset Face Profile',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmResetStudentFace({
    required AdminUser user,
    required int studentId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reset Face Profile',
          ),
          content: Text(
            'Reset the registered face for "${_getUserName(user)}"? '
            'This does not delete the Student account or attendance history. '
            'The Student will be able to register a new face afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: SemanticActionStyles.filled(
                SemanticActionStyles.destructive,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result = await _adminService
          .deleteStudentFaceProfile(studentId);

      if (!mounted) {
        return;
      }

      _showMessage(
        result['message']?.toString().trim().isNotEmpty ==
                true
            ? result['message'].toString()
            : 'Student face profile reset successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ============================================================
  // CHANGE STATUS
  // ============================================================

  Future<void> _changeStatus(
    AdminUser user,
    String status,
  ) async {
    final userId = _getUserId(user);

    try {
      await _adminService.changeUserStatus(
        userId: userId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'User status changed successfully.',
      );

      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ============================================================
  // USER DETAILS
  // ============================================================

  Future<void> _showUserDetails(
    AdminUser user,
  ) async {
    final userId = _getUserId(user);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _adminService.getUserDetails(userId),
          builder: (
            context,
            snapshot,
          ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 80,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('User Details'),
                content: Text(
                  snapshot.error
                          ?.toString()
                          .replaceFirst(
                            'Exception: ',
                            '',
                          ) ??
                      'Unable to load user details.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final details = snapshot.data ?? {};

            return AlertDialog(
              title: const Text('User Details'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: _buildDetailsContent(
                    details,
                    fallbackUser: user,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DETAILS CONTENT
  // ============================================================

  Widget _buildDetailsContent(
    Map<String, dynamic> details, {
    required AdminUser fallbackUser,
  }) {
    if (details.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDetailRow(
            'User ID',
            fallbackUser.userId.toString(),
          ),
          _buildDetailRow(
            'Full Name',
            fallbackUser.fullName,
          ),
          _buildDetailRow(
            'Email',
            fallbackUser.email,
          ),
          _buildDetailRow(
            'Phone',
            fallbackUser.phone ?? '-',
          ),
          _buildDetailRow(
            'Role',
            fallbackUser.roleName,
          ),
          _buildDetailRow(
            'Account Status',
            fallbackUser.accountStatus,
          ),
          _buildDetailRow(
            'Created At',
            _formatDateTime(fallbackUser.createdAt),
          ),
          _buildDetailRow(
            'Updated At',
            _formatDateTime(fallbackUser.updatedAt),
          ),
          _buildDetailRow(
            'Last Login',
            fallbackUser.lastLoginAt == null
                ? 'Never'
                : _formatDateTime(
                    fallbackUser.lastLoginAt!,
                  ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: details.entries.map((entry) {
        return _buildDetailRow(
          _formatKey(entry.key),
          entry.value?.toString() ?? '-',
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${local.day}/${local.month}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  // ============================================================
  // CONFIRM STATUS CHANGE
  // ============================================================

  Future<void> _confirmStatusChange(
    AdminUser user,
    String status,
  ) async {
    final name = _getUserName(user);

    final action = switch (status) {
      'ACTIVE' => 'activate',
      'SUSPENDED' => 'suspend',
      'INACTIVE' => 'deactivate',
      _ => 'change the status of',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${_capitalize(action)} User',
          ),
          content: Text(
            'Are you sure you want to $action "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: SemanticActionStyles.filled(
                status == 'ACTIVE'
                    ? SemanticActionStyles.positive
                    : status == 'INACTIVE' ||
                            status == 'SUSPENDED'
                        ? SemanticActionStyles.caution
                        : SemanticActionStyles.primary,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _changeStatus(user, status);
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.error : null,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'All Users';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusDropdown(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleDropdown(),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildSearchField(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatusDropdown(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildRoleDropdown(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText:
            'Search by name, email, phone, role or ID...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.clear_rounded,
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: AppColors.surfaceSoft,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Account Status',
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
        ),
      ),
      items: const [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('All Statuses'),
        ),
        DropdownMenuItem<String?>(
          value: 'ACTIVE',
          child: Text('Active'),
        ),
        DropdownMenuItem<String?>(
          value: 'PENDING',
          child: Text('Pending'),
        ),
        DropdownMenuItem<String?>(
          value: 'SUSPENDED',
          child: Text('Suspended'),
        ),
        DropdownMenuItem<String?>(
          value: 'INACTIVE',
          child: Text('Inactive'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
        });

        _loadUsers();
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedRole,
      decoration: InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
        ),
      ),
      items: const [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('All Roles'),
        ),
        DropdownMenuItem<String?>(
          value: 'STUDENT',
          child: Text('Students'),
        ),
        DropdownMenuItem<String?>(
          value: 'FACULTY',
          child: Text('Faculty'),
        ),
        DropdownMenuItem<String?>(
          value: 'ADMIN',
          child: Text('Administrators'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
        });

        _loadUsers();
      },
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final users = _filteredUsers;

    if (users.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics:
            const AlwaysScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (
          context,
          index,
        ) =>
            const SizedBox(height: 10),
        itemBuilder: (
          context,
          index,
        ) {
          return _buildUserCard(users[index]);
        },
      ),
    );
  }

  // ============================================================
  // USER CARD
  // ============================================================

  Widget _buildUserCard(AdminUser user) {
    final name = _getUserName(user);
    final email = user.email;
    final role = user.roleName;
    final status = user.accountStatus.toUpperCase();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showUserDetails(user),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    AppColors.surfaceSoft,
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color:
                        AppColors.primary,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      email,
                      style: TextStyle(
                        color:
                            AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'User ID: ${user.userId}',
                      style: TextStyle(
                        color:
                            AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildChip(
                          role,
                          AppColors.primary,
                        ),
                        _buildStatusChip(
                          status,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _buildUserActions(
                user,
                status,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      final value = parts.first;

      return value
          .substring(
            0,
            value.length >= 2 ? 2 : 1,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  Widget _buildChip(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text.isEmpty ? 'Unknown' : text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color color;

    switch (status) {
      case 'ACTIVE':
        color = SemanticActionStyles.positive;
        break;

      case 'PENDING':
        color = SemanticActionStyles.caution;
        break;

      case 'SUSPENDED':
      case 'INACTIVE':
        color = SemanticActionStyles.caution;
        break;

      default:
        color = AppColors.textSecondary;
    }

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
        status.isEmpty ? 'UNKNOWN' : status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // USER ACTIONS
  // ============================================================

  Widget _buildUserActions(
    AdminUser user,
    String status,
  ) {
    final role =
        user.roleName
            .trim()
            .toUpperCase();

    final isPublicRegistration =
        status == 'PENDING' &&
            (role == 'STUDENT' ||
                role == 'FACULTY');

    return PopupMenuButton<String>(
      tooltip: 'User actions',
      onSelected: (value) {
        if (value == 'details') {
          _showUserDetails(user);
          return;
        }

        if (value ==
            'review_registration') {
          _reviewRegistration(user);
          return;
        }

        if (value == 'face_profile') {
          _showStudentFaceProfile(user);
          return;
        }

        _confirmStatusChange(
          user,
          value,
        );
      },
      itemBuilder: (context) {
        if (isPublicRegistration) {
          return [
            const PopupMenuItem<String>(
              value: 'details',
              child: ListTile(
                leading: Icon(
                  Icons
                      .visibility_rounded,
                ),
                title:
                    Text('View Details'),
                contentPadding:
                    EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value:
                  'review_registration',
              child: ListTile(
                leading: Icon(
                  Icons
                      .fact_check_outlined,
                ),
                title: Text(
                  'Review Registration',
                ),
                subtitle: Text(
                  'Approve or reject using the registration review flow',
                ),
                contentPadding:
                    EdgeInsets.zero,
              ),
            ),
          ];
        }

        return [
          const PopupMenuItem<String>(
            value: 'details',
            child: ListTile(
              leading: Icon(
                Icons.visibility_rounded,
              ),
              title:
                  Text('View Details'),
              contentPadding:
                  EdgeInsets.zero,
            ),
          ),

          if (role == 'STUDENT')
            const PopupMenuItem<String>(
              value: 'face_profile',
              child: ListTile(
                leading: Icon(
                  Icons.face_retouching_natural,
                ),
                title: Text(
                  'Face Status / Reset',
                ),
                subtitle: Text(
                  'View registration status or reset the face profile',
                ),
                contentPadding:
                    EdgeInsets.zero,
              ),
            ),

          if (status != 'ACTIVE')
            const PopupMenuItem<String>(
              value: 'ACTIVE',
              child: ListTile(
                leading: Icon(
                  Icons.check_circle_rounded,
                  color: SemanticActionStyles.positive,
                ),
                title: Text(
                  'Activate',
                  style: TextStyle(
                    color: SemanticActionStyles.positive,
                  ),
                ),
                contentPadding:
                    EdgeInsets.zero,
              ),
            ),

          if (status != 'SUSPENDED')
            const PopupMenuItem<String>(
              value: 'SUSPENDED',
              child: ListTile(
                leading: Icon(
                  Icons.block_rounded,
                  color: SemanticActionStyles.caution,
                ),
                title: Text(
                  'Suspend',
                  style: TextStyle(
                    color: SemanticActionStyles.caution,
                  ),
                ),
                contentPadding:
                    EdgeInsets.zero,
              ),
            ),

          if (status != 'INACTIVE')
            const PopupMenuItem<String>(
              value: 'INACTIVE',
              child: ListTile(
                leading: Icon(
                  Icons.pause_circle_rounded,
                  color: SemanticActionStyles.caution,
                ),
                title: Text(
                  'Deactivate',
                  style: TextStyle(
                    color: SemanticActionStyles.caution,
                  ),
                ),
                contentPadding:
                    EdgeInsets.zero,
              ),
            ),
        ];
      },
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 70,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 16),

            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _searchQuery.isNotEmpty
                  ? 'No users match your search.'
                  : 'There are no users for the selected filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Card(
          child: Padding(
            padding:
                const EdgeInsets.all(30),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 55,
                  color:
                      AppColors.error,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Unable to load users',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 500,
                  ),
                  child: Text(
                    _errorMessage ??
                        'An unknown error occurred.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label:
                      const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
