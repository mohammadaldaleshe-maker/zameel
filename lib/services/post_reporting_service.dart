import 'package:supabase_flutter/supabase_flutter.dart';

class PostReportingService {
  static Future<bool> submit({
    required String postId,
    required String category,
    required String reason,
    String contentType = 'post',
  }) async {
    const allowedTypes = <String>{'post', 'clip', 'story'};
    if (!allowedTypes.contains(contentType)) {
      throw ArgumentError.value(contentType, 'contentType');
    }
    final response = await Supabase.instance.client.rpc(
      contentType == 'post' ? 'zameel_report_post' : 'zameel_report_media',
      params: {
        if (contentType == 'post') 'p_post_id': postId,
        if (contentType != 'post') ...{
          'p_content_type': contentType, 'p_content_id': postId,
        },
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
