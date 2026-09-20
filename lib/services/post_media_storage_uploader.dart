import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'post_media_storage_uploader_stub.dart'
    if (dart.library.io) 'post_media_storage_uploader_io.dart' as platform;

/// Upload one picked media item without making the shared publisher depend on
/// `dart:io`. Native builds stream from a File path when available; web builds
/// use XFile bytes. The returned value is the verified uploaded byte size.
Future<int> uploadPickedPostMedia({
  required SupabaseClient client,
  required String bucket,
  required String storagePath,
  required XFile source,
  required int maxBytes,
  required String tooLargeError,
  required String contentType,
}) =>
    platform.uploadPickedPostMedia(
      client: client,
      bucket: bucket,
      storagePath: storagePath,
      source: source,
      maxBytes: maxBytes,
      tooLargeError: tooLargeError,
      contentType: contentType,
    );
