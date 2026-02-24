import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class DonationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> donation;

  // If provided (or present as donation['id']), the screen fetches the latest
  // donation data from Firestore.
  final String? donationId;

  const DonationDetailScreen({
    super.key,
    required this.donation,
    this.donationId,
  });

  @override
  State<DonationDetailScreen> createState() => _DonationDetailScreenState();
}

class _DonationDetailScreenState extends State<DonationDetailScreen> {
  final PageController _pageController = PageController();
  int _activeImageIndex = 0;
  bool _expandedDescription = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _donationStream;

  String? get _id {
    final fromParam = widget.donationId;
    if (fromParam != null && fromParam.trim().isNotEmpty) return fromParam;
    final fromMap = widget.donation['id'];
    if (fromMap is String && fromMap.trim().isNotEmpty) return fromMap;
    return null;
  }

  @override
  void initState() {
    super.initState();
    final id = _id;
    if (id != null) {
      // Initialize stream once to prevent "refreshing" on every build
      _donationStream = FirebaseFirestore.instance
          .collection('donations')
          .doc(id)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is Map) {
      final seconds = value['_seconds'];
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
  }

  String _expiryLabel(Map<String, dynamic> d) {
    DateTime? end;

    final pickupWindow = d['pickup_window'];
    if (pickupWindow is Map) {
      end = _toDate(pickupWindow['end_date']);
    }
    end ??= _toDate(d['expiry_date']);
    if (end == null) return '';

    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';

    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h >= 1) return 'Expires in ${h}h ${m}m';
    return 'Expires in ${diff.inMinutes}m';
  }

  List<String> _imagesFrom(Map<String, dynamic> d) {
    final raw = d['images'];
    if (raw is List) {
      return raw.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (_donationStream != null) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _donationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data?.data();
          if (data == null && !snapshot.hasData) {
            return const Scaffold(
              body: Center(child: Text('Donation not found')),
            );
          }
          final merged = <String, dynamic>{'id': _id, ...(data ?? widget.donation)};
          return _buildUI(context, merged);
        },
      );
    }

    return _buildUI(context, widget.donation);
  }

  Widget _buildUI(BuildContext context, Map<String, dynamic> d) {
    final images = _imagesFrom(d);
    final title = (d['title'] ?? 'Donation').toString();
    final category = (d['category'] ?? 'other').toString();
    final condition = (d['condition'] ?? 'good').toString();
    final description = (d['description'] ?? '').toString();

    final expiry = _expiryLabel(d);
    final donorName = (d['donorName'] ?? d['donor_name'] ?? 'Donor').toString();
    final donorKarma = d['donorKarma'] ?? d['karma'] ?? 50;
    final distance = d['distance'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    _roundIcon(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _roundIcon(icon: Icons.share_outlined, onTap: () {}),
                    const SizedBox(width: 10),
                    _roundIcon(
                      icon: Icons.favorite,
                      onTap: () {},
                      filled: true,
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _imageCarousel(images),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _thumbnailRow(images),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    const Text(
                      'Free',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (expiry.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expiry,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _donorCard(donorName: donorName, donorKarma: donorKarma),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: const Text(
                  'Item Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _detailsGrid(
                  category: category,
                  condition: condition,
                  quantity: d['food_quantity'] ?? d['quantity'] ?? 1,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _descriptionBlock(description),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1C1E),
                        ),
                      ),
                    ),
                    if (distance is num)
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _hiddenLocationCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context, d),
    );
  }

  Widget _roundIcon({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? const Color(0xFFE53935) : const Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _imageCarousel(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            if (images.isNotEmpty)
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _activeImageIndex = i),
                itemBuilder: (context, i) => Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 40),
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 40),
                ),
              ),

            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, size: 14, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == _activeImageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
              ),

            if (images.length > 1)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailRow(List<String> images) {
    if (images.isEmpty) return const SizedBox(height: 68);
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length.clamp(0, 8),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final active = i == _activeImageIndex;
          return InkWell(
            onTap: () {
              // Only animate if not already active to prevent jitter
              if (_activeImageIndex != i) {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFF22C55E) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _donorCard({required String donorName, required dynamic donorKarma}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, color: Color(0xFF111827)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        donorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$donorKarma Karma',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '4.8 (24 reviews)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              'View Profile',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsGrid({
    required String category,
    required String condition,
    required dynamic quantity,
  }) {
    Widget tile({
      required String label,
      required String value,
      required IconData icon,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final qty = quantity is num ? quantity.toString() : quantity.toString();

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        tile(
          label: 'CATEGORY',
          value: _pretty(category),
          icon: Icons.category_outlined,
        ),
        tile(
          label: 'CONDITION',
          value: _pretty(condition),
          icon: Icons.verified_outlined,
        ),
        tile(
          label: 'QUANTITY',
          value: '$qty Unit',
          icon: Icons.inventory_2_outlined,
        ),
        tile(label: 'PICKUP', value: 'Today, 6-9 PM', icon: Icons.access_time),
      ],
    );
  }

  String _pretty(String v) {
    if (v.isEmpty) return v;
    final s = v.replaceAll('_', ' ').trim();
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  Widget _descriptionBlock(String description) {
    if (description.trim().isEmpty) {
      return const Text(
        'No description provided.',
        style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
      );
    }

    final text = description.trim();
    final maxLines = _expandedDescription ? 20 : 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF374151),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () =>
                setState(() => _expandedDescription = !_expandedDescription),
            child: Text(
              _expandedDescription ? 'Read less' : 'Read more',
              style: const TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hiddenLocationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 170,
            width: double.infinity,
            color: Colors.black.withOpacity(0.06),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.network(
                      'https://via.placeholder.com/800x400',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Column(
                    children: const [
                      Text(
                        'Location Hidden',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Exact address revealed after\n Platform fee payment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Icon(
              Icons.place_outlined,
              size: 16,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Approximate Location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, Map<String, dynamic> donation) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.firebaseUser?.uid;
    final donorId = donation['donorId'] ?? donation['userId'];
    final isPostedByMe = currentUserId != null && currentUserId == donorId;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.chat_bubble_outline, color: Color(0xFF111827)),
                    SizedBox(height: 2),
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!isPostedByMe)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/reserve-item',
                        arguments: donation,
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Claim Item  →',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'PAY ₹9 PLATFORM FEE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Text(
                    'This is your donation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
