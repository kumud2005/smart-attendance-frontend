import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';

import '../admin/admin_dashboard_screen.dart';
import '../faculty/faculty_dashboard_screen.dart';
import '../student/student_dashboard_screen.dart'
    if (dart.library.html)
        '../student/student_dashboard_web_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authService.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _authService.login(
        email:
            _emailController.text.trim(),
        password:
            _passwordController.text,
      );

      // ----------------------------------------------------------
      // READ LOGIN RESPONSE
      // ----------------------------------------------------------

      final accessToken =
          response['access_token']
              ?.toString()
              .trim();

      var roleName =
          response['role_name']
              ?.toString()
              .trim()
              .toUpperCase();

      var accountStatus =
          response['account_status']
              ?.toString()
              .trim()
              .toUpperCase();

      // ----------------------------------------------------------
      // NORMALIZE ENUM-LIKE VALUES
      // ----------------------------------------------------------

      if (roleName != null &&
          roleName.contains('.')) {
        roleName =
            roleName.split('.').last;
      }

      if (accountStatus != null &&
          accountStatus.contains('.')) {
        accountStatus =
            accountStatus.split('.').last;
      }

      // ----------------------------------------------------------
      // VALIDATE ACCESS TOKEN
      // ----------------------------------------------------------

      if (accessToken == null ||
          accessToken.isEmpty) {
        throw Exception(
          'Login succeeded, but no access token was returned.',
        );
      }

      // ----------------------------------------------------------
      // VALIDATE ROLE
      // ----------------------------------------------------------

      if (roleName == null ||
          roleName.isEmpty) {
        throw Exception(
          'Login succeeded, but no account role was returned.',
        );
      }

      // ----------------------------------------------------------
      // VALIDATE ACCOUNT STATUS
      // ----------------------------------------------------------

      if (accountStatus != 'ACTIVE') {
        throw Exception(
          'Your account is not active.',
        );
      }

      // ----------------------------------------------------------
      // SAVE ACCESS TOKEN
      // ----------------------------------------------------------

      await TokenStorage.saveAccessToken(
        accessToken,
      );

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------
      // ROLE-BASED NAVIGATION
      // ----------------------------------------------------------

      switch (roleName) {
        // ========================================================
        // ADMIN
        // ========================================================

        case 'ADMIN':
          Navigator.of(context)
              .pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  const AdminDashboardScreen(),
            ),
          );
          return;

        // ========================================================
        // FACULTY
        // ========================================================

        case 'FACULTY':
          Navigator.of(context)
              .pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  const FacultyDashboardScreen(),
            ),
          );
          return;

        // ========================================================
        // STUDENT
        // ========================================================

        case 'STUDENT':
          Navigator.of(context)
              .pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  const StudentDashboardScreen(),
            ),
          );
          return;

        // ========================================================
        // UNSUPPORTED ROLE
        // ========================================================

        default:
          throw Exception(
            'Your account role does not have an available dashboard.',
          );
      }
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
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CLEAN ERROR MESSAGE
  // ============================================================

  String _cleanErrorMessage(
    Object error,
  ) {
    final message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isDesktop =
                constraints.maxWidth >= 900;

            if (isDesktop) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child:
                        _buildBrandPanel(
                      desktop: true,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      color:
                          AppColors.background,
                      alignment:
                          Alignment.center,
                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets
                                .all(
                          40,
                        ),
                        child:
                            _buildLoginCard(),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildBrandPanel(
                    desktop: false,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      20,
                      24,
                      20,
                      32,
                    ),
                    child:
                        _buildLoginCard(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // RAISONI BRAND PANEL
  // ============================================================

  Widget _buildBrandPanel({
    required bool desktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal:
            desktop ? 64 : 28,
        vertical:
            desktop ? 56 : 34,
      ),
      decoration:
          const BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          // ------------------------------------------------------
          // DECORATIVE ORANGE CIRCLE
          // ------------------------------------------------------

          Positioned(
            top: -90,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration:
                  BoxDecoration(
                color: AppColors.accent
                    .withValues(
                  alpha: 0.18,
                ),
                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          // ------------------------------------------------------
          // DECORATIVE WHITE CIRCLE
          // ------------------------------------------------------

          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withValues(
                  alpha: 0.05,
                ),
                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // RAISONI BRAND BOX
              // --------------------------------------------------

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                          const BoxDecoration(
                        color:
                            AppColors.primary,
                        shape:
                            BoxShape.circle,
                      ),
                      child:
                          const Icon(
                        Icons
                            .school_rounded,
                        color:
                            Colors.white,
                        size: 26,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'RAISONI',
                          style:
                              TextStyle(
                            color:
                                AppColors
                                    .primary,
                            fontSize: 21,
                            fontWeight:
                                FontWeight
                                    .w800,
                            letterSpacing:
                                1.2,
                          ),
                        ),
                        Text(
                          'Education',
                          style:
                              TextStyle(
                            color:
                                AppColors
                                    .accent,
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(
                height:
                    desktop ? 46 : 28,
              ),

              // --------------------------------------------------
              // COLLEGE NAME
              // --------------------------------------------------

              Text(
                'G H Raisoni College\n'
                'of Engineering',
                style: TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      desktop ? 40 : 28,
                  fontWeight:
                      FontWeight.w800,
                  height: 1.16,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // --------------------------------------------------
              // ORANGE LINE
              // --------------------------------------------------

              Container(
                width: 82,
                height: 5,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.accent,
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              Text(
                'Smart Anti-Proxy '
                'Attendance System',
                style: TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      desktop ? 21 : 17,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Text(
                  'Secure and intelligent attendance '
                  'verification using Dynamic QR, '
                  'Geofence, Face Recognition and '
                  'Liveness Verification.',
                  style: TextStyle(
                    color: Colors.white
                        .withValues(
                      alpha: 0.78,
                    ),
                    fontSize:
                        desktop ? 15 : 13,
                    height: 1.55,
                  ),
                ),
              ),

              if (desktop) ...[
                const SizedBox(
                  height: 44,
                ),

                _buildFeature(
                  Icons
                      .qr_code_2_rounded,
                  'Dynamic QR verification',
                ),

                const SizedBox(
                  height: 14,
                ),

                _buildFeature(
                  Icons
                      .location_on_outlined,
                  'Classroom geofence verification',
                ),

                const SizedBox(
                  height: 14,
                ),

                _buildFeature(
                  Icons
                      .face_retouching_natural,
                  'Face & liveness verification',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FEATURE ITEM
  // ============================================================

  Widget _buildFeature(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(
            color: Colors.white
                .withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            icon,
            color:
                AppColors.accent,
            size: 22,
          ),
        ),

        const SizedBox(
          width: 13,
        ),

        Text(
          text,
          style:
              const TextStyle(
            color:
                Colors.white,
            fontSize: 14,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOGIN CARD
  // ============================================================

  Widget _buildLoginCard() {
    return ConstrainedBox(
      constraints:
          const BoxConstraints(
        maxWidth: 460,
      ),
      child: Card(
        elevation: 0,
        child: Padding(
          padding:
              const EdgeInsets.all(
            32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                // ------------------------------------------------
                // LOGIN HEADER
                // ------------------------------------------------

                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .surfaceSoft,
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .lock_person_rounded,
                        color:
                            AppColors.primary,
                        size: 25,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Welcome Back',
                            style:
                                TextStyle(
                              fontSize: 23,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color:
                                  AppColors
                                      .textPrimary,
                            ),
                          ),
                          SizedBox(
                            height: 3,
                          ),
                          Text(
                            'GHRCE Smart Attendance',
                            style:
                                TextStyle(
                              fontSize: 12,
                              color:
                                  AppColors
                                      .textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 30,
                ),

                const Text(
                  'Sign in to your account',
                  style:
                      TextStyle(
                    color:
                        AppColors
                            .textPrimary,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                const Text(
                  'Administrator, faculty and student '
                  'accounts use the same secure login.',
                  style:
                      TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // ------------------------------------------------
                // ERROR MESSAGE
                // ------------------------------------------------

                if (_errorMessage !=
                    null) ...[
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.error
                              .withValues(
                        alpha: 0.07,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                      border:
                          Border.all(
                        color:
                            AppColors.error
                                .withValues(
                          alpha: 0.22,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Icon(
                          Icons
                              .error_outline_rounded,
                          color:
                              AppColors.error,
                          size: 21,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style:
                                const TextStyle(
                              color:
                                  AppColors
                                      .error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                ],

                // ------------------------------------------------
                // EMAIL
                // ------------------------------------------------

                TextFormField(
                  controller:
                      _emailController,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  textInputAction:
                      TextInputAction
                          .next,
                  enabled:
                      !_isLoading,
                  autofillHints:
                      const [
                    AutofillHints
                        .email,
                  ],
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Email address',
                    hintText:
                        'Enter your email',
                    prefixIcon:
                        Icon(
                      Icons
                          .email_outlined,
                    ),
                  ),
                  validator:
                      (value) {
                    final email =
                        value
                                ?.trim() ??
                            '';

                    if (email
                        .isEmpty) {
                      return 'Please enter your email.';
                    }

                    if (!email
                        .contains(
                      '@',
                    )) {
                      return 'Please enter a valid email.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 18,
                ),

                // ------------------------------------------------
                // PASSWORD
                // ------------------------------------------------

                TextFormField(
                  controller:
                      _passwordController,
                  obscureText:
                      _obscurePassword,
                  textInputAction:
                      TextInputAction
                          .done,
                  enabled:
                      !_isLoading,
                  autofillHints:
                      const [
                    AutofillHints
                        .password,
                  ],
                  onFieldSubmitted:
                      (_) {
                    if (!_isLoading) {
                      _login();
                    }
                  },
                  decoration:
                      InputDecoration(
                    labelText:
                        'Password',
                    hintText:
                        'Enter your password',
                    prefixIcon:
                        const Icon(
                      Icons
                          .lock_outline_rounded,
                    ),
                    suffixIcon:
                        IconButton(
                      tooltip:
                          _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                  setState(
                                    () {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    },
                                  );
                                },
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .isEmpty) {
                      return 'Please enter your password.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 28,
                ),

                // ------------------------------------------------
                // SIGN IN BUTTON
                // ------------------------------------------------

                SizedBox(
                  height: 52,
                  child:
                      FilledButton(
                    onPressed:
                        _isLoading
                            ? null
                            : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Icon(
                                Icons
                                    .login_rounded,
                                size: 20,
                              ),
                              SizedBox(
                                width: 9,
                              ),
                              Text(
                                'Sign In',
                                style:
                                    TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),

                // ------------------------------------------------
                // RAISONI ACCENT DIVIDER
                // ------------------------------------------------

                Row(
                  children: [
                    const Expanded(
                      child:
                          Divider(),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                      ),
                      child:
                          Container(
                        width: 9,
                        height: 9,
                        decoration:
                            const BoxDecoration(
                          color:
                              AppColors
                                  .accent,
                          shape:
                              BoxShape
                                  .circle,
                        ),
                      ),
                    ),

                    const Expanded(
                      child:
                          Divider(),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                const Text(
                  'G H Raisoni College of Engineering\n'
                  'Nagpur, Maharashtra',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}