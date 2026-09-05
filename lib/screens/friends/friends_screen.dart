import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  List<Map<String, dynamic>> _suggestions = [];

  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _load(); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final me = uid!;
      final req = await db.from('friend_requests').select('id, sender_id, receiver_id, sender_name, receiver_name, status, created_at').or('sender_id.eq.$me,receiver_id.eq.$me').order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(req);
      final incoming = rows.where((r) => r['receiver_id'] == me && r['status'] == 'pending').toList();
      final outgoing = rows.where((r) => r['sender_id'] == me && r['status'] == 'pending').toList();
      final accepted = rows.where((r) => r['status'] == 'accepted').toList();
      final friends = <Map<String, dynamic>>[];
      final friendIds = accepted.map((r) => (r['sender_id'] == me ? r['receiver_id'] : r['sender_id']).toString()).toList();
      if (friendIds.isNotEmpty) {
        final userRows = await db.from('users').select('id,name,username,university,college,department,profile_image').inFilter('id', friendIds);
        final byId = {for (final u in userRows) u['id'].toString(): Map<String,dynamic>.from(u)};
        for (final r in accepted) {
          final id = (r['sender_id'] == me ? r['receiver_id'] : r['sender_id']).toString();
          final u = byId[id];
          if (u != null) friends.add({...u, 'request_id': r['id']});
        }
      }
      final users = await db.from('users').select('id,name,username,university,college,department,profile_image').neq('id', me).limit(100);
      final existing = <String>{...friends.map((e) => e['id'].toString()), ...incoming.map((e) => e['sender_id'].toString()), ...outgoing.map((e) => e['receiver_id'].toString())};
      final suggestions = List<Map<String, dynamic>>.from(users).where((u) => !existing.contains(u['id'].toString())).take(30).toList();
      if (mounted) setState(() { _friends = friends; _incoming = incoming; _outgoing = outgoing; _suggestions = suggestions; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الزملاء: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _sendRequest(String targetId) async {
    final me = uid;
    if (me == null || me == targetId) return;
    try {
      final existing = await db
          .from('friend_requests')
          .select('id,sender_id,receiver_id,status,created_at')
          .or('and(sender_id.eq.$me,receiver_id.eq.$targetId),and(sender_id.eq.$targetId,receiver_id.eq.$me)')
          .order('created_at', ascending: false)
          .limit(1);

      if (existing.isNotEmpty && existing.first['status'] == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('طلب الزمالة موجود مسبقًا.')),
          );
        }
        return;
      }

      final names = await db.from('users').select('id,name').inFilter('id', [me, targetId]);
      final byId = {for (final u in names) u['id'].toString(): u['name']?.toString() ?? ''};
      final senderName = (byId[me] ?? '').isEmpty ? 'زميل' : byId[me]!;
      final receiverName = (byId[targetId] ?? '').isEmpty ? 'زميل' : byId[targetId]!;

      await db.from('friend_requests').insert({
        'sender_id': me,
        'receiver_id': targetId,
        'sender_name': senderName,
        'receiver_name': receiverName,
        'status': 'pending',
      });

      await db.from('notifications').insert({
        'user_id': targetId,
        'actor_id': me,
        'type': 'friend_request',
        'title_ar': 'طلب زميل جديد',
        'title_en': 'New colleague request',
        'body_ar': '$senderName أرسل لك طلب زميل',
        'body_en': '$senderName sent you a colleague request',
        'data': {'request_id': 'pending'},
      });

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الزمالة ✓')),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('طلب الزمالة موجود مسبقًا.')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: ${e.message}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $e')));
    }
  }

  Future<void> _respond(Map<String, dynamic> request, bool accept) async {
    final id = request['id']; final me = uid; if (id == null || me == null) return;
    try {
      await db.from('friend_requests').update({'status': accept ? 'accepted' : 'rejected', 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('receiver_id', me);
      final sender = request['sender_id']?.toString();
      if (sender != null) {
        await db.from('notifications').insert({'user_id': sender, 'actor_id': me, 'type': accept ? 'friend_request_accepted' : 'friend_request_rejected', 'title_ar': accept ? 'تم قبول طلب الزمالة' : 'تم رفض طلب الزمالة', 'title_en': accept ? 'Colleague request accepted' : 'Colleague request declined', 'body_ar': accept ? 'تم قبول طلب الزمالة الذي أرسلته.' : 'تم رفض طلب الزمالة الذي أرسلته.', 'body_en': accept ? 'Your colleague request was accepted.' : 'Your colleague request was declined.', 'data': {'request_id': id}});
      }
      await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنفيذ الطلب: $e'))); }
  }

  Future<void> _removeFriend(String requestId) async {
    try { await db.from('friend_requests').update({'status': 'cancelled', 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', requestId); await _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إزالة الزميل: $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr, child: Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: Text(ar ? '👥 الزملاء' : '👥 Colleagues'), centerTitle: true, actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))], bottom: TabBar(controller: _tabs, tabs: [Tab(text: ar ? 'زملائي (${_friends.length})' : 'Colleagues (${_friends.length})'), Tab(text: ar ? 'الطلبات (${_incoming.length})' : 'Requests (${_incoming.length})'), Tab(text: ar ? 'اكتشاف' : 'Discover')])),
      body: _loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabs, children: [_friendsView(ar), _requestsView(ar), _discoverView(ar)]),
    ));
  }

  Widget _friendsView(bool ar) {
    if (_friends.isEmpty) return _empty(ar ? 'لا يوجد زملاء مقبولون بعد' : 'No accepted colleagues yet');
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: _friends.length, itemBuilder: (_, i) {
      final f = _friends[i]; final name = f['name']?.toString() ?? 'User';
      return Card(child: ListTile(leading: _avatar(f), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${f['department'] ?? ''} • ${f['university'] ?? ''}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: f['id'].toString()))), trailing: Wrap(children: [IconButton(tooltip: ar ? 'دردشة' : 'Chat', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(partnerId: f['id'].toString(), partnerName: name))), icon: const Icon(Icons.chat_bubble_rounded)), IconButton(tooltip: ar ? 'إزالة' : 'Remove', onPressed: () => _removeFriend(f['request_id'].toString()), icon: const Icon(Icons.person_remove_rounded, color: Colors.red)), IconButton(tooltip: ar ? 'حظر' : 'Block', onPressed: () async { try { await db.from('user_blocks').upsert({'blocker_id': uid, 'blocked_id': f['id']}); await _removeFriend(f['request_id'].toString()); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حظر المستخدم: $e'))); } }, icon: const Icon(Icons.block_rounded, color: Colors.redAccent))])));
    }));
  }

  Widget _requestsView(bool ar) {
    if (_incoming.isEmpty && _outgoing.isEmpty) return _empty(ar ? 'لا توجد طلبات زمالة' : 'No colleague requests');
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (_incoming.isNotEmpty) ...[Text(ar ? 'طلبات واردة' : 'Incoming requests', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), ..._incoming.map((r) => _requestCard(r, ar))],
      if (_outgoing.isNotEmpty) ...[const SizedBox(height: 18), Text(ar ? 'طلبات أرسلتها' : 'Sent requests', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), ..._outgoing.map((r) => _outgoingCard(r, ar))],
    ]);
  }

  Widget _requestCard(Map<String, dynamic> r, bool ar) { final name = r['sender_name']?.toString().isNotEmpty == true ? r['sender_name'].toString() : 'User'; return Card(child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [const CircleAvatar(child: Icon(Icons.person)), const SizedBox(width: 10), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))), IconButton(onPressed: () => _respond(r, true), icon: const Icon(Icons.check_circle_rounded, color: Colors.green)), IconButton(onPressed: () => _respond(r, false), icon: const Icon(Icons.cancel_rounded, color: Colors.red))]))); }
  Widget _outgoingCard(Map<String, dynamic> r, bool ar) { final name = r['receiver_name']?.toString().isNotEmpty == true ? r['receiver_name'].toString() : 'User'; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(ar ? 'بانتظار القبول' : 'Waiting for acceptance'), trailing: TextButton(onPressed: () async { await db.from('friend_requests').update({'status':'cancelled'}).eq('id', r['id']); _load(); }, child: Text(ar ? 'إلغاء' : 'Cancel')))); }

  Widget _discoverView(bool ar) { if (_suggestions.isEmpty) return _empty(ar ? 'لا يوجد زملاء مقترحون' : 'No suggestions'); return ListView.builder(padding: const EdgeInsets.all(14), itemCount: _suggestions.length, itemBuilder: (_, i) { final u = _suggestions[i]; return Card(child: ListTile(leading: _avatar(u), title: Text(u['name']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${u['department'] ?? ''} • ${u['university'] ?? ''}'), trailing: FilledButton.icon(onPressed: () => _sendRequest(u['id'].toString()), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: Text(ar ? 'إضافة' : 'Add')))); }); }

  Widget _empty(String text) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400), const SizedBox(height: 12), Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center)])));
  Widget _avatar(Map<String, dynamic> u) { final image = u['profile_image']?.toString(); return CircleAvatar(radius: 24, backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person_rounded) : null); }
}
