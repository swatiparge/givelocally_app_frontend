import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String donationId;
  final String itemName;
  final String? itemImage;
  final String? requesterId;

  const ChatScreen({
    super.key,
    required this.donationId,
    required this.itemName,
    this.itemImage,
    this.requesterId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _initialized = false;
  late ChatParams _chatParams;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initializeChatParams();
    }
  }

  void _initializeChatParams() {
    final currentUserId = ref.read(userIdProvider);

    debugPrint('CHAT_SCREEN: === INITIALIZE ===');
    debugPrint('CHAT_SCREEN: donationId = ${widget.donationId}');
    debugPrint('CHAT_SCREEN: requesterId from widget = ${widget.requesterId}');
    debugPrint('CHAT_SCREEN: currentUserId = $currentUserId');

    _chatParams = ChatParams(
      donationId: widget.donationId,
      requesterId: widget.requesterId ?? currentUserId,
    );

    debugPrint('CHAT_SCREEN: Final requesterId = ${_chatParams.requesterId}');
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessagesProvider(_chatParams).notifier).loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() => _isSending = true);

    await ref
        .read(chatMessagesProvider(_chatParams).notifier)
        .sendMessage(text);

    if (mounted) {
      setState(() => _isSending = false);
    }
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
        dt = DateTime.now();
      }
    } else {
      dt = DateTime.now();
    }

    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(_chatParams));
    final currentUserId = ref.watch(userIdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildErrorState(err),
              data: (messages) => messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(messages, currentUserId),
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Unable to load messages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(chatMessagesProvider(_chatParams).notifier)
                    .loadMessages();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
    debugPrint('CHAT_SCREEN: itemImage = $imageUrl');
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          (imageUrl != null &&
              imageUrl.isNotEmpty &&
              imageUrl.startsWith('http'))
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.inventory_2_outlined,
                color: Colors.grey,
                size: 20,
              ),
            )
          : const Icon(
              Icons.inventory_2_outlined,
              color: Colors.grey,
              size: 20,
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
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

  Widget _buildMessageList(
    List<Map<String, dynamic>> messages,
    String? currentUserId,
  ) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe =
            message['isMe'] == true ||
            (currentUserId != null && message['senderId'] == currentUserId);
        return _buildMessageBubble(message, isMe);
      },
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedMessage(Map<String, dynamic> message) {
    final imageUrl = widget.itemImage;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE5E7EB),
              image:
                  (imageUrl != null &&
                      imageUrl.isNotEmpty &&
                      imageUrl.startsWith('http'))
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child:
                (imageUrl == null ||
                    imageUrl.isEmpty ||
                    !imageUrl.startsWith('http'))
                ? const Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: Colors.grey,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF38A84A),
              radius: 24,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _isSending ? null : _handleSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
