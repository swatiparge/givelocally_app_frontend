import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'complete_pickup_screen.dart';
import '../home/donation_detail_screen.dart';

class MyDonationsScreen extends ConsumerStatefulWidget {
  const MyDonationsScreen({super.key});

  @override
  ConsumerState<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends ConsumerState<MyDonationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  String _selectedDistance = 'All';

  final List<String> _categories = ['All', 'Food', 'Appliances', 'Blood', 'Stationery'];
  final List<String> _distances = ['All', 'Within 1 km', 'Within 3 km', 'Within 5 km'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Stream<QuerySnapshot> _getFilteredStream(String uid, {required bool isActive}) {
    Query query = FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: uid);

    if (isActive) {
      // Show only active and reserved donations in the Active tab
      query = query.where('status', whereIn: ['active', 'reserved']);
    } else {
      // Show completed donations in the Completed tab
      query = query.where('status', isEqualTo: 'completed');
    }

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory.toLowerCase());
    }

    return query.orderBy('created_at', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot> _filterByDistance(List<QueryDocumentSnapshot> docs) {
    double maxDist = 1.0;
    if (_selectedDistance.contains('3')) maxDist = 3.0;
    if (_selectedDistance.contains('5')) maxDist = 5.0;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dist = double.tryParse(data['distance']?.toString() ?? '0') ?? 0.0;
      return dist <= maxDist;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildDropdown(_categories, _selectedCategory, "Category", (val) {
                    modalState(() => _selectedCategory = val!);
                  }),
                  const SizedBox(height: 16),
                  _buildDropdown(_distances, _selectedDistance, "Distance", (val) {
                    modalState(() => _selectedDistance = val!);
                  }),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () {
                      setState(() {}); // Trigger rebuild on main screen
                      Navigator.pop(context);
                    },
                    child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(userIdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "My Donations",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.green,
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDonationList(uid, isActive: true),
                _buildDonationList(uid, isActive: false),
              ],
            ),
    );
  }

  Widget _buildDonationList(String uid, {required bool isActive}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredStream(uid, isActive: isActive),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint("Firestore Error: ${snapshot.error}");
          return _buildErrorState();
        }

        var docs = snapshot.data?.docs ?? [];
        if (_selectedDistance != 'All') {
          docs = _filterByDistance(docs);
        }

        if (docs.isEmpty) {
          return _buildEmptyState(isActive: isActive);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            // Add document ID to the data map
            data['id'] = doc.id;
            return _buildDonationItemCard(data);
          },
        );
      },
    );
  }

  Widget _buildDropdown(List<String> items, String selected, String placeholder, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected == 'All' ? null : selected,
          hint: Text(placeholder, style: const TextStyle(color: Colors.grey)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          style: const TextStyle(color: Color(0xFF495057), fontWeight: FontWeight.w600, fontSize: 14),
          onChanged: onChanged,
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isActive}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            isActive ? "No active donations" : "No completed donations",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          const Text("Your donations will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text("Unable to load donations.",
          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildDonationItemCard(Map<String, dynamic> item) {
    final category = (item['category'] ?? '').toString().toLowerCase();
    final title = item['title'] ?? "Item";
    final status = (item['status'] ?? 'active').toString().toLowerCase();
    final timestamp = item['created_at'] as Timestamp?;
    
    String timeAgo = "Just now";
    if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inDays > 0) {
        timeAgo = "${diff.inDays}d ago";
      } else if (diff.inHours > 0) {
        timeAgo = "${diff.inHours}h ago";
      } else if (diff.inMinutes > 0) {
        timeAgo = "${diff.inMinutes}m ago";
      }
    }

    final requestCount = item['requestCount'] ?? 0;
    final reservedBy = item['reservedBy'] as Map?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryIcon(category),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1A1C1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Listed $timeAgo", style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    if (status == 'reserved' && reservedBy != null)
                      _buildReservedByChip(reservedBy)
                    else if (status == 'active')
                      _buildRequestCountChip(requestCount),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F1F1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DonationDetailScreen(donation: item),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "View Details",
                    style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              if (status == 'reserved' || (status == 'active' && requestCount > 0)) ...[
                const SizedBox(width: 12),
                _buildReviewButton(item, isReserved: status == 'reserved'),
              ],
            ],
          )
        ],
      ),
    );
  }
  
  Widget _buildCategoryIcon(String category) {
    IconData icon;
    Color bgColor;

    switch (category) {
      case 'food':
        icon = Icons.restaurant_outlined;
        bgColor = const Color(0xFFFFF8E1);
        break;
      case 'appliances':
        icon = Icons.tv_outlined;
        bgColor = const Color(0xFFE3F2FD);
        break;
      case 'blood':
        icon = Icons.water_drop_outlined;
        bgColor = const Color(0xFFFFEBEE);
        break;
      case 'stationery':
        icon = Icons.menu_book_outlined;
        bgColor = const Color(0xFFF3E5F5);
        break;
      default:
        icon = Icons.inventory_2_outlined;
        bgColor = const Color(0xFFF5F5F5);
    }

    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20)
      ),
      child: Icon(icon, color: Colors.blue.shade700, size: 36), // Updated to match image blue icons
    );
  }

  Widget _buildReservedByChip(Map reservedBy) {
    return Row(
      children: [
        CircleAvatar(radius: 10, backgroundImage: NetworkImage(reservedBy['photoUrl'] ?? 'https://via.placeholder.com/150')),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Reserved by ${reservedBy['name'] ?? 'user'}",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCountChip(int count) {
    return Row(
      children: [
        const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF4CAF50)),
        const SizedBox(width: 8),
        Text("$count requests", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
      ],
    );
  }

  Widget _buildReviewButton(Map<String, dynamic> item, {required bool isReserved}) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () async {
          if (isReserved) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompletePickupScreen(donation: item),
              ),
            );
            if (result == true) {
              setState(() {}); // Refresh list if completed
            }
          } else {
            // TODO: Open review requests list screen
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A), // Dark blue/black as per image
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          "Review Requests",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor;
    String text = status.toUpperCase();

    switch (status) {
      case 'active':
        color = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'reserved':
        color = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      case 'completed':
        color = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'pending':
        color = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        text = 'PENDING';
        break;
      default:
        color = const Color(0xFFF5F5F5);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
