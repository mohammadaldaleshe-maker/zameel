part of '../main.dart';

class SharedActivity156 extends StatefulWidget {
  const SharedActivity156({super.key, this.owner, this.kind = 'all'});
  final String? owner;
  final String kind;
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static void refresh() => revision.value++;
  @override
  State<SharedActivity156> createState() => _SharedActivity156State();
}

class _SharedActivity156State extends State<SharedActivity156> {
  final Set<String> _likeRequests161 = <String>{};

  List<Map<String, dynamic>> rows = [];
  final _saved156 = <Map<String, dynamic>>[];
  int offset = 0;
  bool loading = false, more = false;
  int request = 0;
  @override
  void initState() {
    super.initState();
    SharedActivity156.revision.addListener(_reset);
    _load();
  }

  @override
  void dispose() {
    request++;
    SharedActivity156.revision.removeListener(_reset);
    super.dispose();
  }

  void _reset() {
    offset = 0;
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (loading && !reset) return;
    loading = true;
    final generation = ++request;
    final viewer = Supabase.instance.client.auth.currentUser?.id;
    try {
      final data = await Supabase.instance.client
          .rpc('zameel_shared_activity_156', params: {
        'p_owner': widget.owner,
        'p_kind': widget.kind,
        'p_offset': reset ? 0 : offset
      });
      if (!mounted ||
          request != generation ||
          Supabase.instance.client.auth.currentUser?.id != viewer) return;
      final fresh = List<Map<String, dynamic>>.from(data as List);
      final owners = fresh.map((r) => '${r['shared_by']}').toSet().toList();
      if (owners.isNotEmpty) {
        final users = await Supabase.instance.client
            .from('users')
            .select('id,name,profile_image')
            .inFilter('id', owners);
        if (!mounted || request != generation) return;
        for (final row in fresh) {
          for (final user in users) {
            if (row['shared_by'] == user['id'])
              row['profile_image'] = user['profile_image'];
          }
        }
      }
      final ids = fresh
          .where((r) => r['posts'] is Map)
          .map((r) => r['posts']['id'].toString())
          .toList();
      if (viewer != null && ids.isNotEmpty) {
        try {
          final db = Supabase.instance.client;
          final lookups = await Future.wait([
            db
                .from('likes')
                .select('post_id')
                .eq('user_id', viewer)
                .inFilter('post_id', ids),
            db
                .from('saved_posts')
                .select('post_id')
                .eq('user_id', viewer)
                .inFilter('post_id', ids)
          ]);
          if (!mounted || request != generation) return;
          final liked = {for (final r in lookups[0]) r['post_id']};
          _saved156.clear();
          for (final r in fresh) {
            if (r['posts'] is Map) {
              r['posts']['liked'] = liked.contains(r['posts']['id']);
              if (lookups[1].any((s) => s['post_id'] == r['posts']['id']))
                _saved156.add(Map<String, dynamic>.from(r['posts']));
            }
          }
        } catch (_) {
          /* Existing reactions remain usable if counts are temporarily unavailable. */
        }
      }
      setState(() {
        if (reset) rows = [];
        rows.addAll(fresh);
        offset = rows.length;
        more = fresh.length == 30;
      });
    } catch (_) {
    } finally {
      if (request == generation) loading = false;
    }
  }

  Future<void> _share(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    await Supabase.instance.client.from('shared_posts').upsert(
        {'post_id': post['id'], 'shared_by': me.id},
        onConflict: 'post_id,shared_by');
    SharedActivity156.refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final row in rows)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (row['profile_image'] ?? '').toString().isEmpty
                                ? null
                                : NetworkImage('${row['profile_image']}'),
                        child: (row['profile_image'] ?? '').toString().isEmpty
                            ? const Icon(Icons.person_outline)
                            : null),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${row['name'] ?? 'مستخدم'} أعاد مشاركة المنشور',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    if (row['shared_by'] ==
                        Supabase.instance.client.auth.currentUser?.id)
                      IconButton(
                          tooltip: 'إلغاء المشاركة',
                          onPressed: () async {
                            final clip = row['kind'] == 'clip';
                            await Supabase.instance.client
                                .from(clip ? 'shared_clips' : 'shared_posts')
                                .delete()
                                .eq('id', row['id']);
                            SharedActivity156.refresh();
                          },
                          icon: const Icon(Icons.undo))
                  ]),
                  if (row['posts'] is Map)
                    Builder(builder: (context) {
                      final post = Map<String, dynamic>.from(row['posts']);
                      final user = post['users'] as Map? ?? {};
                      return _PostCard(
                          post: {
                            ...post,
                            'name_ar': user['name'],
                            'name_en': user['name'],
                            'profile_image': user['profile_image'],
                            'time_ar': jordanPostDate157(post['created_at']),
                            'time_en': jordanPostDate157(post['created_at']),
                            'likes': post['likes_count'],
                            'comments': post['comments_count'],
                            'shares': post['shares_count']
                          },
                          postOwnerId: post['user_id'],
                          savedPosts: _saved156,
                          onLike: () async {
                            final db = Supabase.instance.client,
                                me = Supabase.instance.client.auth.currentUser;
                            if (me == null) return;
                            final key161 = '${post['id']}';
                            if (!_likeRequests161.add(key161)) return;
                            try {
                              final liked = await db
                                  .from('likes')
                                  .select('id')
                                  .eq('user_id', me.id)
                                  .eq('post_id', post['id'])
                                  .maybeSingle();
                              await setPostLike161(db,
                                  userId: me.id,
                                  postId: '${post['id']}',
                                  liked: liked == null);
                              SharedActivity156.refresh();
                            } finally {
                              _likeRequests161.remove(key161);
                            }
                          },
                          onDelete: () async {
                            if (await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                            title: const Text('حذف المنشور؟'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, false),
                                                  child: const Text('إلغاء')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, true),
                                                  child: const Text('حذف'))
                                            ])) ==
                                true) {
                              await PostPublishService.deletePost(
                                  '${post['id']}');
                              SharedActivity156.refresh();
                            }
                          },
                          onShareToProfile: _share);
                    })
                  else if (row['clips'] is Map)
                    Builder(builder: (context) {
                      final clip = Map<String, dynamic>.from(row['clips']);
                      return ListTile(
                          leading: const Icon(Icons.play_circle,
                              size: 44, color: AppTheme.primary),
                          title: Text('${clip['caption'] ?? 'شورتس'}'),
                          subtitle: const Text('فتح الشورت الأصلي'),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => VerticalClipsViewer(
                                      clips: [clip], initialIndex: 0))));
                    })
                ])),
      if (more)
        TextButton(
            onPressed: () => _load(), child: const Text('المزيد من المشاركات'))
    ]);
  }
}
