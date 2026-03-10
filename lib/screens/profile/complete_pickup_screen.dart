import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/transaction_debug.dart';
import '../../utils/pickup_verification_helper.dart';
import 'verification_success_screen.dart';

class CompletePickupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> donation;

  const CompletePickupScreen({super.key, required this.donation});

  @override
  ConsumerState<CompletePickupScreen> createState() =>
      _CompletePickupScreenState();
}

class _CompletePickupScreenState extends ConsumerState<CompletePickupScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // Refresh to update box borders
  }

  Future<void> _verifyAndComplete() async {
    // Check mounted BEFORE using context
    if (!mounted) return;

    final code = _controllers.map((c) => c.text).join();
    if (code.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter the 4-digit code")),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    // Capture ScaffoldMessenger before any async gaps to avoid "deactivated widget" errors
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Use 'id' or 'donationId' if available
      final donationId = widget.donation['id'] ?? widget.donation['donationId'];
      if (donationId == null) {
        throw Exception("Donation ID not found in record");
      }

      // DEBUG: Log transaction details
      await TransactionDebugHelper.debugTransaction(donationId);

      final currentUserId = ref.read(userIdProvider);
      // Backend uses 'donorId' consistently now
      final donorId = widget.donation['donorId'] ?? widget.donation['userId'];

      if (currentUserId == null) {
        throw Exception("Please log in to verify the pickup");
      }

      if (donorId != null && donorId != currentUserId) {
        debugPrint(
          "ID Mismatch: donation.donorId($donorId) != currentUserId($currentUserId)",
        );
        throw Exception("Only the donor can verify pickup codes");
      }

      // Step 1: Fetch transaction from Firestore using donationId
      // Try different field names that might be used
      debugPrint("=== PICKUP DEBUG ===");
      debugPrint("Looking for transaction with donationId: $donationId");
      debugPrint("Current user ID: $currentUserId");

      // First try: Query by donationId (camelCase)
      var transactionQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('donationId', isEqualTo: donationId)
          .limit(1)
          .get();

      // Second try: Query by donation_id (snake_case) if first fails
      if (transactionQuery.docs.isEmpty) {
        debugPrint(
          "No transaction found with 'donationId', trying 'donation_id'...",
        );
        transactionQuery = await FirebaseFirestore.instance
            .collection('transactions')
            .where('donation_id', isEqualTo: donationId)
            .limit(1)
            .get();
      }

      // Third try: Query all transactions and filter in memory (for debugging)
      if (transactionQuery.docs.isEmpty) {
        debugPrint(
          "No transaction found with either field name. Fetching all transactions...",
        );
        final allTransactions = await FirebaseFirestore.instance
            .collection('transactions')
            .limit(10)
            .get();

        debugPrint("Found ${allTransactions.docs.length} total transactions");
        for (var doc in allTransactions.docs) {
          final data = doc.data();
          debugPrint(
            "Transaction ${doc.id}: donationId=${data['donationId']}, donation_id=${data['donation_id']}, status=${data['payment_status']}",
          );
        }
      }

      if (transactionQuery.docs.isEmpty) {
        throw Exception(
          "No transaction found for this donation. The receiver may not have paid the promise fee yet.",
        );
      }

      final transactionData = transactionQuery.docs.first.data();
      final transactionDonorId = transactionData['donorId'] as String?;
      final paymentStatus = transactionData['payment_status'] as String?;

      debugPrint(
        "Found transaction: donorId=$transactionDonorId, currentUserId=$currentUserId, paymentStatus=$paymentStatus",
      );

      // Check payment status
      if (paymentStatus == 'cancelled') {
        throw Exception("This pickup has already been completed.");
      }

      // Accept both 'authorized' (auth & capture model) and 'captured' (immediate charge model)
      if (paymentStatus != 'authorized' && paymentStatus != 'captured') {
        throw Exception(
          "Invalid transaction status: $paymentStatus. The receiver may not have paid the promise fee yet.",
        );
      }

      // Verify current user is the donor
      if (transactionDonorId != currentUserId) {
        throw Exception(
          "Permission denied. Only the donor can verify this pickup.",
        );
      }
      final transactionPickupCode = transactionData['pickup_code'] as String?;
      final pickupCodeUsed =
          transactionData['pickup_code_used'] as bool? ?? false;
      final expiresAt = transactionData['pickup_code_expires'];

      // Step 2: Validate pickup code
      debugPrint(
        "Validating pickup code: entered='$code', expected='$transactionPickupCode'",
      );

      if (transactionPickupCode == null || transactionPickupCode.isEmpty) {
        throw Exception(
          "Pickup code not found in transaction. Please contact support.",
        );
      }

      if (pickupCodeUsed) {
        throw Exception("This pickup has already been completed.");
      }

      if (transactionPickupCode != code) {
        debugPrint(
          "❌ CODE MISMATCH: entered='$code' != expected='$transactionPickupCode'",
        );
        throw Exception(
          "Invalid pickup code. Please check with the receiver and try again.",
        );
      }

      debugPrint("✅ Pickup code validated successfully");
      debugPrint("📞 Calling Cloud Function verifyPickupCode...");
      debugPrint("   donationId: $donationId");
      debugPrint("   pickupCode: $code");
      debugPrint("   currentUserId: $currentUserId");

      // Step 3: Check expiration
      if (expiresAt != null) {
        DateTime expiry;
        if (expiresAt is Timestamp) {
          expiry = expiresAt.toDate();
        } else {
          expiry = DateTime.now().add(const Duration(hours: 24));
        }

        if (DateTime.now().isAfter(expiry)) {
          throw Exception("This pickup code has expired");
        }
      }

      // Step 4: Call Cloud Function to verify and complete
      debugPrint("🔐 Authentication check before Cloud Function call:");
      debugPrint("   User authenticated: ${currentUserId != null}");
      debugPrint("   User UID: $currentUserId");

      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('verifyPickupCode');

      debugPrint("📤 Sending request to Cloud Function...");

      final result = await callable.call({
        'donationId': donationId,
        'pickupCode': code,
      });

      final data = result.data;
      bool success = false;
      String? message;

      if (data is Map) {
        success = data['success'] == true;
        message = data['message'];
      }

      if (success) {
        if (mounted) {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VerificationSuccessScreen(donation: widget.donation),
            ),
          );
        }
      } else {
        throw Exception(
          message ?? "Invalid verification code. Please try again.",
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("❌ FirebaseFunctionsException:");
      debugPrint("   Code: ${e.code}");
      debugPrint("   Message: ${e.message}");
      debugPrint("   Details: ${e.details}");

      // FALLBACK: If Cloud Function fails with permission-denied, try direct verification
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        debugPrint("🔄 Cloud Function failed, trying direct verification...");

        try {
          final donationId =
              widget.donation['id'] ?? widget.donation['donationId'];
          final currentUserId = ref.read(userIdProvider);

          if (donationId != null && currentUserId != null) {
            final code = _controllers.map((c) => c.text).join();

            await PickupVerificationHelper.verifyPickupDirectly(
              donationId: donationId,
              pickupCode: code,
              userId: currentUserId,
            );

            // Success! Navigate to success screen
            if (mounted) {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VerificationSuccessScreen(donation: widget.donation),
                ),
              );
            }
            return; // Exit early on success
          }
        } catch (directError) {
          debugPrint("❌ Direct verification also failed: $directError");
          // Continue to show original error below
        }
      }

      if (mounted) {
        String errorMsg = "Verification failed";

        if (e.code == 'permission-denied') {
          errorMsg =
              "Permission denied. The Cloud Function rejected your call.\n\nPlease check:\n1. You're logged in as the donor\n2. The donation's donorId matches your user ID\n3. Try the 'Use Direct Verification' button below.";
        } else if (e.code == 'unauthenticated') {
          errorMsg = "Please log in to verify the pickup.";
        } else if (e.code == 'invalid-argument') {
          errorMsg = "Invalid pickup code. Please check with the receiver.";
        } else if (e.code == 'not-found') {
          errorMsg =
              "No pending pickup found. The transaction may have expired.";
        } else if (e.code == 'failed-precondition') {
          errorMsg = "This pickup code has expired. Please contact support.";
        } else if (e.code == 'already-exists') {
          errorMsg = "This pickup has already been completed.";
        } else if (e.message != null) {
          errorMsg = e.message!;
        }

        messenger.showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.donation['title'] ?? "Item";
    final area =
        widget.donation['area'] ??
        widget.donation['location_name'] ??
        "Unknown Location";
    final images = widget.donation['images'] as List?;
    final imageUrl = (images != null && images.isNotEmpty) ? images.first : "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Complete Pickup",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Item Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Pickup from $area",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_open,
                color: Color(0xFF4CAF50),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Ask the receiver:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "\"What is your pickup code?\"",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // OTP Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _buildOtpBox(index)),
            ),
            const SizedBox(height: 100),

            // Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF7CFF7C,
                  ), // Match design's neon green
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        "VERIFY & COMPLETE",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              child: const Text(
                "Having trouble with the code?",
                style: TextStyle(
                  color: Colors.grey,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Direct Verification Button (bypasses Cloud Function)
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final code = _controllers.map((c) => c.text).join();
                      if (code.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please enter the 4-digit code"),
                          ),
                        );
                        return;
                      }

                      setState(() => _isLoading = true);

                      try {
                        final donationId =
                            widget.donation['id'] ??
                            widget.donation['donationId'];
                        final currentUserId = ref.read(userIdProvider);

                        if (donationId == null || currentUserId == null) {
                          throw Exception("Missing donation ID or user ID");
                        }

                        await PickupVerificationHelper.verifyPickupDirectly(
                          donationId: donationId,
                          pickupCode: code,
                          userId: currentUserId,
                        );

                        if (mounted) {
                          await Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VerificationSuccessScreen(
                                donation: widget.donation,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Direct verification failed: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              child: const Text(
                "⚠️ Use Direct Verification (bypass Cloud Function)",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // DEBUG: Show donation details
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DEBUG INFO",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final currentUserId = ref.watch(userIdProvider);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Donation ID: ${widget.donation['id'] ?? widget.donation['donationId'] ?? 'N/A'}",
                          ),
                          Text(
                            "Donation donorId: ${widget.donation['donorId'] ?? 'N/A'}",
                          ),
                          Text(
                            "Donation userId: ${widget.donation['userId'] ?? 'N/A'}",
                          ),
                          Text(
                            "Current User: ${currentUserId ?? 'Not logged in'}",
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Match: ${(widget.donation['donorId'] ?? widget.donation['userId']) == currentUserId ? '✅ YES' : '❌ NO'}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  (widget.donation['donorId'] ??
                                          widget.donation['userId']) ==
                                      currentUserId
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final bool hasValue = _controllers[index].text.isNotEmpty;
    return Container(
      width: 64,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? const Color(0xFF4CAF50) : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (val) => _onChanged(val, index),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
      ),
    );
  }
}
