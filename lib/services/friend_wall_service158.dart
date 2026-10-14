import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_media_storage_uploader.dart';

class FriendWallService158 {
  static final db = Supabase.instance.client;
  static Future<bool> complete(String id) async =>
      await db.rpc('zameel_wall_status158', params: {'p_id': id}) == true;
  static Future<void> publish(
      {required String id,
      required String owner,
      required String text,
      required List<XFile> files}) async {
    if (await complete(id)) return;
    final actor = db.auth.currentUser?.id;
    if (actor == null) throw StateError('not_signed_in');
    final media = <Map<String, String>>[];
    var total = 0;
    if (files.length > 10) throw StateError('too_many_media');
    for (var i = 0; i < files.length; i++) {
      final f = files[i], ext = f.name.split('.').last.toLowerCase();
      const types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'webm': 'video/webm'
      };
      final mime = types[ext];
      if (mime == null) throw StateError('unsupported_media');
      total += await f.length();
      if (total > 150 * 1024 * 1024) throw StateError('media_too_large');
      final path = '$actor/$id/$i.$ext';
      // A lost RPC response can retry without uploading existing files again.
      final exists = await db.rpc('zameel_wall_upload_exists158',
          params: {'p_id': id, 'p_path': path});
      if (exists != true)
        await uploadPickedPostMedia(
            client: db,
            bucket: 'zameel_wall158',
            storagePath: path,
            source: f,
            maxBytes:
                mime.startsWith('video') ? 80 * 1024 * 1024 : 12 * 1024 * 1024,
            tooLargeError: 'media_too_large',
            contentType: mime);
      media.add(
          {'path': path, 'type': mime.startsWith('video') ? 'video' : 'image'});
    }
    if (db.auth.currentUser?.id != actor) throw StateError('account_changed');
    await db.rpc('zameel_wall_create158', params: {
      'p_owner': owner,
      'p_id': id,
      'p_content': text,
      'p_media': media
    });
  }
}
