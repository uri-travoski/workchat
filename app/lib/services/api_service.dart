import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/attachment.dart';

class ApiService {
  String baseUrl;
  String? token;

  ApiService({required this.baseUrl, this.token});

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/login'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'device_name': Platform.operatingSystem,
        'client_version': '1.1.0',
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> loginWithToken(String linkToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/login/link'),
      headers: _headers,
      body: jsonEncode({
        'token': linkToken,
        'device_name': Platform.operatingSystem,
        'client_version': '1.1.0',
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Login link failed');
  }

  Future<Map<String, dynamic>> fetchBootstrap() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/sync/bootstrap'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to bootstrap sync');
  }

  Future<List<User>> fetchUsers() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/users'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<Message>> fetchHistory(String convId, {int? beforeSeq, int limit = 50}) async {
    var url = '$baseUrl/api/v1/conversations/$convId/messages?limit=$limit';
    if (beforeSeq != null) {
      url += '&before_seq=$beforeSeq';
    }
    final res = await http.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Message> sendMessage({
    required String convId,
    required String body,
    String? threadRoot,
    String? replyTo,
    List<String> attachmentIds = const [],
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/conversations/$convId/messages'),
      headers: _headers,
      body: jsonEncode({
        'body': body,
        'thread_root': threadRoot,
        'reply_to': replyTo,
        'attachment_ids': attachmentIds,
      }),
    );
    if (res.statusCode == 201) {
      return Message.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to send message');
  }

  Future<Attachment> uploadFile(File file, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/files'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: filename));
    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);
    if (res.statusCode == 201) {
      return Attachment.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Upload failed: ${res.statusCode}');
  }

  Future<void> markRead(String convId, int seq) async {
    await http.post(
      Uri.parse('$baseUrl/api/v1/conversations/$convId/read'),
      headers: _headers,
      body: jsonEncode({'seq': seq}),
    );
  }

  Future<void> addReaction(String messageId, String emoji) async {
    await http.put(
      Uri.parse('$baseUrl/api/v1/messages/$messageId/reactions/$emoji'),
      headers: _headers,
    );
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    await http.delete(
      Uri.parse('$baseUrl/api/v1/messages/$messageId/reactions/$emoji'),
      headers: _headers,
    );
  }

  Future<String> createDM(String targetUserId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/conversations/dm'),
      headers: _headers,
      body: jsonEncode({'target_user_id': targetUserId}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body)['id'] as String;
    }
    throw Exception('Failed to create DM');
  }

  Future<Conversation> createChannel(String name, String topic, List<String> members) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/conversations'),
      headers: _headers,
      body: jsonEncode({
        'kind': 'channel',
        'name': name,
        'topic': topic,
        'members': members,
      }),
    );
    if (res.statusCode == 201) {
      return Conversation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create channel');
  }

  Future<List<Message>> fetchThreadMessages(String convId, String rootMsgId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/conversations/$convId/threads/$rootMsgId'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
