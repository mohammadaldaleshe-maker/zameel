import 'mention_field156.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MediaDescriptionDialog extends StatefulWidget {
  const MediaDescriptionDialog(
      {super.key, required this.mediaCount, this.arabic = true, this.onMentions});
  final void Function(List<String>)? onMentions;
  final int mediaCount;
  final bool arabic;

  @override
  State<MediaDescriptionDialog> createState() => _MediaDescriptionDialogState();
}

class _MediaDescriptionDialogState extends State<MediaDescriptionDialog> {
  final _controller = MentionController156();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.adaptiveSurface,
        title: Text(
            widget.arabic
                ? 'وصف الصور أو الفيديو'
                : 'Photo or video description',
            style: TextStyle(color: AppTheme.adaptiveText)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                widget.arabic
                    ? 'تم اختيار ${widget.mediaCount} من الوسائط. الوصف اختياري ويظهر أعلى الوسائط.'
                    : '${widget.mediaCount} media selected. Optional description appears above the media.',
                style: TextStyle(color: AppTheme.adaptiveText)),
            const SizedBox(height: 12),
            MentionTextField156(
              key: const ValueKey('home_media_description'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 10000,
              style: TextStyle(color: AppTheme.adaptiveText),
              decoration: InputDecoration(
                  labelText:
                      widget.arabic ? 'اكتب وصفًا' : 'Write a description',
                  border: const OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.arabic ? 'إلغاء' : 'Cancel')),
          FilledButton(
            onPressed: () {widget.onMentions?.call(_controller.mentionIds);Navigator.pop(context, _controller.text.trim());},
            child: Text(widget.arabic ? 'نشر' : 'Publish'),
          ),
        ],
      );
}
