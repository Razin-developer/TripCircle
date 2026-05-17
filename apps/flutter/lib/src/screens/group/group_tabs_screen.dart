import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import 'group_map_screen.dart';
import 'group_members_screen.dart';
import 'group_settings_screen.dart';

class GroupTabsScreen extends StatefulWidget {
  const GroupTabsScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupName,
  });

  final AppController controller;
  final String groupId;
  final String groupName;

  @override
  State<GroupTabsScreen> createState() => _GroupTabsScreenState();
}

class _GroupTabsScreenState extends State<GroupTabsScreen> {
  int currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      GroupMapScreen(controller: widget.controller, groupId: widget.groupId, groupName: widget.groupName),
      GroupMembersScreen(controller: widget.controller, groupId: widget.groupId, groupName: widget.groupName),
      GroupSettingsScreen(controller: widget.controller, groupId: widget.groupId, groupName: widget.groupName),
    ];

    return Scaffold(
      body: screens[currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        ],
        onDestinationSelected: (index) {
          setState(() {
            currentTab = index;
          });
        },
      ),
    );
  }
}
