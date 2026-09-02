import 'dart:io';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'razorpay_checkout_types.dart';

RazorpayCheckout createRazorpayCheckout({
  required RazorpaySuccessCallback onSuccess,
  required RazorpayErrorCallback onError,
  required RazorpayExternalWalletCallback onExternalWallet,
  required RazorpayDismissCallback onDismiss,
}) {
  return _MobileRazorpayCheckout(
    onSuccess: onSuccess,
    onError: onError,
    onExternalWallet: onExternalWallet,
  );
}

class _MobileRazorpayCheckout implements RazorpayCheckout {
  _MobileRazorpayCheckout({
    required this.onSuccess,
    required this.onError,
    required this.onExternalWallet,
  }) {
    if (!Platform.isWindows) {
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  final RazorpaySuccessCallback onSuccess;
  final RazorpayErrorCallback onError;
  final RazorpayExternalWalletCallback onExternalWallet;
  Razorpay? _razorpay;

  @override
  Future<void> open({
    required String subscriptionId,
    required String keyId,
    required String? email,
    required String windowsCheckoutPageUrl,
  }) async {
    if (Platform.isWindows) {
      await _openWindowsCheckout(
        subscriptionId: subscriptionId,
        keyId: keyId,
        email: email,
        checkoutPageUrl: windowsCheckoutPageUrl,
      );
      return;
    }

    final razorpay = _razorpay;
    if (razorpay == null) {
      throw UnsupportedError('Razorpay Checkout is not available on this platform.');
    }
    razorpay.open({
      'key': keyId,
      'subscription_id': subscriptionId,
      'name': 'ServeFlow',
      'description': 'Basic monthly subscription (Test Mode)',
      'prefill': {'email': email},
    });
  }

  Future<void> _openWindowsCheckout({
    required String subscriptionId,
    required String keyId,
    required String? email,
    required String checkoutPageUrl,
  }) async {
    final checkoutPage = Uri.tryParse(checkoutPageUrl);
    if (checkoutPage == null || !checkoutPage.hasScheme || !checkoutPage.hasAuthority) {
      throw StateError('Windows checkout is not configured.');
    }
    final values = <String, String>{
      'key_id': keyId,
      'subscription_id': subscriptionId,
      if (email != null && email.isNotEmpty) 'email': email,
    };
    final checkoutUri = checkoutPage.replace(
      fragment: Uri(queryParameters: values).query,
    );
    final opened = await launchUrl(
      checkoutUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Could not open the browser for Razorpay Checkout.');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onSuccess(response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onError(response.message);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onExternalWallet(response.walletName);
  }

  @override
  void dispose() {
    _razorpay?.clear();
  }
}
