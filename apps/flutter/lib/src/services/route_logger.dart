import 'dart:async';

import 'package:flutter/material.dart';

import 'app_logger.dart';

class AppRouteObserver extends NavigatorObserver {
  String _nameFor(Route<dynamic>? route) {
    return route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown-route';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    unawaited(
      AppLogger.instance.routeEvent(
        'pushed',
        _nameFor(route),
        data: {'previousRoute': _nameFor(previousRoute)},
      ),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    unawaited(
      AppLogger.instance.routeEvent(
        'popped',
        _nameFor(route),
        data: {'nextRoute': _nameFor(previousRoute)},
      ),
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    unawaited(
      AppLogger.instance.routeEvent(
        'replaced',
        _nameFor(newRoute),
        data: {'oldRoute': _nameFor(oldRoute)},
      ),
    );
  }
}
