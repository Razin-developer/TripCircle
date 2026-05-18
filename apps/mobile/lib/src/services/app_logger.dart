import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  File? _file;
  Future<void>? _initFuture;
  Future<void> _pendingWrite = Future<void>.value();

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final directory = await getApplicationDocumentsDirectory();

    final logsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}logs',
    );

    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
    }

    final now = DateTime.now();

    final filename =
        'tripcircle-${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.log';

    _file = File('${logsDirectory.path}${Platform.pathSeparator}$filename');

    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
    }

    // Do NOT call info() here, because info() calls init() again.
    await _writeRaw({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'info',
      'category': 'logger',
      'message': 'Logger initialized',
      'data': {
        'logFilePath': _file!.path,
      },
    });
  }

  Future<void> info(
    String category,
    String message, {
    Map<String, dynamic>? data,
  }) {
    return _write('info', category, message, data);
  }

  Future<void> warning(
    String category,
    String message, {
    Map<String, dynamic>? data,
  }) {
    return _write('warning', category, message, data);
  }

  Future<void> error(
    String category,
    String message, {
    Map<String, dynamic>? data,
  }) {
    return _write('error', category, message, data);
  }

  Future<void> screenMounted(
    String screenName, {
    Map<String, dynamic>? data,
  }) {
    return info(
      'screen',
      'Screen mounted',
      data: {'screen': screenName, ...?data},
    );
  }

  Future<void> screenDisposed(
    String screenName, {
    Map<String, dynamic>? data,
  }) {
    return info(
      'screen',
      'Screen disposed',
      data: {'screen': screenName, ...?data},
    );
  }

  Future<void> routeEvent(
    String event,
    String routeName, {
    Map<String, dynamic>? data,
  }) {
    return info(
      'route',
      'Route $event',
      data: {
        'route': routeName,
        ...?data,
      },
    );
  }

  Future<void> _write(
    String level,
    String category,
    String message,
    Map<String, dynamic>? data,
  ) async {
    await init();

    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'category': category,
      'message': message,
      if (data != null && data.isNotEmpty) 'data': data,
    };

    await _writeRaw(entry);
  }

  Future<void> _writeRaw(Map<String, dynamic> entry) async {
    final line = '${jsonEncode(entry)}\n';

    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _file?.writeAsString(
          line,
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {
        // Avoid crashing app because of logger writes.
      }
    });

    await _pendingWrite;
  }
}