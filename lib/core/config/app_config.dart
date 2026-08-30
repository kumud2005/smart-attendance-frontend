class AppConfig {
  AppConfig._();

  // ============================================================
  // API BASE URL
  // ============================================================
  //
  // Production backend:
  // https://smart-attendance-backend-production-355a.up.railway.app/api
  //
  // The URL can still be overridden using --dart-define.
  //
  // ============================================================

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://smart-attendance-backend-production-355a.up.railway.app/api',
  );
}