import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/remaining_services.dart';
import 'package:zameel/theme/app_theme.dart';

class AnonymousScreen extends StatefulWidget {
  const AnonymousScreen({super.key});

  @override
  State<AnonymousScreen> createState() => _AnonymousScreenState();
}

class _AnonymousScreenState extends State<AnonymousScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await RemainingServices.anonymousMessages();
      if (!mounted) return;
      setState(() {
        messages = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await RemainingServices.sendAnonymousMessage(text);
      _messageController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال الرسالة المجهولة'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(dynamic value, bool ar) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return ar ? 'الآن' : 'Now';
    if (diff.inHours < 1) return ar ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return ar ? 'منذ ${diff.inHours} س' : '${diff.inHours}h ago';
    return ar ? 'منذ ${diff.inDays} ي' : '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '👤 الرسائل المجهولة' : '👤 Anonymous Messages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.muted.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? '📝 اكتب رسالتك المجهولة...'
                            : '📝 Write your anonymous message...',
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: messages.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 150),
                                Icon(
                                  Icons.visibility_off_rounded,
                                  size: 64,
                                  color: AppTheme.muted.shade400,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    isArabic
                                        ? '📭 لا توجد رسائل مجهولة'
                                        : '📭 No anonymous messages',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: AppTheme.muted.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.muted.withAlpha(25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: AppTheme.primary.withAlpha(51),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryDark.withAlpha(25),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              message['is_mine'] == true
                                                  ? (isArabic ? '👤 مجهول • أنت' : '👤 Anonymous • You')
                                                  : (isArabic ? '👤 مجهول' : '👤 Anonymous'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryDark,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _time(message['created_at'], isArabic),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.muted.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        message['content']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 15, height: 1.5),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
