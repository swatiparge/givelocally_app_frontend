import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static const String _tag = 'GiveLocally';

  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      final dataStr = data != null ? ' | Data: $data' : '';
      print('📱 [DEBUG] $_tag: $message$dataStr');
    }
  }

  static void info(String message, [dynamic data]) {
    if (kDebugMode) {
      final dataStr = data != null ? ' | Data: $data' : '';
      print('ℹ️ [INFO] $_tag: $message$dataStr');
    }
  }

  static void warning(String message, [dynamic data]) {
    if (kDebugMode) {
      final dataStr = data != null ? ' | Data: $data' : '';
      print('⚠️ [WARNING] $_tag: $message$dataStr');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    print('❌ [ERROR] $_tag: $message');
    if (error != null) {
      print('   Error details: $error');
    }
    if (stackTrace != null && kDebugMode) {
      print('   Stack trace:\n$stackTrace');
    }
  }

  static void time(String label) {
    if (kDebugMode) {
      print('⏱️ [TIMING] $label started at ${DateTime.now()}');
    }
  }

  static void timeEnd(String label) {
    if (kDebugMode) {
      print('⏱️ [TIMING] $label ended at ${DateTime.now()}');
    }
  }
}

class ErrorLoggerService {
  static final ErrorLoggerService _instance = ErrorLoggerService._internal();
  factory ErrorLoggerService() => _instance;
  ErrorLoggerService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    AppLogger.info('Error logger initialized');
  }

  void log({
    required String message,
    LogLevel level = LogLevel.info,
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final tagStr = tag != null ? '[$tag] ' : '';
    final errorStr = error != null ? '\nError: $error' : '';
    print('[${level.name.toUpperCase()}] $tagStr$message$errorStr');
  }

  Future<T> guard<T>({
    required String tag,
    required Future<T> Function() task,
    String? fallbackMessage,
  }) async {
    try {
      return await task();
    } catch (error, stackTrace) {
      log(
        message: fallbackMessage ?? 'Operation failed in $tag',
        level: LogLevel.error,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
