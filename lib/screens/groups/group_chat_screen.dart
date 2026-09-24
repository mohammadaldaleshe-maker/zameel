import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/remaining_services.dart';
import '../../theme/app_theme.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = RemainingServices.subscribeToGroupMessages(widget.groupId, _load);
  }

  Future<void> _load() async {
    try {
      final rows = await RemainingServices.groupMessages(widget.groupId);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await RemainingServices.sendGroupMessage(widget.groupId, text);
      _controller.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر إرسال الرسالة إلى المجموعة'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    RemainingServices.removeChannel(_channel);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('لا توجد رسائل بعد'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['user_id']?.toString() == me;
                          final name = message['sender_name']?.toString().trim().isNotEmpty == true
                              ? message['sender_name'].toString().trim()
                              : 'زميل';
                          final created = DateTime.tryParse(
                            message['created_at']?.toString() ?? '',
                          )?.toLocal();
                          return Align(
                            alignment: isMe
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isMe
                                    ? null
                                    : Border.all(color: AppTheme.muted.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? Colors.white : AppTheme.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    message['content']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (created != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('dd/MM/yyyy • HH:mm').format(created),
                                      style: TextStyle(
                                        color: isMe ? Colors.white70 : AppTheme.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.black87),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة للمجموعة...',
                        hintStyle: const TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
