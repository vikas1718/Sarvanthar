class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Destination for Supabase email-auth callbacks, including staff
  /// invitation magic links. Override this for each deployed environment.
  static const authEmailRedirectUrl = String.fromEnvironment(
    'AUTH_EMAIL_REDIRECT_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Origin of the customer-facing scan destination.
  ///
  /// Placeholder until the separate Next.js project exists. Override with
  /// --dart-define=QR_SCAN_BASE_URL=https://real-domain once it is deployed;
  /// tokens already printed keep working because only the origin changes.
  static const qrScanBaseUrl = String.fromEnvironment(
    'QR_SCAN_BASE_URL',
    defaultValue: 'https://scan.serveflow.app',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static String qrScanUrl(String token) => '$qrScanBaseUrl/scan/$token';
}
