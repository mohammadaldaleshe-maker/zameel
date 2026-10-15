import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/keep_keyboard_send_button.dart';
import '../profile/profile_screen.dart';

class CollegeComments161 extends StatefulWidget {
  const CollegeComments161(
      {super.key, required this.entryId, required this.ownerId});
  final String entryId, ownerId;
  @override
  State<CollegeComments161> createState() => _CollegeComments161State();
}

class _CollegeComments161State extends State<CollegeComments161> {
  final text = TextEditingController();
  final focus = FocusNode();
  final db = Supabase.instance.client;
  List<Map<String, dynamic>> rows = [];
  bool loading = true, sending = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  void error() {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'تعذر تنفيذ العملية. قد تكون دورة التحدي انتهت؛ حدّث الصفحة.')));
  }

  Future<void> load() async {
    try {
      final result = await db
          .from('zameel_college_comments161')
          .select('*,users(name,profile_image)')
          .eq('entry_id', widget.entryId)
          .order('created_at')
          .limit(200);
      if (mounted)
        setState(() => rows = List<Map<String, dynamic>>.from(result));
    } catch (_) {
      error();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    if (sending || text.text.trim().isEmpty) return;
    final value = text.text.trim();
    setState(() => sending = true);
    try {
      await db.from('zameel_college_comments161').insert({
        'entry_id': widget.entryId,
        'user_id': db.auth.currentUser!.id,
        'content': value
      });
      if (text.text.trim() == value) text.clear();
      await load();
    } catch (_) {
      error();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) =>
            AlertDialog(title: const Text('حذف التعليق؟'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('حذف'))
            ]));
    if (ok != true || !mounted) return;
    try {
      await db.rpc('zameel_delete_comment161',
          params: {'p_kind': 'college', 'p_id': row['id']});
      await load();
    } catch (_) {
      error();
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('التعليقات')),
          body: Column(children: [
            Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: rows.length,
                            itemBuilder: (_, index) {
                              final row = rows[index],
                                  user = row['users'] as Map? ?? {};
                              return ListTile(
                                  title: InkWell(
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ProfileScreen(
                                                  userId:
                                                      '${row['user_id']}'))),
                                      child: Text('${user['name'] ?? 'زميل'}')),
                                  subtitle: Text('${row['content']}'),
                                  trailing: widget.ownerId ==
                                          db.auth.currentUser?.id
                                      ? IconButton(
                                          tooltip: 'حذف التعليق',
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () => remove(row))
                                      : null);
                            }))),
            SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                          child: TextField(
                              controller: text,
                              focusNode: focus,
                              groupId: focus,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 2000,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              onEditingComplete: () {},
                              decoration: const InputDecoration(
                                  hintText: 'اكتب تعليقًا…', counterText: ''))),
                      const SizedBox(width: 8),
                      KeepKeyboardSendButton(
                          composerFocus: focus, onSend: send, busy: sending)
                    ])))
          ])));
}
