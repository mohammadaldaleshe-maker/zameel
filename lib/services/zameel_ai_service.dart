import 'package:supabase_flutter/supabase_flutter.dart';

class ZameelAIResult {
  final String answer;
  final String? conversationId;
  final int remaining;
  final bool verified;
  final List<Map<String, dynamic>> sources;

  const ZameelAIResult({
    required this.answer,
    required this.conversationId,
    required this.remaining,
    required this.verified,
    required this.sources,
  });
}

class ZameelAIService {
  static final _client = Supabase.instance.client;

  Future<ZameelAIResult> ask({
    required String prompt,
    required String mode,
    String? conversationId,
  }) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke('zameel-ai', body: {
        'message': prompt,
        'mode': mode,
        if (conversationId != null) 'conversation_id': conversationId,
      });
    } on FunctionException catch (_) {
      throw Exception('تعذر الحصول على إجابة الآن. حاول بعد قليل.');
    }
    final raw = response.data;
    if (raw is! Map) throw Exception('invalid_ai_response');
    if (raw['error'] != null) {
      throw Exception(raw['message']?.toString() ?? 'تعذر الحصول على إجابة.');
    }
    return ZameelAIResult(
      answer: raw['answer']?.toString() ?? '',
      conversationId: raw['conversation_id']?.toString(),
      remaining: int.tryParse(raw['remaining']?.toString() ?? '') ?? 0,
      verified: raw['source_type'] == 'verified_faq',
      sources: raw['sources'] is List
          ? (raw['sources'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [],
    );
  }

  Future<void> clearHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('ai_conversations').delete().eq('user_id', userId);
  }

  Future<bool> memoryEnabled() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('users')
        .select('ai_memory_enabled')
        .eq('id', userId)
        .maybeSingle();
    return row?['ai_memory_enabled'] != false;
  }

  Future<void> setMemoryEnabled(bool enabled) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('users')
        .update({'ai_memory_enabled': enabled}).eq('id', userId);
  }

  Future<bool> canManageKnowledge() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return const {'owner', 'admin'}
        .contains(row?['role']?.toString().toLowerCase());
  }
}
