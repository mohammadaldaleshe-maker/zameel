import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../friends/friends_screen.dart';
import '../comments/comments_screen.dart';
import '../anonymous/anonymous_screen.dart';  // ✅ استيراد صحيح
import '../groups/groups_screen.dart';

// ============================================================
// NOTIFICATIONS SCREEN
// ============================================================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = [
    {
      'id': 1,
      'type': 'friend_request',
      'title_ar': 'طلب صداقة جديد',
      'title_en': 'New Friend Request',
      'body_ar': 'أحمد محمد أرسل لك طلب صداقة',
      'body_en': 'Ahmed Mohammed sent you a friend request',
      'time': 'منذ 5 دقائق',
      'isRead': false,
      'icon': Icons.person_add_rounded,
      'color': 0xFF12AFA5,
    },
    {
      'id': 2,
      'type': 'comment',
      'title_ar': 'تعليق جديد',
      'title_en': 'New Comment',
      'body_ar': 'سارة علي علقت على منشورك',
      'body_en': 'Sara Ali commented on your post',
      'time': 'منذ 25 دقيقة',
      'isRead': false,
      'icon': Icons.comment_rounded,
      'color': 0xFFFF9800,
    },
    {
      'id': 3,
      'type': 'anonymous_message',
      'title_ar': 'رسالة مجهولة',
      'title_en': 'Anonymous Message',
      'body_ar': 'تلقيت رسالة مجهولة جديدة',
      'body_en': 'You received a new anonymous message',
      'time': 'منذ ساعة',
      'isRead': true,
      'icon': Icons.visibility_off_rounded,
      'color': 0xFF9C27B0,
    },
    {
      'id': 4,
      'type': 'like',
      'title_ar': 'إعجاب جديد',
      'title_en': 'New Like',
      'body_ar': 'يزن عمر أعجب بمنشورك',
      'body_en': 'Yazen Omar liked your post',
      'time': 'منذ ساعتين',
      'isRead': true,
      'icon': Icons.favorite_rounded,
      'color': 0xFFE91E63,
    },
    {
      'id': 5,
      'type': 'group_invite',
      'title_ar': 'دعوة إلى مجموعة',
      'title_en': 'Group Invite',
      'body_ar': 'تمت دعوتك للانضمام إلى مجموعة نادي البرمجة',
      'body_en': 'You were invited to join the Programming Club group',
      'time': 'منذ 3 ساعات',
      'isRead': true,
      'icon': Icons.group_add_rounded,
      'color': 0xFF2196F3,
    },
  ];

  int get unreadCount => notifications.where((n) => n['isRead'] == false).length;

  void _markAsRead(int index) {
    setState(() {
      notifications[index]['isRead'] = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم تحديد جميع الإشعارات كمقروءة'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isArabic = Provider.of<LanguageProvider>(context).isArabic;
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              isArabic ? '🗑️ حذف جميع الإشعارات' : '🗑️ Clear All Notifications',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              isArabic
                  ? 'هل أنت متأكد من رغبتك في حذف جميع الإشعارات؟'
                  : 'Are you sure you want to clear all notifications?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    notifications.clear();
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ تم حذف جميع الإشعارات'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(isArabic ? 'حذف الكل' : 'Clear All'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onNotificationTap(Map<String, dynamic> notification, int index) {
    // ✅ تحديد الإشعار كمقروء
    _markAsRead(index);

    // ✅ فتح شاشة مناسبة حسب نوع الإشعار
    final String type = notification['type'];

    switch (type) {
      case 'friend_request':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        );
        break;

      case 'comment':
        final Map<String, dynamic> dummyPost = {
          'text_ar': 'منشور تجريبي للتعليقات',
          'text_en': 'Dummy post for comments',
          'name_ar': 'مستخدم',
          'name_en': 'User',
          'likes': 0,
          'comments': 0,
        };
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CommentsScreen(post: dummyPost)),
        );
        break;

      case 'anonymous_message':
        // ✅ استخدام const لأن AnonymousScreen معرف بـ const
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnonymousScreen()),
        );
        break;

      case 'like':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❤️ تم فتح الإعجاب'),
            backgroundColor: Color(0xFFE91E63),
            duration: Duration(seconds: 2),
          ),
        );
        break;

      case 'group_invite':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GroupsScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📬 فتح الإشعار'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  void _deleteNotification(int index) {
    setState(() {
      notifications.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ تم حذف الإشعار'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
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
            isArabic ? '🔔 الإشعارات' : '🔔 Notifications',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            if (notifications.isNotEmpty) ...[
              IconButton(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded),
                tooltip: isArabic ? 'تحديد الكل كمقروء' : 'Mark all as read',
              ),
              IconButton(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: isArabic ? 'حذف الكل' : 'Clear all',
              ),
            ],
          ],
        ),
        body: notifications.isEmpty
            ? _buildEmptyState(isArabic)
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isRead = notification['isRead'] ?? false;
                  final Color color = Color(notification['color']);

                  return GestureDetector(
                    onTap: () => _onNotificationTap(notification, index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.white : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? Colors.grey.shade200
                              : color.withAlpha(51),
                          width: isRead ? 1 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              notification['icon'],
                              color: color,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? notification['title_ar']
                                            : notification['title_en'],
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          fontSize: 15,
                                          color: isRead
                                              ? Colors.grey.shade700
                                              : Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF12AFA5),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isArabic ? 'جديد' : 'New',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic
                                      ? notification['body_ar']
                                      : notification['body_en'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isRead
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      notification['time'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteNotification(index),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isArabic) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFDDF6F3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 50,
              color: const Color(0xFF087F78),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isArabic ? '📭 لا توجد إشعارات' : '📭 No notifications',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'عندما تصل إشعارات جديدة ستظهر هنا'
                : 'When new notifications arrive, they will appear here',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}