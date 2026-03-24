import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_sync_service.dart' show getBackendTokenAsync;

class AssistantAction {
  final String type;
  final String? screen;

  const AssistantAction({required this.type, this.screen});

  factory AssistantAction.fromJson(Map<String, dynamic> j) {
    return AssistantAction(
      type: j['type'] as String? ?? '',
      screen: j['screen'] as String?,
    );
  }
}

class AssistantResult {
  final String reply;
  final List<AssistantAction> actions;

  const AssistantResult({required this.reply, required this.actions});
}

class AiAssistantException implements Exception {
  final String message;
  AiAssistantException(this.message);

  @override
  String toString() => message;
}

class AiAssistantService {
  AiAssistantService._();

  /// `messages`: len role `user` / `assistant` a text `content`.
  static Future<AssistantResult> sendMessage(List<Map<String, String>> messages) async {
    final token = await getBackendTokenAsync();
    if (token == null || token.isEmpty) {
      throw AiAssistantException('Nie ste prihlásený.');
    }
    final uri = Uri.parse('${AppConfig.apiBase}/ai/assistant');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'messages': messages}),
    );
    Map<String, dynamic> map;
    try {
      map = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiAssistantException('Neplatná odpoveď servera (${resp.statusCode}).');
    }
    if (resp.statusCode != 200 || map['success'] != true) {
      throw AiAssistantException(map['error']?.toString() ?? 'Chyba servera');
    }
    final rawActions = map['actions'] as List<dynamic>? ?? [];
    final actions = rawActions
        .map((e) => AssistantAction.fromJson(e as Map<String, dynamic>))
        .where((a) => a.type == 'navigate' && (a.screen ?? '').isNotEmpty)
        .toList();
    return AssistantResult(
      reply: map['reply'] as String? ?? '',
      actions: actions,
    );
  }
}
