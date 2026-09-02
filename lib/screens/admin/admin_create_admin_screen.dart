import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/admin_service.dart';

class AdminCreateAdminScreen extends StatefulWidget {
  const AdminCreateAdminScreen({super.key});

  @override
  State<AdminCreateAdminScreen> createState() =>
      _AdminCreateAdminScreenState();
}

class _AdminCreateAdminScreenState
    extends State<AdminCreateAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminService.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await _adminService.createAdmin(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _fullNameController.text,
        employeeId: _employeeIdController.text,
        phone: _phoneController.text,
        designation: _designationController.text,
      );

      if (!mounted) {
        return;
      }

      final serverMessage = response['message']?.toString().trim();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.primary,
              size: 44,
            ),
            title: const Text('Administrator Created'),
            content: Text(
              serverMessage == null || serverMessage.isEmpty
                  ? 'Administrator account created successfully.'
                  : serverMessage,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Administrator'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildFormCard(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBox(_errorMessage!),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            _isSubmitting ? null : _createAdmin,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.person_add_alt_1_rounded,
                              ),
                        label: Text(
                          _isSubmitting
                              ? 'Creating...'
                              : 'Create Administrator',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Only an authenticated Administrator can create another Administrator account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
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
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.primary,
              size: 29,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Administrator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create a secure administrator account for the attendance system.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field(
              controller: _fullNameController,
              label: 'Full name',
              icon: Icons.badge_outlined,
              validator: (value) {
                if ((value ?? '').trim().length < 2) {
                  return 'Please enter the administrator full name.';
                }
                return null;
              },
            ),
            _gap(),
            _field(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) {
                  return 'Please enter an email address.';
                }
                if (!email.contains('@')) {
                  return 'Please enter a valid email address.';
                }
                return null;
              },
            ),
            _gap(),
            _field(
              controller: _phoneController,
              label: 'Phone number (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (_) => null,
            ),
            _gap(),
            _field(
              controller: _employeeIdController,
              label: 'Employee ID',
              icon: Icons.numbers_rounded,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Please enter an employee ID.';
                }
                return null;
              },
            ),
            _gap(),
            _field(
              controller: _designationController,
              label: 'Designation (optional)',
              icon: Icons.work_outline_rounded,
              validator: (_) => null,
            ),
            _gap(),
            _field(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Show password'
                    : 'Hide password',
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if ((value ?? '').length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                return null;
              },
            ),
            _gap(),
            _field(
              controller: _confirmPasswordController,
              label: 'Confirm password',
              icon: Icons.lock_reset_rounded,
              obscureText: _obscurePassword,
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Please confirm the password.';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSubmitting,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  Widget _gap() {
    return const SizedBox(height: 16);
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanErrorMessage(Object error) {
    var message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      message =
          message.substring('Exception: '.length).trim();
    }

    final lower = message.toLowerCase();

    if (lower.contains('failed to fetch') ||
        lower.contains('clientexception') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network request failed')) {
      return 'Unable to connect to the server. '
          'Please check your connection and try again.';
    }

    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }
}
