import 'dart:js_util' as js_util;

import 'package:js/js.dart';

import 'razorpay_checkout_types.dart';

RazorpayCheckout createRazorpayCheckout({
  required RazorpaySuccessCallback onSuccess,
  required RazorpayErrorCallback onError,
  required RazorpayExternalWalletCallback onExternalWallet,
  required RazorpayDismissCallback onDismiss,
}) {
  return _WebRazorpayCheckout(
    onSuccess: onSuccess,
    onError: onError,
    onDismiss: onDismiss,
  );
}

class _WebRazorpayCheckout implements RazorpayCheckout {
  _WebRazorpayCheckout({
    required this.onSuccess,
    required this.onError,
    required this.onDismiss,
  });

  final RazorpaySuccessCallback onSuccess;
  final RazorpayErrorCallback onError;
  final RazorpayDismissCallback onDismiss;

  @override
  Future<void> open({
    required String subscriptionId,
    required String keyId,
    required String? email,
    required String windowsCheckoutPageUrl,
  }) async {
    final razorpayConstructor = js_util.getProperty<Object?>(
      js_util.globalThis,
      'Razorpay',
    );
    if (razorpayConstructor == null) {
      throw StateError('Razorpay Checkout failed to load. Please refresh and try again.');
    }

    final options = js_util.jsify({
      'key': keyId,
      'subscription_id': subscriptionId,
      'name': 'ServeFlow',
      'description': 'Basic monthly subscription (Test Mode)',
      'prefill': {'email': email},
      'theme': {'color': '#f29a28'},
    });
    js_util.setProperty(
      options,
      'handler',
      allowInterop((Object? response) {
        onSuccess(js_util.getProperty<String?>(response!, 'razorpay_payment_id'));
      }),
    );
    js_util.setProperty(
      options,
      'modal',
      js_util.jsify({
        'ondismiss': allowInterop(onDismiss),
      }),
    );

    final checkout = js_util.callConstructor<Object>(razorpayConstructor, [options]);
    js_util.callMethod<void>(checkout, 'on', [
      'payment.failed',
      allowInterop((Object? response) {
        final error = js_util.getProperty<Object?>(response!, 'error');
        onError(error == null ? null : js_util.getProperty<String?>(error, 'description'));
      }),
    ]);
    js_util.callMethod<void>(checkout, 'open', const []);
  }

  @override
  void dispose() {}
}
