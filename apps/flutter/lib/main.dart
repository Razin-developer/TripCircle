import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/services/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppLogger.instance.init().timeout(
      const Duration(seconds: 3),
    );
  } catch (e) {
    debugPrint('Logger init failed: $e');
  }

  runTripCircleApp();
}