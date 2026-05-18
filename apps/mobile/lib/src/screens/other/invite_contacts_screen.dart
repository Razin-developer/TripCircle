import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';
import '../group/group_tabs_screen.dart';

class InviteContactsScreen extends StatefulWidget {
  const InviteContactsScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupName,
  });

  final AppController controller;
  final String groupId;
  final String groupName;

  @override
  State<InviteContactsScreen> createState() => _InviteContactsScreenState();
}

class _InviteContactsScreenState extends State<InviteContactsScreen> {
  final TextEditingController searchController = TextEditingController();
  List<UserSearchResult> results = const [];
  List<UserSearchResult> selectedUsers = const [];
  bool isSearching = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim().toLowerCase();

    if (trimmed.isEmpty) {
      setState(() {
        results = const [];
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    final found = await widget.controller.searchUsers(groupId: widget.groupId, query: trimmed);
    if (!mounted) {
      return;
    }

    setState(() {
      results = found.where((item) => !selectedUsers.any((selected) => selected.id == item.id)).toList();
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenShell(
        screenName: 'InviteContactsScreen',
        logData: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        },
        title: 'Add Members',
        subtitle: 'Search only by username. Each letter checks the backend and shows the top five matches.',
        child: ListView(
          children: [
            TextField(
              controller: searchController,
              textCapitalization: TextCapitalization.none,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search usernames',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (selectedUsers.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...selectedUsers.map(
                      (user) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(user.name),
                        subtitle: Text('@${user.username}'),
                        trailing: TextButton(
                          onPressed: () {
                            setState(() {
                              selectedUsers = selectedUsers.where((item) => item.id != user.id).toList();
                            });
                            _search(searchController.text);
                          },
                          child: const Text('Remove'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (isSearching)
              const GlassCard(
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 12),
                    Expanded(child: Text('Searching usernames...')),
                  ],
                ),
              )
            else if (results.isEmpty)
              EmptyState(
                title: searchController.text.isEmpty ? 'Search by username' : 'No usernames match',
                body: searchController.text.isEmpty
                    ? 'Start typing and we will fetch up to five matching usernames.'
                    : 'Try a different username spelling.',
              )
            else
              ...results.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(user.name),
                      subtitle: Text('@${user.username}'),
                      trailing: TextButton(
                        onPressed: () {
                          setState(() {
                            selectedUsers = [...selectedUsers, user];
                            results = results.where((item) => item.id != user.id).toList();
                          });
                        },
                        child: const Text('Select'),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: selectedUsers.isEmpty ? 'Invite' : 'Invite ${selectedUsers.length}',
              isLoading: widget.controller.isBusy,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                if (selectedUsers.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Pick at least one username to invite.')),
                  );
                  return;
                }

                await widget.controller.inviteUsers(
                  groupId: widget.groupId,
                  usernames: selectedUsers.map((user) => user.username).toList(),
                );

                if (!mounted) {
                  return;
                }

                final message = widget.controller.errorMessage ?? 'Invitations sent.';
                messenger.showSnackBar(SnackBar(content: Text(message)));

                if (widget.controller.errorMessage == null) {
                  navigator.pushReplacement(
                    MaterialPageRoute(
                      settings: RouteSettings(name: 'GroupTabsScreen:${widget.groupId}'),
                      builder: (_) => GroupTabsScreen(
                        controller: widget.controller,
                        groupId: widget.groupId,
                        groupName: widget.groupName,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Skip for Now',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    settings: RouteSettings(name: 'GroupTabsScreen:${widget.groupId}'),
                    builder: (_) => GroupTabsScreen(
                      controller: widget.controller,
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                    ),
                  ),
                );
              },
              variant: 'ghost',
            ),
          ],
        ),
      ),
    );
  }
}
