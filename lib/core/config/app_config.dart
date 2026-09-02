class AppConfig {
  AppConfig._();

  // ============================================================
  // API BASE URL
  // ============================================================
  //
  // Production backend via Cloudflare Worker:
  // https://smart-attendance-api.kumudparate269.workers.dev/api
  //
  // The URL can still be overridden using --dart-define.
  //
  // ============================================================

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://smart-attendance-api.kumudparate269.workers.dev/api',
  );
}