import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String donationId;
  final String itemName;
  final String? itemImage;

  const ChatScreen({
    super.key,
    required this.donationId,
    required this.itemName,
    this.itemImage,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _lastTimestamp;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialMessages();
    });
    
    // Polling for new messages every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollNewMessages());
    
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // In a reversed ListView, the top of the visible area (oldest messages) is at maxScrollExtent.
    // When pixels approach maxScrollExtent, we load older messages.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _lastTimestamp != null) {
        _loadMoreMessages();
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getChatMessages(widget.donationId);
      if (mounted) {
        final List<dynamic> raw = result['messages'] ?? [];
        setState(() {
          _messages = _safeParseMessages(raw);
          _lastTimestamp = result['lastTimestamp']?.toString();
          _hasMore = result['hasMore'] == true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("ChatScreen Initial Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _safeParseMessages(List? raw) {
    if (raw == null) return [];
    final List<Map<String, dynamic>> parsed = [];
    for (var item in raw) {
      if (item is Map) {
        parsed.add(Map<String, dynamic>.from(item));
      }
    }
    // Sort newest first for the reversed ListView
    parsed.sort((a, b) => _toDateTime(b['timestamp']).compareTo(_toDateTime(a['timestamp'])));
    return parsed;
  }

  Future<void> _loadMoreMessages() async {
    if (_lastTimestamp == null || !mounted || _isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    try {
      final result = await _apiService.getChatMessages(
        widget.donationId, 
        lastTimestamp: _lastTimestamp
      );
      if (mounted) {
        final List<dynamic> rawMore = result['messages'] ?? [];
        final moreMessages = _safeParseMessages(rawMore);
        setState(() {
          if (moreMessages.isNotEmpty) {
            _messages = _mergeAndSortMessages(_messages, moreMessages);
            _lastTimestamp = result['lastTimestamp']?.toString();
            _hasMore = result['hasMore'] == true;
          } else {
            _hasMore = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("ChatScreen Load More Error: $e");
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _pollNewMessages() async {
    if (!mounted || _isLoading || _isLoadingMore) return;
    try {
      final result = await _apiService.getChatMessages(widget.donationId);
      final List<dynamic> rawNew = result['messages'] ?? [];
      
      if (mounted && rawNew.isNotEmpty) {
        final newMessages = _safeParseMessages(rawNew);
        setState(() {
          _messages = _mergeAndSortMessages(_messages, newMessages);
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _mergeAndSortMessages(List<Map<String, dynamic>> current, List<Map<String, dynamic>> newlyFetched) {
    final Map<String, Map<String, dynamic>> msgMap = {};
    
    void addToMap(Map<String, dynamic> m) {
      // Use 'id' if available, otherwise fallback to a content-based hash
      final key = m['id']?.toString() ?? 
                 "${m['senderId']}_${m['timestamp']}_${m['message'].toString().hashCode}";
      msgMap[key] = m;
    }

    current.forEach(addToMap);
    newlyFetched.forEach(addToMap);

    final merged = msgMap.values.toList();
    
    // Sort descending: newest first (index 0)
    // In a reversed ListView, index 0 is at the bottom (WhatsApp style)
    merged.sort((a, b) {
      final timeA = _toDateTime(a['timestamp']);
      final timeB = _toDateTime(b['timestamp']);
      return timeB.compareTo(timeA);
    });
    
    return merged;
  }

  DateTime _toDateTime(dynamic ts) {
    if (ts == null) return DateTime.now(); 
    if (ts is int) {
      // Handle seconds vs milliseconds
      return DateTime.fromMillisecondsSinceEpoch(ts < 10000000000 ? ts * 1000 : ts);
    }
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    if (ts is Map) {
      if (ts.containsKey('_seconds')) return DateTime.fromMillisecondsSinceEpoch((ts['_seconds'] as int) * 1000);
      if (ts.containsKey('seconds')) return DateTime.fromMillisecondsSinceEpoch((ts['seconds'] as int) * 1000);
    }
    return DateTime.now();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    
    // Optimistically add message to UI if needed, but here we wait for poll or immediate fetch
    final success = await _apiService.sendMessage(widget.donationId, text);
    if (success) {
      _pollNewMessages();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  String _formatTime(dynamic timestamp) {
    final dt = _toDateTime(timestamp);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(userIdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // index 0 is at the bottom
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          
                          final message = _messages[index];
                          // Robust identity check
                          final isMe = message['isMe'] == true || 
                                       (currentUserId != null && message['senderId'] == currentUserId);
                          
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            "No messages yet.\nStart a conversation!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      backgroundColor: Colors.white,
      leading: const BackButton(color: Colors.black),
      titleSpacing: 0,
      title: Row(
        children: [
          _buildAppBarImage(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemName,
                  style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  "Donation Item",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarImage() {
    final imageUrl = widget.itemImage;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 20),
            )
          : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 20),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    if (isMe) {
      return _buildSentMessage(message);
    } else {
      return _buildReceivedMessage(message);
    }
  }

  Widget _buildSentMessage(Map<String, dynamic> message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, left: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF38A84A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message['message']?.toString() ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['timestamp']),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.done_all, color: Colors.white, size: 16),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedMessage(Map<String, dynamic> message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            margin: const EdgeInsets.only(top: 4, bottom: 4, right: 80),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['message']?.toString() ?? '',
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatTime(message['timestamp']),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  hintText: "Type a message...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF38A84A),
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 22),
                onPressed: _handleSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
