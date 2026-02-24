import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'pickup_code_screen.dart';

class ReceivedItemsScreen extends StatefulWidget {
  const ReceivedItemsScreen({super.key});

  @override
  State<ReceivedItemsScreen> createState() => _ReceivedItemsScreenState();
}

class _ReceivedItemsScreenState extends State<ReceivedItemsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  late Future<List<dynamic>> _pendingItemsFuture;
  late Future<List<dynamic>> _completedItemsFuture;

  @override
  void initState() {
    super.initState();
    debugPrint("DEBUG: ReceivedItemsScreen initState called");
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    debugPrint("DEBUG: ReceivedItemsScreen _loadData() triggered");
    _pendingItemsFuture = _apiService.getReceivedItems("pending");
    _completedItemsFuture = _apiService.getReceivedItems("completed");
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final uid = authService.firebaseUser?.uid;
    
    debugPrint("DEBUG: ReceivedItemsScreen build() called. User ID: $uid");

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Received Items",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2E7D32),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Pending"),
                  const SizedBox(width: 8),
                  _buildCountBadge(_pendingItemsFuture),
                ],
              ),
            ),
            const Tab(text: "Received"),
          ],
        ),
      ),
      body: uid == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Waiting for authentication..."),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApiTransactionList(_pendingItemsFuture, "pending"),
                _buildApiTransactionList(_completedItemsFuture, "completed"),
              ],
            ),
    );
  }

  Widget _buildCountBadge(Future<List<dynamic>> future) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
          );
        }
        final count = snapshot.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildApiTransactionList(Future<List<dynamic>> future, String tab) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        debugPrint("DEBUG: FutureBuilder($tab) state: ${snapshot.connectionState}");
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          debugPrint("DEBUG: FutureBuilder($tab) error: ${snapshot.error}");
          return Center(child: Text("Error loading items: ${snapshot.error}"));
        }

        final items = snapshot.data ?? [];
        debugPrint("DEBUG: FutureBuilder($tab) items count: ${items.length}");

        if (items.isEmpty) {
          return _buildEmptyState(tab);
        }

        return RefreshIndicator(
          onRefresh: () async {
            debugPrint("DEBUG: Manual refresh triggered for $tab");
            setState(() {
              _loadData();
            });
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = items[index] as Map<String, dynamic>;
              return _buildItemCard(data, tab == 'pending');
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String tab) {
    String title = tab == 'pending' ? "No pending pickups" : "No items received yet";
    String subtitle = tab == 'pending' 
        ? "Items you've reserved will appear here." 
        : "Your completed pickups will be listed here.";
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tab == 'pending' ? Icons.shopping_bag_outlined : Icons.archive_outlined,
            size: 80, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatPickupTime(dynamic timeData) {
    if (timeData == null) return "Today, 6:00 PM";
    try {
      if (timeData is String) return timeData;
      // Handle timestamp if needed
      return "Today, 6:00 PM";
    } catch (e) {
      return "Today, 6:00 PM";
    }
  }

  Widget _buildItemCard(Map<String, dynamic> data, bool isPending) {
    final title = data['donationTitle'] ?? data['title'] ?? "Item";
    final donorName = data['donorName'] ?? "Donor";
    final donorPhoto = data['donorPhotoUrl'] ?? "";
    final imageUrl = data['donationImage'] ?? data['image'] ?? "";
    
    // Status handling based on screenshot
    final rawStatus = data['status']?.toString().toUpperCase() ?? (isPending ? "WAITING PICKUP" : "COMPLETED");
    final statusLabel = rawStatus == "RESERVED" ? "RESERVED" : rawStatus;
    
    final statusColor = (statusLabel == "WAITING PICKUP") 
        ? const Color(0xFFFFF3E0) 
        : (statusLabel == "RESERVED" ? const Color(0xFFE8EAF6) : const Color(0xFFE8F5E9));
    final statusTextColor = (statusLabel == "WAITING PICKUP") 
        ? const Color(0xFFE65100) 
        : (statusLabel == "RESERVED" ? const Color(0xFF3F51B5) : const Color(0xFF2E7D32));

    final pickupTime = _formatPickupTime(data['pickupTime']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 80,
                  color: statusLabel == "WAITING PICKUP" ? const Color(0xFFE8EAF6) : const Color(0xFFE3F2FD),
                  child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl, 
                          fit: BoxFit.cover, 
                          errorBuilder: (context, error, stackTrace) => _buildCategoryIcon(data['category']),
                        )
                      : _buildCategoryIcon(data['category']),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1C1E)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: statusTextColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.brown.shade400),
                        const SizedBox(width: 6),
                        Text(
                          "Pickup: $pickupTime",
                          style: TextStyle(color: Colors.brown.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: donorPhoto.isNotEmpty && donorPhoto.startsWith('http') 
                              ? NetworkImage(donorPhoto) 
                              : null,
                          child: (donorPhoto.isEmpty || !donorPhoto.startsWith('http')) 
                              ? const Icon(Icons.person, size: 14) 
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text("Gifted by $donorName", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      ],
                    ),
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
              // Smaller Chat Button
              SizedBox(
                width: 110,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text("Chat", style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    foregroundColor: const Color(0xFF1A1C1E),
                  ),
                ),
              ),
              if (isPending) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PickupCodeScreen(transaction: data)),
                      ).then((_) {
                        debugPrint("DEBUG: Returning from PickupCodeScreen, refreshing...");
                        setState(() {
                          _loadData();
                        });
                      });
                    },
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text("View Pickup Code", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(dynamic category) {
    IconData iconData = Icons.inventory_2;
    Color color = Colors.blue;
    
    final cat = category?.toString().toLowerCase() ?? "";
    if (cat.contains('chair') || cat.contains('furniture')) {
      iconData = Icons.chair;
      color = Colors.indigo;
    } else if (cat.contains('mixer') || cat.contains('appliance')) {
      iconData = Icons.blender;
      color = Colors.redAccent;
    } else if (cat.contains('book') || cat.contains('prep')) {
      iconData = Icons.menu_book;
      color = Colors.green;
    }
    
    return Icon(iconData, color: color, size: 32);
  }
}
