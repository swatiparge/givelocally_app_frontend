import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/chat_provider.dart';
import '../../services/api_service.dart';

class ChatScreenDebug extends ConsumerStatefulWidget {
  final String donationId;
  final String? requesterId;

  const ChatScreenDebug({
    super.key,
    required this.donationId,
    this.requesterId,
  });

  @override
  ConsumerState<ChatScreenDebug> createState() => _ChatScreenDebugState();
}

class _ChatScreenDebugState extends ConsumerState<ChatScreenDebug> {
  String _debugOutput = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _debugOutput = 'Running diagnostics...\n';
    });

    final currentUserId = ref.read(userIdProvider);
    _log('=== USER INFO ===');
    _log('Current User ID: $currentUserId');
    _log('Donation ID: ${widget.donationId}');
    _log('Requester ID: ${widget.requesterId}');
    _log('');

    final apiService = ApiService();

    _log('=== TEST 1: getUserChats ===');
    try {
      final chats = await apiService.getUserChats();
      _log('Total chats: ${chats.length}');

      if (chats.isNotEmpty) {
        _log('\n--- Looking for donationId: ${widget.donationId} ---');
        for (var chat in chats) {
          final chatDonationId =
              chat['donationId']?.toString() ?? chat['id']?.toString();
          _log('\nChat donationId: $chatDonationId');

          if (chatDonationId == widget.donationId) {
            _log('✅ FOUND MATCHING CHAT!');
            _log('Full chat data: $chat');
            _log('');
            _log('Keys: ${chat.keys.toList()}');
            _log('otherUser: ${chat['otherUser']}');
            _log('requesterId: ${chat['requesterId']}');
            _log('donorId: ${chat['donorId']}');
          }
        }
      }
    } catch (e, s) {
      _log('ERROR: $e');
      _log('Stack: $s');
    }

    _log('\n=== TEST 2: getChatMessages (with requesterId) ===');
    try {
      final result = await apiService.getChatMessages(
        widget.donationId,
        requesterId: widget.requesterId,
      );
      _log('Messages found: ${(result['messages'] as List?)?.length ?? 0}');
      if ((result['messages'] as List?)?.isNotEmpty ?? false) {
        _log('First message: ${result['messages'][0]}');
      }
    } catch (e, s) {
      _log('ERROR: $e');
    }

    _log('\n=== TEST 3: getChatMessages (WITHOUT requesterId) ===');
    try {
      final result = await apiService.getChatMessages(widget.donationId);
      _log('Messages found: ${(result['messages'] as List?)?.length ?? 0}');
      if ((result['messages'] as List?)?.isNotEmpty ?? false) {
        _log('First message: ${result['messages'][0]}');
      }
    } catch (e, s) {
      _log('ERROR: $e');
    }

    _log(
      '\n=== TEST 4: getChatMessages (with currentUserId as requesterId) ===',
    );
    try {
      final result = await apiService.getChatMessages(
        widget.donationId,
        requesterId: currentUserId,
      );
      _log('Messages found: ${(result['messages'] as List?)?.length ?? 0}');
      if ((result['messages'] as List?)?.isNotEmpty ?? false) {
        _log('First message: ${result['messages'][0]}');
      }
    } catch (e, s) {
      _log('ERROR: $e');
    }

    setState(() => _isLoading = false);
  }

  void _log(String message) {
    debugPrint(message);
    setState(() {
      _debugOutput += '$message\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _debugOutput,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }
}
