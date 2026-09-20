import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<int> uploadPickedPostMedia({
  required SupabaseClient client,
  required String bucket,
  required String storagePath,
  required XFile source,
  required int maxBytes,
  required String tooLargeError,
  required String contentType,
}) async {
  final path = source.path.trim();
  if (path.isNotEmpty) {
    final localFile = File(path);
    if (await localFile.exists()) {
      final size = await localFile.length();
      if (size <= 0) throw StateError('media_bytes_unavailable');
      if (size > maxBytes) throw StateError(tooLargeError);
      await client.storage.from(bucket).upload(
            storagePath,
            localFile,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '31536000',
              upsert: false,
            ),
          );
      return size;
    }
  }

  // Some providers expose an XFile without a durable filesystem path. Fall
  // back to bytes only in that case; one file is handled at a time.
  final bytes = await source.readAsBytes();
  if (bytes.isEmpty) throw StateError('media_bytes_unavailable');
  if (bytes.length > maxBytes) throw StateError(tooLargeError);
  await client.storage.from(bucket).uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '31536000',
          upsert: false,
        ),
      );
  return bytes.length;
}
