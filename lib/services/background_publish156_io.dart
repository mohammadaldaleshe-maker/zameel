import 'post_presentation157.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_publish_service.dart';
import '../services_social.dart';
import 'shorts_video_preparer.dart';

const _native156 = MethodChannel('zameel/uploads156');
final _jobs156 = <String, List<Map<String, dynamic>>>{};
bool _running156 = false;
Future<void> _disk156 = Future.value();
String _uuid156() {
  final b = List.generate(16, (_) => Random.secure().nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

Future<Directory> _root156(String user) async {
  final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/uploads156/$user');
  await root.create(recursive: true);
  return root;
}

Future<List<Map<String, dynamic>>> _load156(String user) async {
  if (_jobs156.containsKey(user)) return _jobs156[user]!;
  final f = File('${(await _root156(user)).path}/jobs.json');
  List<Map<String, dynamic>> rows = [];
  if (await f.exists()) {
    rows = List<Map<String, dynamic>>.from(
        jsonDecode(await f.readAsString()) as List);
  }
  return _jobs156[user] = rows;
}

Future<void> _save156(String user) {
  final next = _disk156.catchError((_) {}).then((_) async {
    final root = await _root156(user), tmp = File('${root.path}/jobs.tmp');
    await tmp.writeAsString(jsonEncode(_jobs156[user]), flush: true);
    await tmp.rename('${root.path}/jobs.json');
  });
  _disk156 = next;
  return next;
}

Future<void> _nativeCall156(String name, [Map<String, dynamic>? args]) async {
  try {
    await _native156.invokeMethod<void>(name, args);
  } on MissingPluginException {
    // Web/iOS lack the Android foreground service; tasks remain durable.
  } on PlatformException {
    // The OS may deny a foreground service start; jobs stay available for retry.
  }
}

Future<String> enqueue156(Map<String, dynamic> data, List<XFile> files,
    void Function() changed) async {
  final user = Supabase.instance.client.auth.currentUser?.id;
  if (user == null) throw StateError('not_signed_in');
  final jobs = await _load156(user);
  if (jobs.where((j) => j['state'] != 'done').length >= 5)
    throw StateError('upload_queue_full_5');
  final id = _uuid156(),
      folder = Directory('${(await _root156(user)).path}/$id');
  await folder.create();
  final paths = <Map<String, dynamic>>[];
  try {
    for (var i = 0; i < files.length; i++) {
      final file = files[i],
          name = file.name.replaceAll(RegExp(r'[^\w.\-]'), '_'),
          path = '${folder.path}/${i}_$name';
      final bytes = await file.length();
      if (bytes <= 0 || bytes > 80 * 1024 * 1024)
        throw StateError('invalid_upload_size');
      if (await File(file.path).exists()) {
        await File(file.path).copy(path);
      } else {
        await File(path).writeAsBytes(await file.readAsBytes(), flush: true);
      }
      paths.add({'path': path, 'name': file.name, 'size': bytes});
    }
    if (Supabase.instance.client.auth.currentUser?.id != user)
      throw StateError('account_changed');
    jobs.add({
      ...data,
      'id': id,
      'user': user,
      'files': paths,
      'state': 'waiting',
      'created_at': DateTime.now().toUtc().toIso8601String()
    });
    await _save156(user);
  } catch (_) {
    if (await folder.exists()) await folder.delete(recursive: true);
    rethrow;
  }
  await _nativeCall156('start');
  changed();
  unawaited(_pump156(changed));
  return id;
}

Future<void> _pump156(void Function() changed) async {
  if (_running156) return;
  _running156 = true;
  String? user;
  try {
    user = Supabase.instance.client.auth.currentUser?.id;
    if (user == null) return;
    final jobs = await _load156(user);
    while (jobs.any((j) => ['waiting', 'running'].contains(j['state']))) {
      final job =
          jobs.firstWhere((j) => ['waiting', 'running'].contains(j['state']));
      if (Supabase.instance.client.auth.currentUser?.id != user) break;
      job['state'] = 'running';
      await _save156(user);
      changed();
      try {
        final kind = job['kind'],
            table = kind == 'post'
                ? 'posts'
                : kind == 'clip'
                    ? 'clips'
                    : 'social_stories';
        final db = Supabase.instance.client;
        final prior = await db
            .from(table)
            .select()
            .eq('id', job['id'])
            .eq('user_id', user)
            .maybeSingle();
        final complete = prior != null &&
            (kind == 'post'
                ? completedMediaPost157(prior)
                : prior['upload_state156'] == 'ready' &&
                    '${prior[kind == 'clip' ? 'video_url' : 'media_url'] ?? ''}'
                        .isNotEmpty &&
                    !'${prior[kind == 'clip' ? 'video_url' : 'media_url'] ?? ''}'
                        .startsWith('uploading://'));
        if (!complete) {
          final files = [
            for (final f in job['files'] as List)
              XFile('${f['path']}', name: '${f['name']}')
          ];
          if (kind == 'post') {
            await PostPublishService.publishPost(
                text: '${job['text']}',
                audience: '${job['audience']}',
                media: [
                  for (final f in files)
                    PickedPostMedia(source: f, byteSize: await f.length())
                ],
                mentions: List<String>.from(job['mentions'] ?? []),
                jobId: '${job['id']}');
          } else if (kind == 'clip') {
            final prepared = await prepareShortVideo(files.first,
                cover: files.length > 1 ? files[1] : null);
            try {
              await ZameelSocialService.createClipFile(
                  file: prepared.video,
                  cover: prepared.cover,
                  caption: '${job['text']}',
                  durationSeconds: job['duration'] as int,
                  audience: '${job['audience']}',
                  jobId: '${job['id']}');
            } finally {
              await prepared.cleanup();
            }
          } else {
            await ZameelSocialService.createStoryFile(
                file: files.first,
                mediaType: '${job['type']}',
                caption: '${job['text']}',
                audience: '${job['audience']}',
                jobId: '${job['id']}');
          }
        }
        job['state'] = 'done';
        job.remove('error');
        await _save156(user);
        final folder = Directory('${(await _root156(user)).path}/${job['id']}');
        if (await folder.exists()) await folder.delete(recursive: true);
      } catch (error) {
        job['state'] = 'error';
        job['error'] = error.runtimeType.toString();
        await _save156(user);
        if (Supabase.instance.client.auth.currentUser?.id == user)
          await _nativeCall156('failed', {'id': job['id']});
      }
      changed();
    }
  } finally {
    _running156 = false;
    await _nativeCall156('stop');
  }
}

Future<void> resume156(void Function() changed) async {
  final user = Supabase.instance.client.auth.currentUser?.id;
  if (user == null) return;
  await _load156(user);
  if (_jobs156[user]!.any((j) => ['waiting', 'running'].contains(j['state']))) {
    await _nativeCall156('start');
    unawaited(_pump156(changed));
  }
}

Future<List<Map<String, dynamic>>> tasks156() async {
  final user = Supabase.instance.client.auth.currentUser?.id;
  return user == null
      ? []
      : List<Map<String, dynamic>>.from(await _load156(user));
}

Future<void> retry156(String id, void Function() changed) async {
  final user = Supabase.instance.client.auth.currentUser?.id;
  if (user == null) return;
  final jobs = await _load156(user);
  for (final job in jobs) {
    if (job['id'] == id && job['state'] == 'error') {
      job['state'] = 'waiting';
      await _save156(user);
      await _nativeCall156('start');
      changed();
      unawaited(_pump156(changed));
      return;
    }
  }
}
