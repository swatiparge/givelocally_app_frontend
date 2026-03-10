import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

const bool _kDebugChatLogging = false;

void _chatLog(String message) {
  if (_kDebugChatLogging && kDebugMode) {
    debugPrint(message);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ChatParams {
  final String donationId;
  final String? requesterId;

  ChatParams({required this.donationId, this.requesterId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParams &&
          runtimeType == other.runtimeType &&
          donationId == other.donationId &&
          requesterId == other.requesterId;

  @override
  int get hashCode => donationId.hashCode ^ requesterId.hashCode;
}

final chatListProvider =
    StateNotifierProvider<
      ChatListNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >((ref) {
      return ChatListNotifier(ref);
    });

final chatMessagesProvider =
    StateNotifierProvider.family<
      ChatMessagesNotifier,
      AsyncValue<List<Map<String, dynamic>>>,
      ChatParams
    >((ref, params) {
      return ChatMessagesNotifier(ref, params);
    });

class ChatListNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  Timer? _refreshTimer;
  String _currentFilter = 'all';

  ChatListNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  String get currentFilter => _currentFilter;

  void _init() {
    loadChats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refreshChats(),
    );
  }

  Future<void> loadChats({String filter = 'all'}) async {
    _currentFilter = filter;
    state = const AsyncValue.loading();
    await _fetchChats();
  }

  Future<void> refreshChats({bool force = false}) async {
    if (!force && state.isLoading) return;
    await _fetchChats();
  }

  Future<void> setFilter(String filter) async {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    state = const AsyncValue.loading();
    await _fetchChats();
  }

  Future<void> _fetchChats() async {
    try {
      _chatLog(
        'CHAT_PROVIDER: Fetching chat list with filter: $_currentFilter...',
      );
      final apiService = _ref.read(apiServiceProvider);
      final chats = await apiService.getUserChats(filter: _currentFilter);
      _chatLog('CHAT_PROVIDER: Received ${chats.length} chats');

      final typedChats = chats
          .map((chat) {
            if (chat is Map<String, dynamic>) return chat;
            if (chat is Map) return Map<String, dynamic>.from(chat);
            return <String, dynamic>{};
          })
          .where((chat) => chat.isNotEmpty)
          .toList();

      typedChats.sort((a, b) {
        final timeA = _toDateTime(
          a['lastMessageTime'] ?? a['updatedAt'] ?? a['createdAt'],
        );
        final timeB = _toDateTime(
          b['lastMessageTime'] ?? b['updatedAt'] ?? b['createdAt'],
        );
        return timeB.compareTo(timeA);
      });

      state = AsyncValue.data(typedChats);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  DateTime _toDateTime(dynamic ts) {
    if (ts == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (ts is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        ts < 10000000000 ? ts * 1000 : ts,
      );
    }
    if (ts is String) {
      return DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (ts is Map) {
      if (ts.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (ts['_seconds'] as int) * 1000,
        );
      }
      if (ts.containsKey('seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (ts['seconds'] as int) * 1000,
        );
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

class ChatMessagesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  final ChatParams params;
  Timer? _refreshTimer;
  String? _lastTimestamp;
  bool _hasMore = true;

  ChatMessagesNotifier(this._ref, this.params)
    : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    loadMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => refreshMessages(),
    );
  }

  Future<void> loadMessages() async {
    state = const AsyncValue.loading();
    await _fetchMessages();
  }

  Future<void> refreshMessages() async {
    if (state.isLoading) return;
    await _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      _chatLog('CHAT_MESSAGES: === FETCH START ===');
      _chatLog('CHAT_MESSAGES: donationId = ${params.donationId}');
      _chatLog('CHAT_MESSAGES: requesterId = ${params.requesterId}');

      if (params.requesterId == null) {
        _chatLog('CHAT_MESSAGES: ⚠️ requesterId is NULL');
      }

      final apiService = _ref.read(apiServiceProvider);
      final result = await apiService.getChatMessages(
        params.donationId,
        requesterId: params.requesterId,
      );

      if (result.containsKey('error')) {
        _chatLog('CHAT_MESSAGES: Network error detected');

        if (params.requesterId != null) {
          _chatLog('CHAT_MESSAGES: Trying fallback without requesterId...');
          final fallbackResult = await apiService.getChatMessages(
            params.donationId,
          );

          if (!fallbackResult.containsKey('error')) {
            final messages = _safeParseMessages(fallbackResult['messages']);
            if (messages.isNotEmpty) {
              _lastTimestamp = fallbackResult['lastTimestamp']?.toString();
              _hasMore = fallbackResult['hasMore'] == true;
              state = AsyncValue.data(messages);
              debugPrint(
                'CHAT_MESSAGES: Fallback succeeded with ${messages.length} messages',
              );
              return;
            }
          }
        }

        state = AsyncValue.error(
          Exception('Network error. Please check your internet connection.'),
          StackTrace.current,
        );
        return;
      }

      var messages = _safeParseMessages(result['messages']);

      if (messages.isEmpty && params.requesterId != null) {
        _chatLog('CHAT_MESSAGES: Trying without requesterId...');
        final fallbackResult = await apiService.getChatMessages(
          params.donationId,
        );
        messages = _safeParseMessages(fallbackResult['messages']);
      }

      _chatLog('CHAT_MESSAGES: Final count = ${messages.length}');

      _lastTimestamp = result['lastTimestamp']?.toString();
      _hasMore = result['hasMore'] == true;

      state = AsyncValue.data(messages);
      _chatLog('CHAT_MESSAGES: === FETCH COMPLETE ===');
    } catch (e, stack) {
      _chatLog('CHAT_MESSAGES: ERROR = $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMoreMessages() async {
    if (!_hasMore || _lastTimestamp == null) return;

    final currentState = state;
    if (currentState is! AsyncData || currentState.value == null) return;

    try {
      final apiService = _ref.read(apiServiceProvider);
      final result = await apiService.getChatMessages(
        params.donationId,
        lastTimestamp: _lastTimestamp,
        requesterId: params.requesterId,
      );

      final newMessages = _safeParseMessages(result['messages']);
      _lastTimestamp = result['lastTimestamp']?.toString();
      _hasMore = result['hasMore'] == true;

      if (newMessages.isNotEmpty) {
        final merged = _mergeAndSortMessages(currentState.value!, newMessages);
        state = AsyncValue.data(merged);
      }
    } catch (e) {
      _chatLog('CHAT_MESSAGES: loadMore error = $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final apiService = _ref.read(apiServiceProvider);
    final success = await apiService.sendMessage(
      params.donationId,
      text.trim(),
      requesterId: params.requesterId,
    );

    if (success) {
      await refreshMessages();
      _ref.read(chatListProvider.notifier).refreshChats(force: true);
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.markMessageAsRead(params.donationId, messageId);
  }

  Future<void> archiveChat() async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.archiveChatMessages(params.donationId);
  }

  List<Map<String, dynamic>> _safeParseMessages(dynamic raw) {
    if (raw == null || raw is! List) return [];

    final List<Map<String, dynamic>> parsed = [];
    for (var item in raw) {
      if (item is Map<String, dynamic>) {
        parsed.add(item);
      } else if (item is Map) {
        parsed.add(Map<String, dynamic>.from(item));
      }
    }

    parsed.sort((a, b) {
      final timeA = _toDateTime(a['timestamp']);
      final timeB = _toDateTime(b['timestamp']);
      return timeB.compareTo(timeA);
    });

    return parsed;
  }

  List<Map<String, dynamic>> _mergeAndSortMessages(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> newlyFetched,
  ) {
    final Map<String, Map<String, dynamic>> msgMap = {};

    void addToMap(Map<String, dynamic> m) {
      final key =
          m['id']?.toString() ??
          "${m['senderId']}_${m['timestamp']}_${m['message'].toString().hashCode}";
      msgMap[key] = m;
    }

    for (var m in current) addToMap(m);
    for (var m in newlyFetched) addToMap(m);

    final merged = msgMap.values.toList();
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
      return DateTime.fromMillisecondsSinceEpoch(
        ts < 10000000000 ? ts * 1000 : ts,
      );
    }
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    if (ts is Map) {
      if (ts.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (ts['_seconds'] as int) * 1000,
        );
      }
      if (ts.containsKey('seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (ts['seconds'] as int) * 1000,
        );
      }
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final chatByDonationIdProvider =
    Provider.family<AsyncValue<Map<String, dynamic>?>, String>((
      ref,
      donationId,
    ) {
      final chatListAsync = ref.watch(chatListProvider);

      return chatListAsync.when(
        data: (chats) {
          final chat = chats.firstWhere(
            (chat) => chat['donationId']?.toString() == donationId,
            orElse: () => <String, dynamic>{},
          );
          return AsyncValue.data(chat.isEmpty ? null : chat);
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    });

final hasUnreadMessagesProvider = Provider<bool>((ref) {
  final chatListAsync = ref.watch(chatListProvider);
  return chatListAsync.when(
    data: (chats) {
      return chats.any(
        (chat) =>
            chat['unreadCount'] != null && (chat['unreadCount'] as int) > 0,
      );
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

final totalUnreadCountProvider = Provider<int>((ref) {
  final chatListAsync = ref.watch(chatListProvider);
  return chatListAsync.when(
    data: (chats) {
      return chats.fold<int>(
        0,
        (sum, chat) => sum + ((chat['unreadCount'] ?? 0) as int),
      );
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
