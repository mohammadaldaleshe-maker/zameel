import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_media_storage_uploader.dart';

class CommentImages156 {
  static const bucket = 'comment-images156';
  static Future<List<String>> upload(String post, List<XFile> files) async {
    final db = Supabase.instance.client, user = db.auth.currentUser;
    if (user == null) throw StateError('not_signed_in');
    if (files.length > 5) throw StateError('too_many_comment_images');
    final result = <String>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i], ext = f.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext))
        throw StateError('unsupported_comment_image');
      final path =
          '${user.id}/$post/${DateTime.now().microsecondsSinceEpoch}_$i.$ext';
      await uploadPickedPostMedia(
          client: db,
          bucket: bucket,
          storagePath: path,
          source: f,
          maxBytes: 12 * 1024 * 1024,
          tooLargeError: 'image_too_large_12mb',
          contentType: ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg');
      result.add(path);
    }
    return result;
  }

  static Future<void> resolve(List<Map<String, dynamic>> comments) async {
    final paths = comments
        .expand((c) => List<String>.from(c['image_paths156'] ?? []))
        .toSet()
        .toList();
    if (paths.isEmpty) return;
    final signed = await Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrls(paths, 300);
    final urls = {
      for (final s in signed)
        if (s.signedUrl.isNotEmpty) s.path: s.signedUrl
    };
    for (final c in comments) {
      c['image_urls156'] = [
        for (final p in c['image_paths156'] ?? [])
          if (urls[p] != null) urls[p]
      ];
    }
  }
}
