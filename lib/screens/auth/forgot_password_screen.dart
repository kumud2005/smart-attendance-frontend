import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen
    extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen>
      createState() =>
          _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _emailFormKey =
      GlobalKey<FormState>();

  final _passwordFormKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _newPasswordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  bool _requesting = false;
  bool _resetting = false;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _resetToken;
  String? _errorMessage;
  String? _infoMessage;

  bool get _passwordStage =>
      _resetToken != null &&
      _resetToken!.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _authService.dispose();

    super.dispose();
  }

  // ============================================================
  // REQUEST RESET
  // ============================================================

  Future<void> _requestReset() async {
    FocusScope.of(context).unfocus();

    if (!_emailFormKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _requesting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final response =
          await _authService
              .requestPasswordReset(
        email:
            _emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      final testMode =
          response['test_mode'] == true;

      final token =
          response['test_reset_token']
              ?.toString()
              .trim();

      if (token == null ||
          token.isEmpty) {
        setState(() {
          _errorMessage = testMode
              ? 'No local reset token was created. '
                'Make sure the email belongs to a registered account.'
              : 'Email verification is not enabled for this build yet. '
                'For local testing, enable the backend test reset mode.';
        });

        return;
      }

      final expires =
          response['expires_in_minutes']
              ?.toString();

      setState(() {
        _resetToken = token;
        _infoMessage =
            'Local testing mode: email ownership verification '
            'is temporarily bypassed. '
            'Set a new password'
            '${expires == null ? '.' : ' within $expires minutes.'}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            _cleanErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _requesting = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRM RESET
  // ============================================================

  Future<void> _confirmReset() async {
    FocusScope.of(context).unfocus();

    if (!_passwordFormKey.currentState!
        .validate()) {
      return;
    }

    final resetToken = _resetToken;

    if (resetToken == null ||
        resetToken.isEmpty) {
      setState(() {
        _errorMessage =
            'Password reset session is missing. '
            'Please start again.';
      });

      return;
    }

    setState(() {
      _resetting = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _authService
              .confirmPasswordReset(
        resetToken: resetToken,
        newPassword:
            _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      final message =
          response['message']
              ?.toString()
              .trim();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (
          dialogContext,
        ) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons
                      .check_circle_rounded,
                  color:
                      AppColors.success,
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    'Password Changed',
                  ),
                ),
              ],
            ),
            content: Text(
              message == null ||
                      message.isEmpty
                  ? 'Your password has been changed successfully.'
                  : message,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();

                  Navigator.of(
                    context,
                  ).pop();
                },
                child: const Text(
                  'Back to Login',
                ),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            _cleanErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _resetting = false;
        });
      }
    }
  }

  // ============================================================
  // START AGAIN
  // ============================================================

  void _startAgain() {
    setState(() {
      _resetToken = null;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _validateNewPassword(
    String? value,
  ) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter a new password.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]')
        .hasMatch(password)) {
      return 'Add at least 1 uppercase letter.';
    }

    if (!RegExp(r'[a-z]')
        .hasMatch(password)) {
      return 'Add at least 1 lowercase letter.';
    }

    if (!RegExp(r'[0-9]')
        .hasMatch(password)) {
      return 'Add at least 1 number.';
    }

    if (!RegExp(r'[^A-Za-z0-9]')
        .hasMatch(password)) {
      return 'Add at least 1 special character.';
    }

    return null;
  }

  // ============================================================
  // ERROR CLEANUP
  // ============================================================

  String _cleanErrorMessage(
    Object error,
  ) {
    var message =
        error.toString().trim();

    if (message.startsWith(
      'Exception: ',
    )) {
      message = message.substring(
        'Exception: '.length,
      ).trim();
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
          'Please try again.';
    }

    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
        ),
      ),
      body: SafeArea(
        child: Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              18,
            ),
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 480,
              ),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    24,
                  ),
                  child:
                      _passwordStage
                          ? _buildPasswordStage()
                          : _buildEmailStage(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMAIL STAGE
  // ============================================================

  Widget _buildEmailStage() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          const Icon(
            Icons
                .lock_reset_rounded,
            size: 52,
            color:
                AppColors.primary,
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'Reset your password',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          const Text(
            'Enter the email registered with your account.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          _buildMessages(),
          TextFormField(
            controller:
                _emailController,
            enabled:
                !_requesting,
            keyboardType:
                TextInputType
                    .emailAddress,
            textInputAction:
                TextInputAction.done,
            decoration:
                const InputDecoration(
              labelText:
                  'Registered email',
              prefixIcon:
                  Icon(
                Icons.email_outlined,
              ),
            ),
            validator: (
              value,
            ) {
              final email =
                  value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Please enter your email.';
              }

              if (!email.contains(
                '@',
              )) {
                return 'Please enter a valid email.';
              }

              return null;
            },
            onFieldSubmitted:
                (_) {
              if (!_requesting) {
                _requestReset();
              }
            },
          ),
          const SizedBox(
            height: 22,
          ),
          SizedBox(
            height: 50,
            child:
                FilledButton.icon(
              onPressed:
                  _requesting
                      ? null
                      : _requestReset,
              icon: _requesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .arrow_forward_rounded,
                    ),
              label: Text(
                _requesting
                    ? 'Checking...'
                    : 'Continue',
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          TextButton(
            onPressed:
                _requesting
                    ? null
                    : () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
            child: const Text(
              'Back to Login',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PASSWORD STAGE
  // ============================================================

  Widget _buildPasswordStage() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          const Icon(
            Icons.password_rounded,
            size: 52,
            color:
                AppColors.primary,
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'Create new password',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _emailController.text
                .trim()
                .toLowerCase(),
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          _buildMessages(),
          TextFormField(
            controller:
                _newPasswordController,
            enabled:
                !_resetting,
            obscureText:
                _obscureNewPassword,
            textInputAction:
                TextInputAction.next,
            decoration:
                InputDecoration(
              labelText:
                  'New password',
              prefixIcon:
                  const Icon(
                Icons
                    .lock_outline_rounded,
              ),
              suffixIcon:
                  IconButton(
                tooltip:
                    _obscureNewPassword
                        ? 'Show password'
                        : 'Hide password',
                onPressed:
                    _resetting
                        ? null
                        : () {
                            setState(
                              () {
                                _obscureNewPassword =
                                    !_obscureNewPassword;
                              },
                            );
                          },
                icon: Icon(
                  _obscureNewPassword
                      ? Icons
                          .visibility_outlined
                      : Icons
                          .visibility_off_outlined,
                ),
              ),
            ),
            validator:
                _validateNewPassword,
          ),
          const SizedBox(
            height: 16,
          ),
          TextFormField(
            controller:
                _confirmPasswordController,
            enabled:
                !_resetting,
            obscureText:
                _obscureConfirmPassword,
            textInputAction:
                TextInputAction.done,
            decoration:
                InputDecoration(
              labelText:
                  'Confirm new password',
              prefixIcon:
                  const Icon(
                Icons
                    .lock_reset_rounded,
              ),
              suffixIcon:
                  IconButton(
                tooltip:
                    _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                onPressed:
                    _resetting
                        ? null
                        : () {
                            setState(
                              () {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              },
                            );
                          },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons
                          .visibility_outlined
                      : Icons
                          .visibility_off_outlined,
                ),
              ),
            ),
            validator: (
              value,
            ) {
              if (value == null ||
                  value.isEmpty) {
                return 'Please confirm your new password.';
              }

              if (value !=
                  _newPasswordController
                      .text) {
                return 'Passwords do not match.';
              }

              return null;
            },
            onFieldSubmitted:
                (_) {
              if (!_resetting) {
                _confirmReset();
              }
            },
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'Use at least 8 characters with uppercase, '
            'lowercase, number and special character.',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(
            height: 22,
          ),
          SizedBox(
            height: 50,
            child:
                FilledButton.icon(
              onPressed:
                  _resetting
                      ? null
                      : _confirmReset,
              icon: _resetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .check_rounded,
                    ),
              label: Text(
                _resetting
                    ? 'Changing...'
                    : 'Change Password',
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          TextButton(
            onPressed:
                _resetting
                    ? null
                    : _startAgain,
            child: const Text(
              'Use a different email',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE BOXES
  // ============================================================

  Widget _buildMessages() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color: AppColors.error
                  .withValues(
                alpha: 0.07,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              border: Border.all(
                color: AppColors.error
                    .withValues(
                  alpha: 0.20,
                ),
              ),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color:
                    AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(
            height: 14,
          ),
        ],
        if (_infoMessage != null) ...[
          Container(
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color: AppColors.primary
                  .withValues(
                alpha: 0.06,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Text(
              _infoMessage!,
              style: const TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(
            height: 14,
          ),
        ],
      ],
    );
  }
}
