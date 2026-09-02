import 'razorpay_checkout_mobile.dart'
    if (dart.library.html) 'razorpay_checkout_web.dart' as platform;
import 'razorpay_checkout_types.dart';

export 'razorpay_checkout_types.dart';

RazorpayCheckout createRazorpayCheckout({
  required RazorpaySuccessCallback onSuccess,
  required RazorpayErrorCallback onError,
  required RazorpayExternalWalletCallback onExternalWallet,
  required RazorpayDismissCallback onDismiss,
}) {
  return platform.createRazorpayCheckout(
    onSuccess: onSuccess,
    onError: onError,
    onExternalWallet: onExternalWallet,
    onDismiss: onDismiss,
  );
}
