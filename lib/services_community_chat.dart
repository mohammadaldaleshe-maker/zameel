import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityScope {
  final String scope;
  final String? university;
  final String? college;
  final String? department;

  const CommunityScope._(this.scope, this.university, this.college, this.department);

  const CommunityScope.global() : this._('global', null, null, null);
  const CommunityScope.faculty({required String university, required String college})
      : this._('faculty', university, college, null);
  const CommunityScope.major({required String university, required String college, required String department})
      : this._('major', university, college, department);

  String get key => [scope, university ?? '', college ?? '', department ?? ''].join('|');
}

class ZameelCommunityChatService {
  static final SupabaseClient db = Supabase.instance.client;

  static Future<Map<String, dynamic>?> currentProfile() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await db
        .from('users')
        .select('id,name,university,college,department,profile_image')
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  static Future<List<Map<String, dynamic>>> listMessages(CommunityScope scope) async {
    var query = db.from('community_messages').select('id,scope,university,college,department,user_id,content,created_at,users(name,profile_image)');
    query = query.eq('scope', scope.scope);
    if (scope.university == null) {
      query = query.filter('university', 'is', 'null').filter('college', 'is', 'null').filter('department', 'is', 'null');
    } else if (scope.scope == 'faculty') {
      query = query.eq('university', scope.university!).eq('college', scope.college!).filter('department', 'is', 'null');
    } else {
      query = query.eq('university', scope.university!).eq('college', scope.college!).eq('department', scope.department!);
    }
    final rows = await query.order('created_at', ascending: true).limit(300);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> sendMessage({required CommunityScope scope, required String content}) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception('Authentication required');
    final row = await db.from('community_messages').insert({
      'scope': scope.scope,
      'university': scope.university,
      'college': scope.college,
      'department': scope.department,
      'user_id': uid,
      'content': content.trim(),
    }).select('id,scope,university,college,department,user_id,content,created_at,users(name,profile_image)').single();
    return Map<String, dynamic>.from(row);
  }
}
