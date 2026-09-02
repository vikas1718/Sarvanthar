typedef RazorpaySuccessCallback = void Function(String? paymentId);
typedef RazorpayErrorCallback = void Function(String? message);
typedef RazorpayExternalWalletCallback = void Function(String? walletName);
typedef RazorpayDismissCallback = void Function();

abstract interface class RazorpayCheckout {
  Future<void> open({
    required String subscriptionId,
    required String keyId,
    required String? email,
    required String windowsCheckoutPageUrl,
  });

  void dispose();
}
