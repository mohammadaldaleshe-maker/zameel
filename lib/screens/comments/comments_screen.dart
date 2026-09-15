import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';

class CommentsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? highlightedCommentId;
  const CommentsScreen({super.key, required this.post, this.highlightedCommentId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _comments = [];

  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  String get postId => widget.post['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (postId.isEmpty) return;
    try {
      final rows = await db
          .from('post_comments')
          .select('id,post_id,user_id,content,created_at,updated_at,users(name,profile_image,department)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _comments = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل التعليقات: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final user = db.auth.currentUser;
    if (text.isEmpty || user == null || postId.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await db.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': text,
      });
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إضافة التعليق: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editComment(Map<String,dynamic> comment,bool ar) async {
    final controller=TextEditingController(text:comment['content']?.toString()??'');
    final value=await showDialog<String?>(context:context,builder:(c)=>AlertDialog(title:Text(ar?'تعديل التعليق':'Edit comment'),content:TextField(controller:controller,maxLines:4,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:Text(ar?'إلغاء':'Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text.trim()),child:Text(ar?'حفظ':'Save'))]));
    controller.dispose();if(value==null||value.isEmpty)return;
    await db.from('post_comments').update({'content':value,'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('id',comment['id']).eq('user_id',uid!);await _loadComments();
  }
  Future<void> _deleteComment(Map<String,dynamic> comment) async {
    await db.from('post_comments').delete().eq('id',comment['id']);await _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final ownerName = isArabic
        ? (widget.post['name_ar'] ?? widget.post['users']?['name'] ?? 'مستخدم')
        : (widget.post['name_en'] ?? widget.post['users']?['name'] ?? 'User');
    final postText = isArabic
        ? (widget.post['text_ar'] ?? '')
        : (widget.post['text_en'] ?? '');

    return Directionality(
      textDirection:
          isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'التعليقات' : 'Comments'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(
                  bottom: BorderSide(color: AppTheme.muted.shade200),
                ),
              ),
              child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(postText,style:const TextStyle(fontSize:15,height:1.5)),if((widget.post['image_url']?.toString()??'').isNotEmpty)...[const SizedBox(height:10),ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network(widget.post['image_url'].toString(),fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()))]]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: _imageForPost(widget.post),
                    child: _imageForPost(widget.post) == null
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ownerName.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${_comments.length}'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            isArabic
                                ? 'لا توجد تعليقات بعد\nكن أول من يعلق!'
                                : 'No comments yet\nBe the first to comment!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.muted.shade600),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _comments.length,
                          itemBuilder: (_, index) => _commentCard(
                            _comments[index],
                            isArabic,
                          ),
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'اكتب تعليقك...'
                              : 'Write a comment...',
                          filled: true,
                          fillColor: AppTheme.muted.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _sending ? null : _addComment,
                      child: _sending
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
      ),
    );
  }

  ImageProvider? _imageForPost(Map<String, dynamic> post) {
    final direct = post['profile_image']?.toString();
    final nested = post['users'] is Map<String, dynamic>
        ? (post['users']['profile_image']?.toString())
        : null;
    final url = (direct != null && direct.isNotEmpty)
        ? direct
        : (nested != null && nested.isNotEmpty ? nested : null);
    return url == null ? null : NetworkImage(url);
  }

  Widget _commentCard(Map<String, dynamic> comment, bool isArabic) {
    final user = comment['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(comment['users'])
        : <String, dynamic>{};
    final name = user['name']?.toString() ?? 'مستخدم';
    final body = comment['content']?.toString() ?? '';
    final avatar = user['profile_image']?.toString();
    final mine=comment['user_id']?.toString()==uid;
    final postOwner=widget.post['user_id']?.toString()==uid;
    final created=DateTime.tryParse(comment['created_at']?.toString()??'')?.toLocal();
    final updated=comment['updated_at']!=null;
    final highlighted=widget.highlightedCommentId==comment['id']?.toString();

    return Card(
      color: highlighted ? AppTheme.accentSoft : null,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatar != null && avatar.isNotEmpty
              ? NetworkImage(avatar)
              : null,
          child: avatar == null || avatar.isEmpty
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(padding:const EdgeInsets.only(top:5),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(body),const SizedBox(height:4),Text('${created==null?'':DateFormat(isArabic?'yyyy/MM/dd • HH:mm':'MMM d, yyyy • HH:mm',isArabic?'ar':'en').format(created)}${updated?(isArabic?' • تم التعديل':' • edited'):''}',style:TextStyle(fontSize:10,color:AppTheme.muted.shade600))])),
        trailing:(mine||postOwner)?PopupMenuButton<String>(onSelected:(v){if(v=='edit')_editComment(comment,isArabic);if(v=='delete')_deleteComment(comment);},itemBuilder:(_)=>[if(mine)PopupMenuItem(value:'edit',child:Text(isArabic?'تعديل':'Edit')),PopupMenuItem(value:'delete',child:Text(isArabic?'حذف':'Delete'))]):null,
      ),
    );
  }
}
