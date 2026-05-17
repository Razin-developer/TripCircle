import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_logger.dart';
import '../services/socket_service.dart';
import '../services/tripcircle_api.dart';

class AppController extends ChangeNotifier {
  AppController({TripCircleApi? api}) : _api = api ?? TripCircleApi();

  final TripCircleApi _api;

  UserProfile? user;
  String? token;
  String? pendingPhoneNumber;
  bool isBusy = false;
  String? errorMessage;
  List<GroupSummary> groups = const [];
  List<InvitationSummary> invitations = const [];

  bool get isAuthenticated => token != null && user != null;

  Future<void> login(String phoneNumber) async {
    unawaited(
      AppLogger.instance.info(
        'auth',
        'Login started',
        data: {'phoneNumber': phoneNumber.trim()},
      ),
    );
    await _run(() async {
      try {
        final session = await _api.login(phoneNumber.trim());
        token = session.token;
        user = session.user;
        pendingPhoneNumber = null;
        unawaited(_connectSocket());
        await refreshHomeData();
        await AppLogger.instance.info(
          'auth',
          'Login succeeded',
          data: {'userId': user?.id, 'username': user?.username},
        );
      } on TripCircleApiException catch (error) {
        if (error.statusCode == 404 || error.message.contains('User not found')) {
          pendingPhoneNumber = phoneNumber.trim();
          errorMessage = null;
          notifyListeners();
          await AppLogger.instance.info(
            'auth',
            'Login redirected to profile setup',
            data: {'phoneNumber': phoneNumber.trim()},
          );
          return;
        }

        rethrow;
      }
    });
  }

  Future<void> register({
    required String phoneNumber,
    required String name,
    required String username,
  }) async {
    unawaited(
      AppLogger.instance.info(
        'auth',
        'Register started',
        data: {'phoneNumber': phoneNumber.trim(), 'username': username.trim().toLowerCase()},
      ),
    );
    await _run(() async {
      final session = await _api.register(
        phoneNumber: phoneNumber.trim(),
        name: name.trim(),
        username: username.trim().toLowerCase(),
      );
      token = session.token;
      user = session.user;
      pendingPhoneNumber = null;
      unawaited(_connectSocket());
      await refreshHomeData();
      await AppLogger.instance.info(
        'auth',
        'Register succeeded',
        data: {'userId': user?.id, 'username': user?.username},
      );
    });
  }

  Future<void> refreshHomeData() async {
    if (!isAuthenticated) {
      return;
    }

    final currentToken = token!;
    final loadedGroups = await _api.getGroups(currentToken);
    final loadedInvitations = await _api.getInvitations(currentToken);
    groups = loadedGroups;
    invitations = loadedInvitations;
    notifyListeners();
  }

  Future<GroupSummary?> createGroup(String name) async {
    if (!isAuthenticated) {
      return null;
    }

    GroupSummary? createdGroup;
    await _run(() async {
      createdGroup = await _api.createGroup(token: token!, name: name.trim());
      groups = [createdGroup!, ...groups];
      notifyListeners();
    });

    return createdGroup;
  }

  Future<void> updateProfile({
    required String name,
    required String phoneNumber,
    required String username,
  }) async {
    if (!isAuthenticated) {
      return;
    }

    await _run(() async {
      user = await _api.updateProfile(
        token: token!,
        name: name,
        phoneNumber: phoneNumber,
        username: username,
      );
      notifyListeners();
    });
  }

  Future<void> updateTheme(String activeTheme) async {
    if (!isAuthenticated) {
      return;
    }

    await _run(() async {
      user = await _api.updateTheme(token: token!, activeTheme: activeTheme);
      notifyListeners();
    });
  }

  Future<List<UserSearchResult>> searchUsers({
    required String groupId,
    required String query,
  }) async {
    if (!isAuthenticated) {
      return const [];
    }

    return _api.searchUsers(token: token!, groupId: groupId, query: query.trim().toLowerCase());
  }

  Future<void> inviteUsers({
    required String groupId,
    required List<String> usernames,
  }) async {
    if (!isAuthenticated) {
      return;
    }

    await _run(() async {
      await _api.inviteUsers(token: token!, groupId: groupId, usernames: usernames);
    });
  }

  Future<InvitationSummary?> acceptInvitation(String invitationId) async {
    if (!isAuthenticated) {
      return null;
    }

    InvitationSummary? invitation;
    await _run(() async {
      invitation = await _api.acceptInvitation(token: token!, invitationId: invitationId);
      await refreshHomeData();
    });
    return invitation;
  }

  Future<InvitationSummary?> declineInvitation(String invitationId) async {
    if (!isAuthenticated) {
      return null;
    }

    InvitationSummary? invitation;
    await _run(() async {
      invitation = await _api.declineInvitation(token: token!, invitationId: invitationId);
      await refreshHomeData();
    });
    return invitation;
  }

  Future<GroupDetailResponse?> getGroup(String groupId) async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      return await _api.getGroup(token: token!, groupId: groupId);
    } on TripCircleApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Something went wrong.';
      notifyListeners();
      return null;
    }
  }

  Future<List<GroupMember>> getMembers(String groupId) async {
    if (!isAuthenticated) {
      return const [];
    }

    try {
      return await _api.getMembers(token: token!, groupId: groupId);
    } on TripCircleApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return const [];
    } catch (_) {
      errorMessage = 'Something went wrong.';
      notifyListeners();
      return const [];
    }
  }

  Future<GroupSummary?> updateGroup({
    required String groupId,
    String? name,
    String? locationUpdateMode,
    bool? isSharingLocation,
  }) async {
    if (!isAuthenticated) {
      return null;
    }

    GroupSummary? updatedGroup;
    await _run(() async {
      updatedGroup = await _api.updateGroup(
        token: token!,
        groupId: groupId,
        name: name,
        locationUpdateMode: locationUpdateMode,
        isSharingLocation: isSharingLocation,
      );
      await refreshHomeData();
    });

    return updatedGroup;
  }

  Future<void> stopSharing(String groupId) async {
    if (!isAuthenticated) {
      return;
    }

    await _run(() async {
      await _api.stopSharing(token: token!, groupId: groupId);
      await refreshHomeData();
    });
  }

  Future<void> leaveGroup(String groupId) async {
    if (!isAuthenticated) {
      return;
    }

    await _run(() async {
      await _api.leaveGroup(token: token!, groupId: groupId);
      await refreshHomeData();
    });
  }

  Future<void> deleteGroup(String groupId) async {
    if (!isAuthenticated) {
      return;
    }

    await _run(() async {
      await _api.deleteGroup(token: token!, groupId: groupId);
      await refreshHomeData();
    });
  }

  Future<void> ensureSocketConnected() async {
    if (!isAuthenticated) {
      return;
    }

    await _connectSocket();
  }

  void logout() {
    unawaited(
      AppLogger.instance.info(
        'auth',
        'Logout',
        data: {'userId': user?.id, 'username': user?.username},
      ),
    );
    SocketService.instance.disconnect();
    token = null;
    user = null;
    pendingPhoneNumber = null;
    groups = const [];
    invitations = const [];
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    SocketService.instance.disconnect();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final currentToken = token;
    if (currentToken == null || currentToken.isEmpty) {
      return;
    }

    await SocketService.instance.connect(currentToken);
    SocketService.instance.joinUser();
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on TripCircleApiException catch (error) {
      errorMessage = error.message;
      await AppLogger.instance.error(
        'controller',
        'Action failed with API error',
        data: {'message': error.message, 'statusCode': error.statusCode},
      );
      notifyListeners();
    } catch (error) {
      errorMessage = 'Something went wrong.';
      await AppLogger.instance.error(
        'controller',
        'Action failed with unexpected error',
        data: {'error': error.toString()},
      );
      notifyListeners();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
