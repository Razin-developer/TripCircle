import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/services/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();
  runTripCircleApp();
}
