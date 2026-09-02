import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get supabaseUrl => _value('SUPABASE_URL');
  static String get supabasePublishableKey =>
      _value('SUPABASE_PUBLISHABLE_KEY');

  /// Destination for Supabase email-auth callbacks, including staff
  /// invitation magic links. Override this for each deployed environment.
  static String get authEmailRedirectUrl =>
      _value('AUTH_EMAIL_REDIRECT_URL', 'http://localhost:8080');

  /// Origin of the customer-facing scan destination.
  ///
  /// Placeholder until the separate Next.js project exists. Set this in
  /// `.env` once it is deployed; tokens already printed keep working because
  /// only the origin changes.
  static String get qrScanBaseUrl =>
      _value('QR_SCAN_BASE_URL', 'https://scan.serveflow.app');

  /// Hosted copy of web/razorpay_checkout.html used by the Windows app.
  /// Configure this in Windows release builds; the page must be served over
  /// HTTPS from an origin enabled for the Razorpay key.
  static String get razorpayCheckoutPageUrl =>
      _value('RAZORPAY_CHECKOUT_PAGE_URL');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static String qrScanUrl(String token) => '$qrScanBaseUrl/scan/$token';

  static String _value(String key, [String fallback = '']) =>
      dotenv.env[key]?.trim() ?? fallback;
}
