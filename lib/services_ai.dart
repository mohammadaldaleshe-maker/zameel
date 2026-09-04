import 'package:supabase_flutter/supabase_flutter.dart';

class ZameelAIService {
  static final _functions = Supabase.instance.client.functions;

  static Future<String> ask(String message, {String mode = 'assistant', String language = 'ar', String university = ''}) async {
    final result = await _functions.invoke('zameel-ai', body: {
      'message': message,
      'mode': mode,
      'language': language,
      'university': university,
    });
    final data = result.data;
    if (data is Map && data['answer'] != null) return data['answer'].toString();
    throw Exception(data is Map ? (data['error'] ?? 'AI request failed') : 'AI request failed');
  }
}
