import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services_social.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_screen.dart';

class ClipCommentsScreen extends StatefulWidget {
  final Map<String, dynamic> clip;

  const ClipCommentsScreen({super.key, required this.clip});

  @override
  State<ClipCommentsScreen> createState() => _ClipCommentsScreenState();
}

class _ClipCommentsScreenState extends State<ClipCommentsScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  Set<String> _likedIds = <String>{};
  Map<String, dynamic>? _replyingTo;

  String get clipId => widget.clip['id']?.toString() ?? '';
  String? get uid => ZameelSocialService.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (clipId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final comments = await ZameelSocialService.loadComments(clipId);
      final liked = await ZameelSocialService.loadMyClipCommentLikes(
        comments
            .map((comment) => comment['id']?.toString())
            .whereType<String>()
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _likedIds = liked;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر تحميل التعليقات'))),
      );
    }
  }

  void _reply(Map<String, dynamic> comment) {
    setState(() => _replyingTo = comment);
    _focusNode.requestFocus();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || clipId.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ZameelSocialService.addClipComment(
        clipId,
        text,
        parentCommentId: _replyingTo?['id']?.toString(),
      );
      _controller.clear();
      if (mounted) setState(() => _replyingTo = null);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر إضافة التعليق'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> comment) async {
    final id = comment['id']?.toString();
    if (id == null || id.isEmpty) return;
    final wasLiked = _likedIds.contains(id);
    final oldCount = (comment['likes_count'] as num?)?.toInt() ?? 0;
    setState(() {
      if (wasLiked) {
        _likedIds.remove(id);
      } else {
        _likedIds.add(id);
      }
      comment['likes_count'] = (oldCount + (wasLiked ? -1 : 1)).clamp(0, 999999);
    });
    try {
      await ZameelSocialService.toggleClipCommentLike(id, wasLiked);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedIds.add(id);
        } else {
          _likedIds.remove(id);
        }
        comment['likes_count'] = oldCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر تحديث الإعجاب'))),
      );
    }
  }

  Future<void> _edit(Map<String, dynamic> comment, bool ar) async {
    if (comment['user_id']?.toString() != uid) return;
    final editor = TextEditingController(text: comment['text']?.toString() ?? '');
    final value = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'تعديل التعليق' : 'Edit comment'),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editor.text.trim()),
            child: Text(ar ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await ZameelSocialService.updateClipComment(comment['id'].toString(), value);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر تعديل التعليق'))),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> comment, bool ar) async {
    if (comment['user_id']?.toString() != uid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'حذف التعليق؟' : 'Delete comment?'),
        content: Text(
          ar
              ? 'سيتم حذف التعليق وردوده المرتبطة به.'
              : 'The comment and its replies will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ar ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ZameelSocialService.deleteClipComment(comment['id'].toString());
      if (_replyingTo?['id']?.toString() == comment['id']?.toString() && mounted) {
        setState(() => _replyingTo = null);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر حذف التعليق'))),
        );
      }
    }
  }

  Future<void> _openCommenterProfile(Map<String, dynamic> comment) async {
    final userId = comment['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  List<_ClipThreadEntry> _threaded() {
    final byParent = <String?, List<Map<String, dynamic>>>{};
    final ids = _comments
        .map((comment) => comment['id']?.toString())
        .whereType<String>()
        .toSet();
    for (final comment in _comments) {
      var parent = comment['parent_comment_id']?.toString();
      if (parent != null && !ids.contains(parent)) parent = null;
      byParent.putIfAbsent(parent, () => <Map<String, dynamic>>[]).add(comment);
    }
    final result = <_ClipThreadEntry>[];
    final visited = <String>{};
    void append(Map<String, dynamic> comment, int depth) {
      final id = comment['id']?.toString() ?? '';
      if (id.isEmpty || !visited.add(id)) return;
      result.add(_ClipThreadEntry(comment, depth.clamp(0, 3).toInt()));
      for (final reply in byParent[id] ?? const <Map<String, dynamic>>[]) {
        append(reply, depth + 1);
      }
    }
    for (final root in byParent[null] ?? const <Map<String, dynamic>>[]) {
      append(root, 0);
    }
    for (final comment in _comments) {
      if (!visited.contains(comment['id']?.toString())) append(comment, 0);
    }
    return result;
  }

  String _nameOf(Map<String, dynamic> comment) {
    final user = comment['users'];
    if (user is Map) {
      final name = user['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
      final username = user['username']?.toString().trim() ?? '';
      if (username.isNotEmpty) return username;
    }
    return 'زميل';
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final threaded = _threaded();
    return Directionality(
      textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ar ? 'تعليقات الكليبس' : 'Clip comments'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : threaded.isEmpty
                      ? Center(
                          child: Text(
                            ar
                                ? 'لا توجد تعليقات بعد\nكن أول من يعلق!'
                                : 'No comments yet\nBe the first to comment!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.muted.shade600),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: threaded.length,
                            itemBuilder: (_, index) => _card(
                              threaded[index].comment,
                              threaded[index].depth,
                              ar,
                            ),
                          ),
                        ),
            ),
            if (_replyingTo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppTheme.accentSoft,
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ar
                            ? 'الرد على ${_nameOf(_replyingTo!)}'
                            : 'Replying to ${_nameOf(_replyingTo!)}',
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _replyingTo = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
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
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: _replyingTo == null
                              ? (ar ? 'اكتب تعليقك...' : 'Write a comment...')
                              : (ar ? 'اكتب ردك...' : 'Write a reply...'),
                          filled: true,
                          fillColor: AppTheme.muted.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox.square(
                              dimension: 18,
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

  Widget _card(Map<String, dynamic> comment, int depth, bool ar) {
    final user = comment['users'] is Map
        ? Map<String, dynamic>.from(comment['users'] as Map)
        : <String, dynamic>{};
    final displayName = user['name']?.toString().trim() ?? '';
    final username = user['username']?.toString().trim() ?? '';
    final name = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? username : (ar ? 'مستخدم' : 'User'));
    final avatar = user['profile_image']?.toString() ?? '';
    final id = comment['id']?.toString() ?? '';
    final mine = comment['user_id']?.toString() == uid;
    final liked = _likedIds.contains(id);
    final likes = (comment['likes_count'] as num?)?.toInt() ?? 0;
    final created = DateTime.tryParse(comment['created_at']?.toString() ?? '')
        ?.toLocal();
    final createdRaw = DateTime.tryParse(comment['created_at']?.toString() ?? '');
    final updatedRaw = DateTime.tryParse(comment['updated_at']?.toString() ?? '');
    final edited = createdRaw != null &&
        updatedRaw != null &&
        updatedRaw.difference(createdRaw).inSeconds.abs() > 1;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: (depth * 22).toDouble()),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openCommenterProfile(comment),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: depth == 0 ? 20 : 17,
                  backgroundImage:
                      avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _openCommenterProfile(comment),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (mine)
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _edit(comment, ar);
                              } else if (value == 'delete') {
                                _delete(comment, ar);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(ar ? 'تعديل' : 'Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(ar ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(comment['text']?.toString() ?? ''),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${created == null ? '' : DateFormat(ar ? 'yyyy/MM/dd • HH:mm' : 'MMM d, yyyy • HH:mm', ar ? 'ar' : 'en').format(created)}${edited ? (ar ? ' • تم التعديل' : ' • edited') : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.muted.shade600,
                          ),
                        ),
                        InkWell(
                          onTap: () => _toggleLike(comment),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: liked ? Colors.redAccent : null,
                                ),
                                if (likes > 0) ...[
                                  const SizedBox(width: 3),
                                  Text('$likes'),
                                ],
                              ],
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _reply(comment),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 16),
                          label: Text(ar ? 'رد' : 'Reply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipThreadEntry {
  final Map<String, dynamic> comment;
  final int depth;

  const _ClipThreadEntry(this.comment, this.depth);
}
