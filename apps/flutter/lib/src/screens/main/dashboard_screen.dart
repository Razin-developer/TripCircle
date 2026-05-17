import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/floating_action_button.dart';
import '../../widgets/group_card.dart';
import '../../widgets/screen_shell.dart';
import '../group/group_tabs_screen.dart';
import '../other/create_group_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refreshHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.controller.groups;

    return Scaffold(
      floatingActionButton: TripFloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateGroupScreen(controller: widget.controller),
            ),
          );
        },
      ),
      body: ScreenShell(
        title: 'Dashboard',
        subtitle: 'Your live travel circles and active family trips.',
        child: RefreshIndicator(
          onRefresh: widget.controller.refreshHomeData,
          child: ListView(
            children: [
              if (groups.isEmpty)
                const EmptyState(
                  title: 'No groups yet',
                  body: 'Create your first TripCircle and invite the family members who are travelling with you.',
                ),
              ...groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GroupCard(
                    group: group,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupTabsScreen(
                            controller: widget.controller,
                            groupId: group.id,
                            groupName: group.name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
