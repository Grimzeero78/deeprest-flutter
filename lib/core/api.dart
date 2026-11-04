// ============================================================
// DeepRest API client — talks to the SAME Cloudflare backend as
// the website. Auth: JWT in SharedPreferences, sent as
// `Authorization: Bearer <token>` (web uses a cookie; the Bearer
// path is checked first by requireSession).
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiError implements Exception {
  final String message;
  final int status;
  ApiError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = 'https://deeprest-app.dev078.workers.dev';
  static const _tokenKey = 'deeprest_jwt';
  static const _nameKey = 'deeprest_name';
  static String? _token;

  static String? get token => _token;

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString(_tokenKey);
  }

  static Future<void> saveSession(String token, String name) async {
    _token = token;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, token);
    await sp.setString(_nameKey, name);
  }

  static Future<void> clearSession() async {
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
    await sp.remove(_nameKey);
  }

  static Future<String?> storedName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_nameKey);
  }

  // ---------- core request ----------
  static Future<Map<String, dynamic>> _run(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) headers['Authorization'] = 'Bearer $_token!';
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 25));
      final res = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 25));
      return _handle(res);
    } on TimeoutException {
      throw ApiError('Network timeout — check your connection.');
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError('Cannot reach DeepRest. Are you online?');
    }
  }

  static Map<String, dynamic> _handle(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      json = <String, dynamic>{};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (json['error'] as String?) ?? 'Request failed (${res.statusCode})';
      throw ApiError(msg, res.statusCode);
    }
    return json;
  }

  static Future<Map<String, dynamic>> get(String path) => _run('GET', path, null);
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _run('POST', path, body);
  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _run('PATCH', path, body);
  static Future<Map<String, dynamic>> delete(String path) => _run('DELETE', path, null);

  // ---------- auth ----------
  static Future<void> register(
      String name, String password, String confirmPassword, String hint) async {
    final r = await post('/api/auth/register', {
      'name': name,
      'password': password,
      'confirmPassword': confirmPassword,
      'hint': hint,
    });
    await saveSession(r['token'] as String, name);
  }

  static Future<void> login(String name, String password) async {
    final r = await post('/api/auth/login', {'name': name, 'password': password});
    await saveSession(r['token'] as String, (r['user']?['name'] ?? name) as String);
  }

  static Future<void> logout() async {
    try {
      await post('/api/auth/logout', {});
    } catch (_) {}
    await clearSession();
  }

  // ---------- presence ----------
  static Future<void> heartbeat() async {
    try {
      await post('/api/presence', {});
    } catch (_) {}
  }

  // ---------- me / dashboard ----------
  static Future<Map<String, dynamic>> me() => get('/api/auth/me');

  static Future<void> setTarget(int minutes) =>
      post('/api/screentime', {'action': 'target', 'minutes': minutes});

  // ---------- community ----------
  static Future<List<dynamic>> users({String q = ''}) async {
    final r = await get('/api/users?q=${Uri.encodeComponent(q)}&limit=100');
    return (r['users'] as List?) ?? [];
  }

  // ---------- conversations ----------
  static Future<List<dynamic>> conversations() async {
    final r = await get('/api/social/conversations');
    return (r['conversations'] as List?) ?? [];
  }

  static Future<String> startDm(String userId) async {
    final r = await post('/api/social/conversations', {'kind': 'dm', 'userId': userId});
    return r['conversationId'] as String;
  }

  static Future<String> createGroup(String name, String emoji, List<String> memberIds) async {
    final r = await post(
        '/api/social/conversations', {'kind': 'group', 'name': name, 'emoji': emoji, 'memberIds': memberIds});
    return r['conversationId'] as String;
  }

  static Future<List<dynamic>> messages(String convoId) async {
    final r = await get('/api/social/conversations/$convoId/messages');
    return (r['messages'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> sendMessage(String convoId, String body) =>
      post('/api/social/conversations/$convoId', {'body': body});

  static Future<void> markRead(String convoId) async {
    try {
      await patch('/api/social/conversations/$convoId', {'action': 'read'});
    } catch (_) {}
  }

  static Future<void> leaveGroup(String convoId) => delete('/api/social/conversations/$convoId');

  // ---------- SOS ----------
  static Future<Map<String, dynamic>> sosAll() => get('/api/sos');

  static Future<void> sosSend(String message) =>
      post('/api/sos', {'confirmed': true, 'message': message});

  static Future<Map<String, dynamic>> sosAck(String alertId) =>
      patch('/api/sos', {'id': alertId});

  // ---------- duo ----------
  static Future<Map<String, dynamic>> duo() => get('/api/duo');

  static Future<String> duoInvite() async {
    final r = await post('/api/duo', {'action': 'invite'});
    return r['inviteCode'] as String;
  }

  static Future<void> duoAccept(String code) =>
      post('/api/duo', {'action': 'accept', 'code': code});

  static Future<void> duoUnbind() => post('/api/duo', {'action': 'unbind'});

  // ---------- leaderboard ----------
  static Future<Map<String, dynamic>> leaderboard() => get('/api/leaderboard');

  // ---------- AI companions ----------
  static Future<Map<String, dynamic>> aiGet(String persona) =>
      get('/api/chat?persona=$persona');

  static Future<String> aiSend(String persona, String message) async {
    final r = await post('/api/chat', {'persona': persona, 'message': message});
    return (r['message']?['content'] ?? '') as String;
  }

  static Future<void> aiClear(String persona) => delete('/api/chat?persona=$persona');

  // ---------- profile ----------
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) =>
      patch('/api/profile', data);

  static Future<void> changePassword(String current, String next) =>
      post('/api/profile', {'currentPassword': current, 'newPassword': next});

  // ---------- calls ----------
  static Future<Map<String, dynamic>> callState() => get('/api/call');
  static Future<void> callStart() => post('/api/call', {});
  static Future<void> callAction(String callId, String action) =>
      patch('/api/call', {'callId': callId, 'action': action});
}
