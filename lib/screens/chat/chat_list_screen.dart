import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../providers/chat_provider.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Donating', 'Receiving'];

  String _getApiFilter(String uiFilter) {
    switch (uiFilter) {
      case 'Donating':
        return 'donating';
      case 'Receiving':
        return 'receiving';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatListAsync = ref.watch(chatListProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(chatListProvider.notifier).refreshChats(force: true),
              child: chatListAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text('Error loading chats: $err'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(chatListProvider.notifier)
                            .loadChats(filter: _getApiFilter(_selectedFilter)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (chats) {
                  return chats.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 8, bottom: 20),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: chats.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 84,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) =>
                              _buildChatTile(context, ref, chats[index]),
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = filter);
                ref
                    .read(chatListProvider.notifier)
                    .loadChats(filter: _getApiFilter(filter));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF67AC5D) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> chat,
  ) {
    final currentUserId = ref.read(userIdProvider);
    final donorId = chat['donorId']?.toString();
    final chatRequesterId = chat['requesterId']?.toString();

    // Debug logging
    debugPrint("════════════════════════════════════════");
    debugPrint("CHAT_LIST: currentUserId = $currentUserId");
    debugPrint("CHAT_LIST: donorId = $donorId");
    debugPrint("CHAT_LIST: requesterId = $chatRequesterId");
    debugPrint("CHAT_LIST: isDonating = ${chat['isDonating']}");
    debugPrint("CHAT_LIST: otherUser = ${chat['otherUser']}");
    debugPrint("CHAT_LIST: Full chat data = $chat");

    final donationId = chat['donationId']?.toString() ?? chat['id']?.toString();
    final title =
        chat['itemTitle']?.toString() ??
        chat['donationTitle']?.toString() ??
        chat['title']?.toString() ??
        "Donation Item";

    final otherUser = chat['otherUser'];
    String otherUserName = "User";
    String? otherUserAvatar;
    String? otherUserId;
    bool isVerified = chat['isVerified'] ?? false;

    if (otherUser is Map<String, dynamic>) {
      otherUserName = otherUser['name']?.toString() ?? "User";
      otherUserAvatar = otherUser['avatar']?.toString();
      otherUserId = otherUser['id']?.toString();
    } else if (otherUser is String) {
      otherUserName = otherUser;
    }

    // Try multiple image field names - check for 'images' array first
    String imageUrl = "";
    final imagesArray = chat['images'] ?? chat['donationImages'];
    if (imagesArray is List && imagesArray.isNotEmpty) {
      imageUrl = imagesArray[0]?.toString() ?? "";
    }
    if (imageUrl.isEmpty) {
      imageUrl =
          chat['donationImage']?.toString() ??
          chat['image']?.toString() ??
          chat['itemImage']?.toString() ??
          "";
    }
    debugPrint(
      'CHAT_LIST: donationId=${chat['donationId']}, imageUrl=$imageUrl, imagesArray=$imagesArray',
    );
    final lastMessage = chat['lastMessage']?.toString() ?? "";
    final lastMessageTime = chat['lastMessageTime'] ?? chat['updatedAt'];
    final unreadCount = chat['unreadCount'] ?? 0;

    // UI specific fields to match the provided image
    final bool isDonating = chat['isDonating'] ?? true;
    final String status =
        chat['status'] ?? (unreadCount > 0 ? "Scheduled" : "Active");
    final double? rating = chat['rating'] != null
        ? double.tryParse(chat['rating'].toString())
        : null;

    String? navRequesterId;
    if (currentUserId != null && currentUserId == donorId) {
      navRequesterId = chatRequesterId ?? otherUserId;
    } else {
      navRequesterId = donorId ?? otherUserId ?? chatRequesterId;
    }

    return InkWell(
      onTap: () {
        if (donationId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                donationId: donationId,
                itemName: title,
                itemImage: imageUrl,
                requesterId: navRequesterId,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(otherUserAvatar, isDonating),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              TextSpan(
                                text: otherUserName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isVerified)
                                const WidgetSpan(
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              const TextSpan(
                                text: "  •  ",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: title,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (lastMessageTime != null)
                        Text(
                          _formatTime(lastMessageTime),
                          style: TextStyle(
                            color: unreadCount > 0
                                ? const Color(0xFF67AC5D)
                                : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage.isNotEmpty
                              ? lastMessage
                              : "Tap to open chat",
                          style: TextStyle(
                            color: unreadCount > 0
                                ? Colors.black
                                : Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF67AC5D),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusChip(status),
                      if (rating != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating.toString(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, bool isDonating) {
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
            image: imageUrl != null && imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageUrl == null || imageUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.grey, size: 28)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDonating
                  ? const Color(0xFF4A80F0)
                  : const Color(0xFF9C27B0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              isDonating ? Icons.handshake : Icons.inventory_2,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'scheduled':
        bgColor = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFB88E2F);
        break;
      case 'active':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'completed':
        bgColor = const Color(0xFFF5F5F5);
        textColor = Colors.grey.shade600;
        break;
      default:
        bgColor = const Color(0xFFF5F5F5);
        textColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          Container(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No messages yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your conversations will appear here.",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dt;
    if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(
        timestamp < 10000000000 ? timestamp * 1000 : timestamp,
      );
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is Map) {
      if (timestamp.containsKey('_seconds')) {
        dt = DateTime.fromMillisecondsSinceEpoch(
          (timestamp['_seconds'] as int) * 1000,
        );
      } else if (timestamp.containsKey('seconds')) {
        dt = DateTime.fromMillisecondsSinceEpoch(
          (timestamp['seconds'] as int) * 1000,
        );
      } else {
        return '';
      }
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (today.difference(date).inDays == 1) {
      return 'Yesterday';
    } else if (today.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(dt);
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }
}
