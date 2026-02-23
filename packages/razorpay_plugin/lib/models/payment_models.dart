/// Configuration for Razorpay Auth Capture Plugin
class RazorpayConfig {
  /// Razorpay API Key ID (Test or Live)
  final String keyId;

  /// Amount to hold in paise (e.g., 5000 for ₹50)
  final int amount;

  /// Currency code (default: INR)
  final String currency;

  /// Merchant name shown in checkout
  final String merchantName;

  /// Description shown in checkout
  final String description;

  /// Firebase Cloud Function region
  final String functionRegion;

  /// Theme color for checkout (hex without #)
  final String themeColor;

  /// Enable UPI payment
  final bool enableUPI;

  /// Enable Cards
  final bool enableCards;

  /// Enable Netbanking
  final bool enableNetbanking;

  /// Enable Wallets
  final bool enableWallets;

  /// Callback URL for webhook (optional)
  final String? webhookUrl;

  const RazorpayConfig({
    required this.keyId,
    this.amount = 5000,
    this.currency = 'INR',
    required this.merchantName,
    this.description = 'Promise Fee (Refundable)',
    this.functionRegion = 'asia-southeast1',
    this.themeColor = '4CAF50',
    this.enableUPI = true,
    this.enableCards = true,
    this.enableNetbanking = true,
    this.enableWallets = true,
    this.webhookUrl,
  });

  /// Validate configuration
  bool get isValid {
    return keyId.isNotEmpty &&
        keyId.startsWith('rzp_') &&
        merchantName.isNotEmpty &&
        amount > 0;
  }
}

/// Payment status enum
enum PaymentStatus {
  authorized, // Money held, not deducted
  captured, // Money deducted (forfeited)
  cancelled, // Money released (refunded)
  expired, // Authorization expired
  failed, // Payment failed
}

/// Transaction model
class RazorpayTransaction {
  final String transactionId;
  final String orderId;
  final String paymentId;
  final String donationId;
  final String donorId;
  final String receiverId;
  final int amount;
  final PaymentStatus status;
  final String? pickupCode;
  final DateTime? pickupCodeExpires;
  final DateTime createdAt;
  final DateTime? completedAt;

  RazorpayTransaction({
    required this.transactionId,
    required this.orderId,
    required this.paymentId,
    required this.donationId,
    required this.donorId,
    required this.receiverId,
    required this.amount,
    required this.status,
    this.pickupCode,
    this.pickupCodeExpires,
    required this.createdAt,
    this.completedAt,
  });

  factory RazorpayTransaction.fromFirestore(
      Map<String, dynamic> data, String id) {
    return RazorpayTransaction(
      transactionId: id,
      orderId: data['razorpay_order_id'] ?? '',
      paymentId: data['razorpay_payment_id'] ?? '',
      donationId: data['donationId'] ?? '',
      donorId: data['donorId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      amount: data['promise_fee'] ?? 0,
      status: _parseStatus(data['payment_status']),
      pickupCode: data['pickup_code'],
      pickupCodeExpires: data['pickup_code_expires']?.toDate(),
      createdAt: data['created_at']?.toDate() ?? DateTime.now(),
      completedAt: data['pickup_completed_at']?.toDate(),
    );
  }

  static PaymentStatus _parseStatus(String? status) {
    switch (status) {
      case 'authorized':
        return PaymentStatus.authorized;
      case 'captured':
        return PaymentStatus.captured;
      case 'cancelled':
        return PaymentStatus.cancelled;
      case 'expired':
        return PaymentStatus.expired;
      default:
        return PaymentStatus.failed;
    }
  }
}

/// Callback types
typedef PaymentSuccessCallback = void Function(String paymentId);
typedef PaymentErrorCallback = void Function(String error);
typedef PickupVerifyCallback = void Function(bool success, String? error);
