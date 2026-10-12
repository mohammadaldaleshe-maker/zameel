import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_publish_service.dart';
import '../widgets/post_media_gallery.dart';
import 'media_cache_service.dart';

Future<void> sharePostExternally156(BuildContext context, String id) async {
  try {
    final row = await Supabase.instance.client
        .from('posts')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null ||
        row['audience'] != 'public' ||
        row['is_hidden'] == true ||
        row['upload_state156'] == 'pending') {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('المشاركة الخارجية متاحة للمنشورات العامة الجاهزة')));
      return;
    }
    final post = Map<String, dynamic>.from(row), files = <XFile>[];
    for (final item
        in postMediaItems(post).take(PostPublishService.maxMediaItems)) {
      final uri = Uri.tryParse(item.url);
      if (uri == null ||
          uri.scheme != 'https' ||
          !uri.path.contains('/storage/v1/object/public/')) continue;
      final local = await MediaCacheService.localPathForUrl(item.url);
      if (local != null)
        files.add(XFile(local,
            mimeType: const {
                  'png': 'image/png',
                  'webp': 'image/webp',
                  'gif': 'image/gif',
                  'webm': 'video/webm',
                  'mov': 'video/quicktime',
                  'mp4': 'video/mp4',
                  'jpg': 'image/jpeg',
                  'jpeg': 'image/jpeg'
                }[uri.path.split('.').last.toLowerCase()] ??
                (item.isVideo ? 'video/mp4' : 'image/jpeg'),
            name: item.name ??
                (item.isVideo ? 'zameel-video.mp4' : 'zameel-image.jpg')));
    }
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
        text:
            '${post['text_ar'] ?? post['text_en'] ?? ''}\n\nمنشور من زميل\nzameel://post/$id',
        files: files.isEmpty ? null : files,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تجهيز المشاركة الخارجية. أعد المحاولة.')));
  }
}
