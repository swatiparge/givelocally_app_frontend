import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../chat/chat_screen.dart';

final _apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final transactionDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((
      ref,
      transactionId,
    ) async {
      if (transactionId.isEmpty) return null;
      final api = ref.watch(_apiServiceProvider);
      return await api.getTransaction(transactionId);
    });

final transactionByDonationProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((
      ref,
      donationId,
    ) async {
      if (donationId.isEmpty) return null;
      final api = ref.watch(_apiServiceProvider);
      return await api.getTransactionByDonation(donationId);
    });

final donorDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, donorId) async {
      if (donorId.isEmpty) return null;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(donorId)
            .get();
        return doc.data();
      } catch (e) {
        debugPrint("Error fetching donor details: $e");
        return null;
      }
    });

class PickupCodeScreen extends ConsumerWidget {
  final Map<String, dynamic> initialData;

  const PickupCodeScreen({super.key, required this.initialData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionId = _extractTransactionId(initialData);
    final donationId =
        initialData['donationId']?.toString() ??
        initialData['donation_id']?.toString() ??
        '';
    final donorId =
        initialData['donorId']?.toString() ??
        initialData['donor_id']?.toString() ??
        '';

    debugPrint("PICKUP_CODE_SCREEN: transactionId = $transactionId");
    debugPrint("PICKUP_CODE_SCREEN: donationId = $donationId");
    debugPrint("PICKUP_CODE_SCREEN: donorId = $donorId");

    // Fetch transaction data from Cloud Function
    final transactionAsync = transactionId.isNotEmpty
        ? ref.watch(transactionDataProvider(transactionId))
        : donationId.isNotEmpty
        ? ref.watch(transactionByDonationProvider(donationId))
        : AsyncValue.data(null);

    final donorAsync = ref.watch(donorDetailsProvider(donorId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, ref, initialData),
      body: transactionAsync.when(
        data: (transactionData) {
          debugPrint("PICKUP_CODE_SCREEN: transactionData = $transactionData");

          // Merge initialData with transactionData (transactionData has priority)
          final mergedData = {
            ...initialData,
            if (transactionData != null) ...transactionData,
          };

          debugPrint(
            "PICKUP_CODE_SCREEN: mergedData pickup_code = ${mergedData['pickup_code']}",
          );

          return _PickupCodeContent(
            data: mergedData,
            donorData: donorAsync.valueOrNull,
            isSyncing: false,
          );
        },
        loading: () => _PickupCodeContent(
          data: initialData,
          donorData: donorAsync.valueOrNull,
          isSyncing: true,
        ),
        error: (error, stack) {
          debugPrint("PICKUP_CODE_SCREEN: Error fetching transaction: $error");
          // Show content with initialData even on error
          return _PickupCodeContent(
            data: initialData,
            donorData: donorAsync.valueOrNull,
            isSyncing: false,
          );
        },
      ),
    );
  }

  String _extractTransactionId(Map<String, dynamic> data) {
    return data['id']?.toString() ??
        data['transactionId']?.toString() ??
        data['transaction_id']?.toString() ??
        data['documentId']?.toString() ??
        '';
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    final donationId =
        data['donationId']?.toString() ?? data['donation_id']?.toString();
    final title = data['donationTitle'] ?? data['title'] ?? "Item";

    // Try multiple image field names - check for 'images' array first
    String imageUrl = "";
    final imagesArray = data['images'] ?? data['donationImages'];
    if (imagesArray is List && imagesArray.isNotEmpty) {
      imageUrl = imagesArray[0]?.toString() ?? "";
    }
    if (imageUrl.isEmpty) {
      imageUrl =
          data['donationImage']?.toString() ?? data['image']?.toString() ?? "";
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "Pickup Details",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        if (donationId != null && donationId.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            onPressed: () =>
                _navigateToChat(context, ref, donationId, title, imageUrl),
          ),
      ],
      centerTitle: true,
    );
  }

  void _navigateToChat(
    BuildContext context,
    WidgetRef ref,
    String donationId,
    String title,
    String imageUrl,
  ) {
    final currentUserId = ref.read(userIdProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          donationId: donationId,
          itemName: title,
          itemImage: imageUrl,
          requesterId: currentUserId,
        ),
      ),
    );
  }
}

class _PickupCodeContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? donorData;
  final bool isSyncing;

  const _PickupCodeContent({
    required this.data,
    this.donorData,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final pickupCode = _extractPickupCode(data);
    final timeRemaining = _getTimeRemaining(data);
    final title = data['donationTitle'] ?? data['title'] ?? "Item";
    final category = data['category'] ?? "Item";

    // Try multiple image field names - check for 'images' array first
    String imageUrl = "";
    final imagesArray = data['images'] ?? data['donationImages'];
    if (imagesArray is List && imagesArray.isNotEmpty) {
      imageUrl = imagesArray[0]?.toString() ?? "";
    }
    if (imageUrl.isEmpty) {
      imageUrl =
          data['donationImage']?.toString() ?? data['image']?.toString() ?? "";
    }

    final address =
        data['pickupAddress'] ?? data['address'] ?? "Address in chat";
    final donorName =
        donorData?['name'] ??
        data['donor_name'] ??
        data['donorName'] ??
        "Donor";
    final donorPhoto =
        donorData?['profilePicture'] ??
        data['donor_image'] ??
        data['donorPhotoUrl'] ??
        "";
    final donationId =
        data['donationId']?.toString() ?? data['donation_id']?.toString();

    debugPrint("PICKUP_CODE_CONTENT: data keys = ${data.keys.toList()}");
    debugPrint(
      "PICKUP_CODE_CONTENT: pickup_code field = ${data['pickup_code']}",
    );
    debugPrint("PICKUP_CODE_CONTENT: extracted pickupCode = $pickupCode");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildConfirmationHeader(),
          const SizedBox(height: 40),
          _PickupCodeCard(
            pickupCode: pickupCode,
            timeRemaining: timeRemaining,
            isSyncing: isSyncing && pickupCode == null,
            onCopy: () => _copyCode(context, pickupCode),
            onShare: () => _shareDetails(context, title, pickupCode, address),
          ),
          const SizedBox(height: 24),
          _DonorCard(
            donorName: donorName,
            donorPhoto: donorPhoto,
            address: address,
            donationId: donationId,
            itemName: title,
            itemImage: imageUrl,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildConfirmationHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF4CAF50), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            "Reservation Confirmed",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Show this code to the donor at pickup",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String? _extractPickupCode(Map<String, dynamic> data) {
    debugPrint(
      "PICKUP_CODE: _extractPickupCode called with keys: ${data.keys.toList()}",
    );
    debugPrint("PICKUP_CODE: pickup_code raw value: ${data['pickup_code']}");
    debugPrint(
      "PICKUP_CODE: pickup_code type: ${data['pickup_code'].runtimeType}",
    );

    final possibleFields = [
      'pickup_code',
      'pickup_otp',
      'pickupCode',
      'verification_code',
      'verificationCode',
      'code',
      'otp',
    ];

    for (final field in possibleFields) {
      final value = data[field];
      if (value != null) {
        final stringValue = value.toString();
        debugPrint(
          "PICKUP_CODE: Checking field '$field', value: $value, stringValue: $stringValue",
        );
        if (stringValue.isNotEmpty &&
            stringValue != '0' &&
            stringValue != 'null') {
          debugPrint(
            "PICKUP_CODE: Found valid code in field '$field': $stringValue",
          );
          return stringValue;
        }
      }
    }

    debugPrint("PICKUP_CODE: No valid code found in data");
    return null;
  }

  String _getTimeRemaining(Map<String, dynamic> data) {
    final expiresAt =
        data['pickup_code_expires'] ??
        data['expires_at'] ??
        data['verification_code_expires'] ??
        data['authorization_expires'] ??
        data['pickup_otp_expires'];

    if (expiresAt == null) return "23h 59m";

    DateTime? expiry;
    if (expiresAt is Timestamp) {
      expiry = expiresAt.toDate();
    } else if (expiresAt is String) {
      expiry = DateTime.tryParse(expiresAt);
    } else if (expiresAt is Map && expiresAt['_seconds'] != null) {
      expiry = DateTime.fromMillisecondsSinceEpoch(
        expiresAt['_seconds'] * 1000,
      );
    }

    if (expiry == null) return "23h 59m";

    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return "Expired";

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  void _copyCode(BuildContext context, String? code) {
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Code copied to clipboard")));
  }

  void _shareDetails(
    BuildContext context,
    String title,
    String? code,
    String address,
  ) {
    if (code == null || code.isEmpty) return;
    final text =
        "My GiveLocally Pickup Code for $title is: $code\n\nPickup Address: $address";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Details copied for sharing")));
  }
}

class _PickupCodeCard extends StatelessWidget {
  final String? pickupCode;
  final String timeRemaining;
  final bool isSyncing;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _PickupCodeCard({
    required this.pickupCode,
    required this.timeRemaining,
    required this.isSyncing,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F1F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "YOUR PICKUP CODE",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          else if (pickupCode == null)
            const Text(
              "----",
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Colors.grey,
              ),
            )
          else
            Text(
              pickupCode!.split('').join(' '),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFFE65100),
                ),
                const SizedBox(width: 4),
                Text(
                  "Valid for: $timeRemaining",
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pickupCode != null ? onCopy : null,
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: pickupCode != null ? onShare : null,
                  icon: const Icon(Icons.share),
                  label: const Text("Share"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  final String donorName;
  final String donorPhoto;
  final String address;
  final String? donationId;
  final String itemName;
  final String itemImage;

  const _DonorCard({
    required this.donorName,
    required this.donorPhoto,
    required this.address,
    this.donationId,
    required this.itemName,
    required this.itemImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: donorPhoto.isNotEmpty
                    ? NetworkImage(donorPhoto)
                    : null,
                child: donorPhoto.isEmpty
                    ? const Icon(Icons.person, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pickup from",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      donorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(address, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: itemImage.isNotEmpty
                    ? Image.network(
                        itemImage,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.inventory_2, size: 24),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.inventory_2, size: 24),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  itemName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
