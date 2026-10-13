import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String publicContentLink157(String kind, String id) {
  if (!const ['post', 'clip'].contains(kind) ||
      !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id)) {
    throw ArgumentError('invalid_content_identity');
  }
  return 'https://zameeljo.com/s/$kind/${id.toLowerCase()}';
}

Future<String> _checkedLink157(String kind, String id) async {
  final link = publicContentLink157(kind, id);
  final row = await Supabase.instance.client
      .from(kind == 'clip' ? 'clips' : 'posts')
      .select()
      .eq('id', id)
      .maybeSingle();
  if (row == null ||
      row['audience'] != 'public' ||
      row['is_hidden'] == true ||
      row['deleted_at'] != null ||
      row['upload_state156'] != 'ready') {
    throw StateError('content_not_public');
  }
  final author = await Supabase.instance.client
      .from('users')
      .select('account_privacy')
      .eq('id', row['user_id'])
      .maybeSingle();
  if (author?['account_privacy'] != 'public')
    throw StateError('private_account');
  return link;
}

Future<void> showContentShare157(
  BuildContext context, {
  required String id,
  String kind = 'post',
  required Future<void> Function() onProfile,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('على صفحتي الشخصية'),
          onTap: () => Navigator.pop(sheet, 'profile')),
      ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('المشاركة خارج التطبيق'),
          onTap: () => Navigator.pop(sheet, 'external')),
      ListTile(
          leading: const Icon(Icons.link),
          title: const Text('نسخ الرابط'),
          onTap: () => Navigator.pop(sheet, 'copy')),
    ])),
  );
  if (choice == null || !context.mounted) return;
  try {
    if (choice == 'profile') {
      await onProfile();
      return;
    }
    final link = await _checkedLink157(kind, id);
    if (!context.mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم نسخ الرابط')));
    } else {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
          text: link,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'تعذر المشاركة. المشاركة الخارجية متاحة للمحتوى العام المكتمل فقط.')));
  }
}
