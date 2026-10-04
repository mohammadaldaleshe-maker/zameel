import '../theme/app_theme.dart';
import '../theme/appearance_controller.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/post_reporting_service.dart';

String reportContentLabel(String type, bool ar) => switch (type) {
      'story' => ar ? 'الحالة' : 'story',
      'clip' => ar ? 'الشورتس' : 'Short',
      _ => ar ? 'المنشور' : 'post',
    };

Future<void> showPostReportDialog(
        BuildContext context, String postId, bool ar) =>
    showContentReportDialog(context, postId, 'post', ar);

Future<void> showContentReportDialog(
    BuildContext context, String contentId, String contentType, bool ar) async {
  if (Supabase.instance.client.auth.currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ar ? 'سجّل الدخول لإرسال البلاغ.' : 'Sign in to submit a report.'),
    ));
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PostReportDialog(
      postId: contentId,
      contentType: contentType,
      ar: ar,
    ),
  );
}

class MediaReportButton extends StatelessWidget {
  final String contentId;
  final String? authorId;
  final String contentType;
  final bool ar;
  final VoidCallback? onReportOpened;
  final VoidCallback? onReportClosed;
  const MediaReportButton({
    super.key,
    required this.contentId,
    required this.authorId,
    required this.contentType,
    required this.ar,
    this.onReportOpened,
    this.onReportClosed,
  });
  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null ||
        uid == authorId ||
        contentId.isEmpty ||
        contentId.startsWith('local_')) return const SizedBox.shrink();
    final label = reportContentLabel(contentType, ar);
    return PopupMenuButton<String>(
      tooltip: ar ? 'خيارات $label' : '$label options',
      icon: const Icon(Icons.more_horiz, color: Colors.white),
      onSelected: (_) async {
        onReportOpened?.call();
        try {
          await showContentReportDialog(context, contentId, contentType, ar);
        } finally {
          onReportClosed?.call();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'report',
          child: Row(children: [
            const Icon(Icons.flag_outlined),
            const SizedBox(width: 8),
            Text(ar ? 'الإبلاغ عن $label' : 'Report $label'),
          ]),
        )
      ],
    );
  }
}

class PostReportMenu extends StatelessWidget {
  final String postId;
  final String? authorId;
  final bool ar;
  final bool canDelete;
  final VoidCallback onDelete;

  const PostReportMenu({
    super.key,
    required this.postId,
    required this.authorId,
    required this.ar,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final canReport = uid != null && uid != authorId && postId.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: ar ? 'خيارات المنشور' : 'Post options',
      icon: Icon(Icons.more_horiz, color: AppTheme.legacySecondary),
      onSelected: (value) {
        if (value == 'delete') onDelete();
        if (value == 'report') showPostReportDialog(context, postId, ar);
      },
      itemBuilder: (_) => [
        if (canReport)
          PopupMenuItem(
            value: 'report',
            child: Row(children: [
              const Icon(Icons.flag_outlined),
              const SizedBox(width: 8),
              Text(ar ? 'الإبلاغ عن المنشور' : 'Report post'),
            ]),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text(ar ? 'حذف' : 'Delete'),
            ]),
          ),
      ],
    );
  }
}

class _PostReportDialog extends StatefulWidget {
  final String postId;
  final String contentType;
  final bool ar;
  const _PostReportDialog(
      {required this.postId, required this.contentType, required this.ar});
  @override
  State<_PostReportDialog> createState() => _PostReportDialogState();
}

class _PostReportDialogState extends State<_PostReportDialog> {
  final _reason = TextEditingController();
  String _category = 'spam';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final ar = widget.ar;
    if (_category == 'other' && _reason.text.trim().length < 5) {
      setState(() => _error = ar
          ? 'اكتب سببًا من خمسة أحرف على الأقل.'
          : 'Enter a reason of at least five characters.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final duplicate = await PostReportingService.submit(
        postId: widget.postId,
        category: _category,
        reason: _reason.text,
        contentType: widget.contentType,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(duplicate
              ? (ar
                  ? 'سبق أن أرسلت بلاغًا عن ${reportContentLabel(widget.contentType, ar)}.'
                  : 'You already reported this ${reportContentLabel(widget.contentType, ar)}.')
              : (ar
                  ? 'تم إرسال البلاغ إلى الإدارة للمراجعة.'
                  : 'Report sent to the administration for review.'))));
    } catch (e) {
      if (!mounted) return;
      final message = e is PostgrestException ? e.message : '';
      setState(() {
        _sending = false;
        _error = message.contains('report_rate_limited')
            ? (ar
                ? 'وصلت إلى حد البلاغات المؤقت. حاول لاحقًا.'
                : 'Temporary report limit reached. Try later.')
            : (message.contains('post_not_available') ||
                    message.contains('content_not_available'))
                ? (ar
                    ? 'لم يعد المحتوى متاحًا لك. حدّث الصفحة.'
                    : 'This content is no longer available. Refresh the page.')
                : message.contains('account_cannot_report')
                    ? (ar
                        ? 'لا يسمح وضع الحساب الحالي بإرسال البلاغ.'
                        : 'Your account cannot submit reports right now.')
                    : (ar
                        ? 'تعذر إرسال البلاغ. حاول مجددًا.'
                        : 'Could not send the report. Please retry.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.ar;
    const reasons = {
      'spam': ['إزعاج أو احتيال', 'Spam or scam'],
      'harassment': ['تنمر أو إساءة', 'Harassment or abuse'],
      'hate': ['خطاب كراهية', 'Hate speech'],
      'sexual': ['محتوى جنسي', 'Sexual content'],
      'violence': ['عنف أو تهديد', 'Violence or threats'],
      'privacy': ['انتهاك الخصوصية', 'Privacy violation'],
      'other': ['سبب آخر', 'Other'],
    };
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: Text(ar
            ? 'الإبلاغ عن ${reportContentLabel(widget.contentType, ar)}'
            : 'Report ${reportContentLabel(widget.contentType, ar)}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ar
                ? 'اختر السبب. لا يُخفى المحتوى تلقائيًا؛ تراجعه الإدارة.'
                : 'Choose a reason. The administration reviews reports before hiding content.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: ar ? 'سبب البلاغ' : 'Reason'),
              items: reasons.entries
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value[ar ? 0 : 1]),
                      ))
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) => setState(() {
                        _category = value ?? 'spam';
                        _error = null;
                      }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              enabled: !_sending,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                  labelText: ar ? 'تفاصيل إضافية' : 'Additional details'),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending
                  ? (ar ? 'جارٍ الإرسال…' : 'Sending…')
                  : (ar ? 'إرسال البلاغ' : 'Send report'))),
        ],
      ),
    );
  }
}
