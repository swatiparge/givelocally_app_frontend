import 'package:flutter/material.dart';

import '../services/error_logger_service.dart';

typedef FutureTask<T> = Future<T> Function();

class SafeRequest {
  final BuildContext context;

  SafeRequest(this.context);

  Future<T> execute<T>({
    required FutureTask<T> request,
    required String loadingMessage,
    String? successMessage,
    String? errorMessage,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(loadingMessage), duration: Duration(days: 1)),
    );

    try {
      final result = await request();
      scaffoldMessenger.hideCurrentSnackBar();

      if (successMessage != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }

      onSuccess?.call();
      return result;
    } catch (e, stack) {
      scaffoldMessenger.hideCurrentSnackBar();
      AppLogger.error('Request failed', e, stack);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'Something went wrong'),
          backgroundColor: Colors.red,
        ),
      );

      onError?.call();
      rethrow;
    }
  }
}

extension SafeGuard<T> on Future<T> Function() {
  Future<T> Function() get guard => this;
}
