import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ZameelStudyFilesService {
  static final SupabaseClient db = Supabase.instance.client;

  static String? get uid => db.auth.currentUser?.id;
  static bool get signedIn => uid != null;

  static Future<String> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String title,
    String course = '',
  }) async {
    final userId = uid;
    if (userId == null) throw Exception('Authentication required');

    final extension = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'bin';
    const allowed = {'pdf', 'doc', 'docx', 'ppt', 'pptx'};
    if (!allowed.contains(extension)) throw Exception('Unsupported file type');
    if (bytes.isEmpty) throw Exception('Empty file');
    if (bytes.length > 25 * 1024 * 1024) throw Exception('File is larger than 25 MB');

    final safeName = filename
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final path = '$userId/study/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final mimeType = _mimeType(extension);

    await db.storage.from('study_files').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );

    try {
      final row = await db.from('study_files').insert({
        'user_id': userId,
        'title': title,
        'file_name': filename,
        'file_extension': extension,
        'mime_type': mimeType,
        'file_size': bytes.length,
        'course': course,
        'storage_path': path,
      }).select('id').single();
      return row['id'] as String;
    } catch (e) {
      try {
        await db.storage.from('study_files').remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> listFiles() async {
    if (!signedIn) return [];
    final rows = await db
        .from('study_files')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String?> createSignedUrl(String path) async {
    if (!signedIn) return null;
    return db.storage.from('study_files').createSignedUrl(path, 3600);
  }

  static Future<void> deleteFile(Map<String, dynamic> file) async {
    final userId = uid;
    if (userId == null || file['user_id']?.toString() != userId) {
      throw Exception('Not allowed');
    }
    final path = file['storage_path']?.toString();
    if (path == null || path.isEmpty) throw Exception('Missing file path');
    await db.from('study_files').delete().eq('id', file['id']);
    await db.storage.from('study_files').remove([path]);
  }

  static String _mimeType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }
}
