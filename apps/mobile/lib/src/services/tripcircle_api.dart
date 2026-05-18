import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/app_models.dart';
import 'app_logger.dart';

class TripCircleApiException implements Exception {
  const TripCircleApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TripCircleApi {
  TripCircleApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('${AppConfig.apiBaseUrl}/api$path').replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final stopwatch = Stopwatch()..start();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    late final http.Response response;
    final uri = _uri(path, queryParameters);
    final payload = body == null ? null : jsonEncode(body);

    await AppLogger.instance.info(
      'http',
      'HTTP request started',
      data: {
        'method': method,
        'url': uri.toString(),
        'queryParameters': queryParameters,
        'body': body,
      },
    );

    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 60));
          break;
        case 'POST':
          response = await _client.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 60));
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: payload).timeout(const Duration(seconds: 60));
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 60));
          break;
        default:
          throw const TripCircleApiException('Unsupported request method.');
      }
    } on TimeoutException catch (error) {
      await AppLogger.instance.error(
        'http',
        'HTTP request timed out',
        data: {
          'method': method,
          'url': uri.toString(),
          'durationMs': stopwatch.elapsedMilliseconds,
          'message': error.message,
        },
      );
      throw const TripCircleApiException('Request timed out. Please check your internet and try again.');
    } on SocketException catch (error) {
      await AppLogger.instance.error(
        'http',
        'HTTP network failure',
        data: {
          'method': method,
          'url': uri.toString(),
          'durationMs': stopwatch.elapsedMilliseconds,
          'message': error.message,
        },
      );
      throw const TripCircleApiException('Network error. Please check your internet connection.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      await AppLogger.instance.error(
        'http',
        'HTTP response JSON decode failed',
        data: {
          'method': method,
          'url': uri.toString(),
          'statusCode': response.statusCode,
          'durationMs': stopwatch.elapsedMilliseconds,
          'responseBody': response.body,
        },
      );
      throw const TripCircleApiException('Server returned an invalid response.');
    }

    if (response.statusCode >= 400) {
      await AppLogger.instance.warning(
        'http',
        'HTTP request failed',
        data: {
          'method': method,
          'url': uri.toString(),
          'statusCode': response.statusCode,
          'durationMs': stopwatch.elapsedMilliseconds,
          'response': decoded,
        },
      );
      throw TripCircleApiException(
        decoded['message'] as String? ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    await AppLogger.instance.info(
      'http',
      'HTTP request completed',
      data: {
        'method': method,
        'url': uri.toString(),
        'statusCode': response.statusCode,
        'durationMs': stopwatch.elapsedMilliseconds,
        'response': decoded,
      },
    );

    return decoded;
  }

  Future<SessionResponse> login(String phoneNumber) async {
    final json = await _send('POST', '/auth/login', body: {'phoneNumber': phoneNumber});
    return SessionResponse.fromJson(json);
  }

  Future<SessionResponse> register({
    required String phoneNumber,
    required String name,
    required String username,
  }) async {
    final json = await _send(
      'POST',
      '/auth/register',
      body: {
        'phoneNumber': phoneNumber,
        'name': name,
        'username': username,
      },
    );
    return SessionResponse.fromJson(json);
  }

  Future<UserProfile> updateProfile({
    required String token,
    required String name,
    required String phoneNumber,
    required String username,
  }) async {
    final json = await _send(
      'PATCH',
      '/users/me',
      token: token,
      body: {
        'name': name,
        'phoneNumber': phoneNumber,
        'username': username,
      },
    );
    return UserProfile.fromJson(json['user'] as Map<String, dynamic>? ?? const {});
  }

  Future<UserProfile> updateTheme({
    required String token,
    required String activeTheme,
  }) async {
    final json = await _send(
      'PATCH',
      '/users/me/theme',
      token: token,
      body: {'activeTheme': activeTheme},
    );
    return UserProfile.fromJson(json['user'] as Map<String, dynamic>? ?? const {});
  }

  Future<List<GroupSummary>> getGroups(String token) async {
    final json = await _send('GET', '/groups', token: token);
    final groups = json['groups'] as List<dynamic>? ?? const [];
    return groups.map((item) => GroupSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GroupSummary> createGroup({
    required String token,
    required String name,
  }) async {
    final json = await _send('POST', '/groups', token: token, body: {'name': name});
    return GroupSummary.fromJson(json['group'] as Map<String, dynamic>? ?? const {});
  }

  Future<List<InvitationSummary>> getInvitations(String token) async {
    final json = await _send('GET', '/invitations', token: token);
    final invitations = json['invitations'] as List<dynamic>? ?? const [];
    return invitations.map((item) => InvitationSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<UserSearchResult>> searchUsers({
    required String token,
    required String groupId,
    required String query,
  }) async {
    final json = await _send(
      'GET',
      '/users/search',
      token: token,
      queryParameters: {
        'q': query,
        'groupId': groupId,
      },
    );
    final users = json['users'] as List<dynamic>? ?? const [];
    return users.map((item) => UserSearchResult.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> inviteUsers({
    required String token,
    required String groupId,
    required List<String> usernames,
  }) async {
    await _send(
      'POST',
      '/groups/$groupId/invitations',
      token: token,
      body: {'usernames': usernames},
    );
  }

  Future<InvitationSummary> acceptInvitation({
    required String token,
    required String invitationId,
  }) async {
    final json = await _send('POST', '/invitations/$invitationId/accept', token: token);
    return InvitationSummary.fromJson(json['invitation'] as Map<String, dynamic>? ?? const {});
  }

  Future<InvitationSummary> declineInvitation({
    required String token,
    required String invitationId,
  }) async {
    final json = await _send('POST', '/invitations/$invitationId/decline', token: token);
    return InvitationSummary.fromJson(json['invitation'] as Map<String, dynamic>? ?? const {});
  }

  Future<GroupDetailResponse> getGroup({
    required String token,
    required String groupId,
  }) async {
    final json = await _send('GET', '/groups/$groupId', token: token);
    return GroupDetailResponse.fromJson(json);
  }

  Future<List<GroupMember>> getMembers({
    required String token,
    required String groupId,
  }) async {
    final json = await _send('GET', '/groups/$groupId/members', token: token);
    final members = json['members'] as List<dynamic>? ?? const [];
    return members.map((item) => GroupMember.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GroupSummary> updateGroup({
    required String token,
    required String groupId,
    String? name,
    String? locationUpdateMode,
    bool? isSharingLocation,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (locationUpdateMode != null) body['locationUpdateMode'] = locationUpdateMode;
    if (isSharingLocation != null) body['isSharingLocation'] = isSharingLocation;

    final json = await _send('PATCH', '/groups/$groupId', token: token, body: body);
    return GroupSummary.fromJson(json['group'] as Map<String, dynamic>? ?? const {});
  }

  Future<void> stopSharing({
    required String token,
    required String groupId,
  }) async {
    await _send('POST', '/groups/$groupId/stop-sharing', token: token);
  }

  Future<void> leaveGroup({
    required String token,
    required String groupId,
  }) async {
    await _send('POST', '/groups/$groupId/leave', token: token);
  }

  Future<void> deleteGroup({
    required String token,
    required String groupId,
  }) async {
    await _send('DELETE', '/groups/$groupId', token: token);
  }
}
