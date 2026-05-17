import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/main/dashboard_screen.dart';
import 'screens/main/inbox_screen.dart';
import 'screens/main/settings_screen.dart';
import 'services/app_logger.dart';
import 'services/route_logger.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

void runTripCircleApp() {
  runApp(const TripCircleApp());
}

class TripCircleApp extends StatefulWidget {
  const TripCircleApp({super.key});

  @override
  State<TripCircleApp> createState() => _TripCircleAppState();
}

class _TripCircleAppState extends State<TripCircleApp> {
  late final AppController controller;
  final AppRouteObserver routeObserver = AppRouteObserver();

  @override
  void initState() {
    super.initState();
    controller = AppController();
    unawaited(AppLogger.instance.info('app', 'TripCircle app started'));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = resolveTheme(controller.user?.activeTheme);

        return MaterialApp(
          title: 'TripCircle',
          debugShowCheckedModeBanner: false,
          theme: buildThemeData(palette),
          navigatorObservers: [routeObserver],
          home: _AppGate(controller: controller),
        );
      },
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate({required this.controller});

  final AppController controller;

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  int currentTab = 0;
  bool showPhoneLogin = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller.isBusy && !controller.isAuthenticated && controller.pendingPhoneNumber == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!controller.isAuthenticated) {
      if (controller.pendingPhoneNumber != null) {
        return ProfileSetupScreen(controller: controller, phoneNumber: controller.pendingPhoneNumber!);
      }

      if (!showPhoneLogin) {
        return WelcomeScreen(
          onGetStarted: () {
            unawaited(AppLogger.instance.routeEvent('state-change', 'PhoneLogin', data: {'source': 'Welcome'}));
            setState(() {
              showPhoneLogin = true;
            });
          },
        );
      }

      return PhoneLoginScreen(
        controller: controller,
        onBack: () {
          unawaited(AppLogger.instance.routeEvent('state-change', 'Welcome', data: {'source': 'PhoneLogin'}));
          setState(() {
            showPhoneLogin = false;
          });
        },
      );
    }

    final screens = [
      DashboardScreen(controller: controller),
      InboxScreen(controller: controller),
      SettingsScreen(controller: controller),
    ];

    return Scaffold(
      body: screens[currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (index) {
          final destination = index == 0
              ? 'Dashboard'
              : index == 1
                  ? 'Inbox'
                  : 'Settings';
          unawaited(AppLogger.instance.routeEvent('tab-selected', destination));
          setState(() {
            currentTab = index;
          });
        },
      ),
    );
  }
}
