import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';

class MyDonationsScreen extends StatefulWidget {
  const MyDonationsScreen({super.key});

  @override
  State<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> with SingleTickerProviderStateMixin {
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
      query = query.where('status', whereIn: ['active', 'reserved', 'pending']);
    } else {
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
    final uid = Provider.of<AuthService>(context).firebaseUser?.uid;

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
            final data = docs[index].data() as Map<String, dynamic>;
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
    final listedDate = timestamp != null ? DateFormat('d MMM y').format(timestamp.toDate()) : 'Not specified';

    final requestCount = item['requestCount'] ?? 0;
    final reservedBy = item['reservedBy'] as Map?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
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
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1C1E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Listed on $listedDate", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    if (status == 'reserved' && reservedBy != null)
                      _buildReservedByChip(reservedBy)
                    else if (status == 'active' && requestCount > 0)
                      _buildRequestCountChip(requestCount),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("View Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              if (status == 'reserved') ...[
                const SizedBox(width: 12),
                _buildCompleteButton(),
              ] else if (status == 'active' && requestCount > 0) ...[
                const SizedBox(width: 12),
                _buildReviewButton(),
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
        bgColor = Colors.orange.shade50;
        break;
      case 'appliances':
        icon = Icons.tv_outlined;
        bgColor = Colors.blue.shade50;
        break;
      case 'blood':
        icon = Icons.water_drop_outlined;
        bgColor = Colors.red.shade50;
        break;
      case 'stationery':
        icon = Icons.menu_book_outlined;
        bgColor = Colors.purple.shade50;
        break;
      default:
        icon = Icons.inventory_2_outlined;
        bgColor = Colors.grey.shade200;
    }

    return Container(
      width: 68, height: 68,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16)
      ),
      child: Icon(icon, color: Color.lerp(bgColor, Colors.black, 0.6), size: 32),
    );
  }

  Widget _buildReservedByChip(Map reservedBy) {
    return Row(
      children: [
        CircleAvatar(radius: 10, backgroundImage: NetworkImage(reservedBy['photoUrl'] ?? 'https://via.placeholder.com/150')),
        const SizedBox(width: 8),
        Text("Reserved by ${reservedBy['name'] ?? 'user'}", style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
      ],
    );
  }

  Widget _buildRequestCountChip(int count) {
    return Row(
      children: [
        Icon(Icons.people_alt_outlined, size: 16, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Text("$count requests", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
      ],
    );
  }

  Widget _buildCompleteButton() {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text("Complete Pickup", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildReviewButton() {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1C1E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Review Requests", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text = status.toUpperCase();

    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'reserved':
        color = Colors.orange;
        break;
      case 'pending':
        color = Colors.blue;
        text = 'PENDING PICKUP';
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
