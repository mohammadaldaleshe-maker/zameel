import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'post_publish_service.dart';
import 'background_publish156_stub.dart'
    if (dart.library.io) 'background_publish156_io.dart' as platform;

class BackgroundPublish156 {
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static Future<String> post(
      {required String text,
      required String audience,
      required List<PickedPostMedia> media,
      List<String> mentions = const []}) async {
    PostPublishService.validateMedia156(media);
    return platform.enqueue156({
      'kind': 'post',
      'text': text,
      'audience': audience,
      'mentions': mentions
    }, media.map((m) => m.source).toList(), () => revision.value++);
  }

  static Future<String> clip(
          {required XFile video,
          XFile? cover,
          required String caption,
          required int duration}) =>
      platform.enqueue156({
        'kind': 'clip',
        'text': caption,
        'audience': 'public',
        'duration': duration,
        'has_cover': cover != null
      }, [
        video,
        if (cover != null) cover
      ], () => revision.value++);
  static Future<String> story(
          {required XFile file,
          required String type,
          String caption = '',
          required String audience}) =>
      platform.enqueue156({
        'kind': 'story',
        'text': caption,
        'type': type,
        'audience': audience
      }, [
        file
      ], () => revision.value++);
  static Future<void> resume() => platform.resume156(() => revision.value++);
  static Future<List<Map<String, dynamic>>> tasks() => platform.tasks156();
  static Future<void> retry(String id) =>
      platform.retry156(id, () => revision.value++);
  static Future<void> notice(BuildContext context) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) {
          Future<void>.delayed(const Duration(milliseconds: 800), () {
            if (c.mounted) Navigator.pop(c);
          });
          return const AlertDialog(
              content: Text(
                  'جارٍ رفع المحتوى في الخلفية…\nسيصلك إشعار عند اكتمال النشر.',
                  textAlign: TextAlign.center));
        });
    if (context.mounted)
      Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class UploadTasks156 extends StatefulWidget {
  const UploadTasks156({super.key});
  @override
  State<UploadTasks156> createState() => _UploadTasks156State();
}

class _UploadTasks156State extends State<UploadTasks156> {
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() {
    super.initState();
    _load();
    BackgroundPublish156.revision.addListener(_load);
  }

  @override
  void dispose() {
    BackgroundPublish156.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await BackgroundPublish156.tasks();
    if (mounted) setState(() => rows = r);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('عمليات الرفع')),
      body: ListView(children: [
        for (final row in rows)
          ListTile(
              title: Text('${row['text'] ?? row['kind']}'),
              subtitle: Text(row['state'] == 'error'
                  ? 'تعذر الرفع؛ يمكنك إعادة المحاولة'
                  : row['state'] == 'done'
                      ? 'اكتمل النشر'
                      : 'جارٍ الرفع أو بانتظار الاستئناف'),
              trailing: row['state'] == 'error'
                  ? TextButton(
                      onPressed: () async {
                        await BackgroundPublish156.retry('${row['id']}');
                        await _load();
                      },
                      child: const Text('إعادة المحاولة'))
                  : null)
      ]));
}
