import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'razorpay_checkout_types.dart';

@JS('Razorpay')
external JSFunction? get _razorpayConstructor;

@JS()
extension type _RazorpayPaymentResponse._(JSObject _) implements JSObject {
  @JS('razorpay_payment_id')
  external JSString? get paymentId;
}

@JS()
extension type _RazorpayFailureResponse._(JSObject _) implements JSObject {
  external _RazorpayError? get error;
}

@JS()
extension type _RazorpayError._(JSObject _) implements JSObject {
  external JSString? get description;
}

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
    final razorpayConstructor = _razorpayConstructor;
    if (razorpayConstructor == null) {
      throw StateError(
        'Razorpay Checkout failed to load. Please refresh and try again.',
      );
    }

    final prefill = JSObject()..['email'] = email?.toJS;
    final options = JSObject()
      ..['key'] = keyId.toJS
      ..['subscription_id'] = subscriptionId.toJS
      ..['name'] = 'ServeFlow'.toJS
      ..['description'] = 'Basic monthly subscription (Test Mode)'.toJS
      ..['prefill'] = prefill
      ..['theme'] = (JSObject()..['color'] = '#f29a28'.toJS)
      ..['handler'] = ((_RazorpayPaymentResponse? response) {
        onSuccess(response?.paymentId?.toDart);
      }).toJS
      ..['modal'] = (JSObject()..['ondismiss'] = onDismiss.toJS);

    final checkout = razorpayConstructor.callAsConstructor<JSObject>(options);
    checkout.callMethod<JSAny?>('on'.toJS, 'payment.failed'.toJS, ((
      _RazorpayFailureResponse? response,
    ) {
      onError(response?.error?.description?.toDart);
    }).toJS);
    checkout.callMethod<JSAny?>('open'.toJS);
  }

  @override
  void dispose() {}
}
