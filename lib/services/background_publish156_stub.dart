import 'friend_wall_service158.dart';
import 'dart:async';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_publish_service.dart';
import '../services_social.dart';

final _tasks156 = <Map<String, dynamic>>[];
final _files156 = <String, List<XFile>>{};
String _id156() {
  final b = List.generate(16, (_) => Random.secure().nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

Future<void> _run156(Map<String, dynamic> task, void Function() changed) async {
  if (task['user'] != Supabase.instance.client.auth.currentUser?.id) return;
  task['state'] = 'running';
  changed();
  final files = _files156[task['id']]!;
  try {
    if (task['kind'] == 'wall') {
      await FriendWallService158.publish(
          id: '${task['id']}',
          owner: '${task['owner']}',
          text: '${task['text']}',
          files: files);
    } else if (task['kind'] == 'post') {
      await PostPublishService.publishPost(
          text: '${task['text']}',
          audience: '${task['audience']}',
          media: [
            for (final f in files)
              PickedPostMedia(source: f, byteSize: await f.length())
          ],
          mentions: List<String>.from(task['mentions'] ?? []),
          jobId: '${task['id']}');
    } else if (task['kind'] == 'clip') {
      await ZameelSocialService.createClipFile(
          file: files.first,
          cover: files.length > 1 ? files[1] : null,
          caption: '${task['text']}',
          mentions: List<String>.from(task['mentions'] ?? []),
          durationSeconds: task['duration'] as int,
          audience: '${task['audience']}',
          jobId: '${task['id']}');
    } else {
      await ZameelSocialService.createStoryFile(
          file: files.first,
          mediaType: '${task['type']}',
          caption: '${task['text']}',
          audience: '${task['audience']}',
          jobId: '${task['id']}');
    }
    task['state'] = 'done';
  } catch (_) {
    task['state'] = 'error';
  }
  changed();
}

Future<String> enqueue156(Map<String, dynamic> data, List<XFile> files,
    void Function() changed) async {
  final user = Supabase.instance.client.auth.currentUser?.id;
  if (user == null) throw StateError('not_signed_in');
  final id = _id156(),
      task = {...data, 'id': id, 'user': user, 'state': 'waiting'};
  _tasks156.add(task);
  _files156[id] = files;
  unawaited(_run156(task, changed));
  return id;
}

Future<void> resume156(void Function() changed) async {}
Future<List<Map<String, dynamic>>> tasks156() async => _tasks156
    .where((r) => r['user'] == Supabase.instance.client.auth.currentUser?.id)
    .toList();
Future<void> retry156(String id, void Function() changed) async {
  for (final task in await tasks156()) {
    if (task['id'] == id && task['state'] == 'error') {
      unawaited(_run156(task, changed));
      return;
    }
  }
}
