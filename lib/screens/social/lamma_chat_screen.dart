import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

class LammaChatScreen extends StatefulWidget {
  final String lammaId;
  final String title;

  const LammaChatScreen({super.key, required this.lammaId, required this.title});

  @override
  State<LammaChatScreen> createState() => _LammaChatScreenState();
}

class _LammaChatScreenState extends State<LammaChatScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  final _db = Supabase.instance.client;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    final user = _db.auth.currentUser;
    if (body.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _db.from('social_lamma_messages').insert({
        'lamma_id': widget.lammaId,
        'sender_id': user.id,
        'body': body,
      });
      _message.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الرسالة. تأكد أنك عضو في اللّمّة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _db.auth.currentUser?.id;
    final stream = _db
        .from('social_lamma_messages')
        .stream(primaryKey: ['id'])
        .eq('lamma_id', widget.lammaId)
        .order('created_at');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('تعذر تحميل دردشة اللّمّة.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const Center(child: Text('ابدأوا الحديث في اللّمّة 👋'));
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final item = messages[index];
                      final mine = item['sender_id'] == uid;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 310),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine ? AppTheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(item['body']?.toString() ?? '', style: TextStyle(color: mine ? Colors.white : null)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(counterText: '', hintText: 'اكتب رسالة للّمّة...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
