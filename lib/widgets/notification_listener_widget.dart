import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/fcm_service.dart';

/// Widget that sets up the global WidgetRef for FCM notification processing
/// Place this widget at the top of your app (inside ProviderScope)
///
/// CRITICAL FIX: This properly sets and clears the global ref to prevent memory leaks
class NotificationListenerWidget extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  ConsumerState<NotificationListenerWidget> createState() {
    return _NotificationListenerWidgetState();
  }
}

class _NotificationListenerWidgetState
    extends ConsumerState<NotificationListenerWidget> {
  @override
  void initState() {
    super.initState();

    // ✅ CRITICAL FIX: Set global ref IMMEDIATELY in initState
    // This ensures FCM messages can be processed as soon as they arrive
    FcmService.setGlobalRef(ref);
    debugPrint(
      '✅ NOTIFICATION_LISTENER: Global ref set IMMEDIATELY in initState',
    );

    // ✅ FIX: Process pending initial message after widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService().processPendingInitialMessage();
    });
  }

  @override
  void dispose() {
    // ✅ CRITICAL FIX: Clear global ref to prevent memory leak
    FcmService.clearGlobalRef();
    debugPrint('✅ NOTIFICATION_LISTENER: Global ref cleared in dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SIMPLIFIED: No stream watching needed
    // Processing is done in FcmService directly via _addNotificationToProvider
    return widget.child;
  }
}
