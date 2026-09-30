import 'package:supabase_flutter/supabase_flutter.dart';

class PostReportingService {
  static Future<bool> submit({
    required String postId,
    required String category,
    required String reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'zameel_report_post',
      params: {
        'p_post_id': postId,
        'p_category': category,
        'p_reason': reason.trim(),
      },
    );
    if (response is! Map || response['report_id'] == null) {
      throw StateError('invalid_report_response');
    }
    return response['already_reported'] == true;
  }
}
