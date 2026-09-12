import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  List<Map<String, dynamic>> get userPosts => _userPosts;
  bool get isLoading => _isLoading;

  // جلب بيانات المستخدم الحالي
  Future<void> loadCurrentUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // جلب بيانات المستخدم من جدول users
      final response = await Supabase.instance.client
          .from('users')
          .select('id,name,university,college,department,profile_image,account_privacy,default_post_audience,allow_messages,allow_calls,notifications_enabled,gender,role,created_at,updated_at')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _currentUser = Map<String, dynamic>.from(response);
      } else {
        // إذا لم يكن هناك بيانات، أنشئ بيانات افتراضية
        _currentUser = {
          'id': user.id,
          'name': user.userMetadata?['name'] ?? 'مستخدم',
          'email': user.email,
          'university': '',
          'college': '',
          'department': '',
          'profile_image': null,
        };
      }

      _isLoading = false;
      notifyListeners();

      // جلب منشورات المستخدم
      await loadUserPosts(user.id);
    } catch (e) {
      print('Error loading user: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // جلب منشورات مستخدم معين
  Future<void> loadUserPosts(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('*, users(id,name,profile_image,university,college,department,role,gender)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _userPosts = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading user posts: $e');
    }
  }

  // تحديث بيانات المستخدم
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final response = await Supabase.instance.client
          .from('users')
          .update(data)
          .eq('id', user.id)
          .select('id,name,university,college,department,profile_image,account_privacy,default_post_audience,allow_messages,allow_calls,notifications_enabled,gender,role,created_at,updated_at')
          .single();

      if (response != null) {
        _currentUser = Map<String, dynamic>.from(response);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // تحديث صورة البروفايل
  Future<bool> updateProfileImage(String imageUrl) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final response = await Supabase.instance.client
          .from('users')
          .update({'profile_image': imageUrl})
          .eq('id', user.id)
          .select('id,name,university,college,department,profile_image,account_privacy,default_post_audience,allow_messages,allow_calls,notifications_enabled,gender,role,created_at,updated_at')
          .single();

      if (response != null) {
        _currentUser = Map<String, dynamic>.from(response);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating profile image: $e');
      return false;
    }
  }

  // إضافة منشور جديد لقائمة المستخدم
  void addUserPost(Map<String, dynamic> post) {
    _userPosts.insert(0, post);
    notifyListeners();
  }

  // حذف منشور من قائمة المستخدم
  void removeUserPost(String postId) {
    _userPosts.removeWhere((post) => post['id'] == postId);
    notifyListeners();
  }

  // تسجيل الخروج
  void clearUser() {
    _currentUser = null;
    _userPosts = [];
    notifyListeners();
  }
}
