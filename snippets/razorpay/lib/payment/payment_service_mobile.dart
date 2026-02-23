// Stub file for mobile - exports the openRazorpayWeb function that does nothing
// This file is used when compiling for mobile platforms (iOS/Android)

void openRazorpayWeb({
  required String key,
  required int amount,
  required String orderId,
  required String name,
  required String description,
  required String email,
  required String phone,
  required String themeColor,
  required Function(String) onSuccess,
  required Function(String) onError,
}) {
  // This should never be called on mobile
  throw UnsupportedError('openRazorpayWeb is only supported on web platform');
}
