import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import '../chat/chat_screen.dart';

class DonationDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> donation;
  const DonationDetailScreen({super.key, required this.donation});

  @override
  ConsumerState<DonationDetailScreen> createState() =>
      _DonationDetailScreenState();
}

class _DonationDetailScreenState extends ConsumerState<DonationDetailScreen> {
  late PageController _pageController;
  int _activeImageIndex = 0;
  bool _expandedDescription = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? get _id => widget.donation['id']?.toString();

  List<String> _imagesFrom(Map<String, dynamic> d) {
    final imgs = d['images'];
    if (imgs is List) return imgs.map((e) => e.toString()).toList();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    final images = _imagesFrom(d);

    final currentUserId = ref.watch(userIdProvider);
    final donorId = d['donorId'] ?? d['userId'];
    final isPostedByMe = currentUserId != null && currentUserId == donorId;

    // Use current user's name if it's their donation
    final String donorName = isPostedByMe
        ? (ref.watch(userNameProvider) ?? "You")
        : (d['donorName'] ??
              d['donor_name'] ??
              d['userName'] ??
              d['username'] ??
              d['name'] ??
              'Anonymous Donor');

    final String donorImage = isPostedByMe
        ? (ref.watch(userProfilePictureProvider) ?? "")
        : (d['donorImage'] ?? d['userImage'] ?? d['profilePicture'] ?? "");

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, images),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _donorCard(
                    donorName: donorName,
                    donorKarma: d['donorKarma'] ?? 0,
                    donorImage: donorImage,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    d['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _detailsGrid(
                    category: d['category'] ?? 'Other',
                    condition: d['condition'] ?? 'Used',
                    quantity: d['quantity'] ?? 1,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _descriptionBlock(d['description'] ?? ''),
                  const SizedBox(height: 24),
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _hiddenLocationCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(context, d, isPostedByMe, currentUserId),
    );
  }

  Widget _buildAppBar(BuildContext context, List<String> images) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _activeImageIndex = i),
              itemCount: images.isEmpty ? 1 : images.length,
              itemBuilder: (context, i) {
                if (images.isEmpty) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                }
                return Image.network(images[i], fit: BoxFit.cover);
              },
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _thumbnailRow(images),
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

  Widget _donorCard({
    required String donorName,
    required dynamic donorKarma,
    String? donorImage,
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
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: donorImage != null && donorImage.isNotEmpty
                ? NetworkImage(donorImage)
                : null,
            child: donorImage == null || donorImage.isEmpty
                ? const Icon(Icons.person, color: Color(0xFF111827))
                : null,
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
            Icon(Icons.place_outlined, size: 16, color: Color(0xFF6B7280)),
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

  Widget _bottomBar(
    BuildContext context,
    Map<String, dynamic> d,
    bool isPostedByMe,
    String? currentUserId,
  ) {
    final images = _imagesFrom(d);

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
            if (!isPostedByMe) ...[
              SizedBox(
                width: 56,
                height: 56,
                child: InkWell(
                  onTap: () {
                    final id = _id;
                    if (id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            donationId: id,
                            itemName: (d['title'] ?? 'Item').toString(),
                            itemImage: images.isNotEmpty ? images.first : null,
                            requesterId: currentUserId,
                          ),
                        ),
                      );
                    }
                  },
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
            ],
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
                      context.push(
                        AppRouter.reserveItem,
                        extra: widget.donation,
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
