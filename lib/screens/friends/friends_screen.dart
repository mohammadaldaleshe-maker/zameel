import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../chat/chat_screen.dart';

// ============================================================
// FRIENDS SCREEN
// ============================================================

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int selectedTab = 0;

  List<Map<String, dynamic>> friends = [
    {
      'id': 1,
      'name': 'أحمد محمد',
      'department': 'علم الحاسوب',
      'university': 'الجامعة الأردنية',
      'status': 'online',
      'lastSeen': 'الآن',
    },
    {
      'id': 2,
      'name': 'سارة علي',
      'department': 'هندسة البرمجيات',
      'university': 'الجامعة الأردنية',
      'status': 'offline',
      'lastSeen': 'منذ 5 دقائق',
    },
    {
      'id': 3,
      'name': 'يزن عمر',
      'department': 'نظم المعلومات',
      'university': 'جامعة اليرموك',
      'status': 'online',
      'lastSeen': 'الآن',
    },
    {
      'id': 4,
      'name': 'نور خالد',
      'department': 'علم الحاسوب',
      'university': 'الجامعة الأردنية',
      'status': 'offline',
      'lastSeen': 'منذ ساعة',
    },
  ];

  List<Map<String, dynamic>> friendRequests = [
    {
      'id': 1,
      'name': 'ليلى أحمد',
      'department': 'تكنولوجيا المعلومات',
      'university': 'جامعة العلوم والتكنولوجيا',
      'mutualFriends': 3,
      'image': null,
    },
    {
      'id': 2,
      'name': 'خالد يوسف',
      'department': 'هندسة البرمجيات',
      'university': 'الجامعة الأردنية',
      'mutualFriends': 5,
      'image': null,
    },
  ];

  List<Map<String, dynamic>> suggestedFriends = [
    {
      'id': 5,
      'name': 'محمد سليمان',
      'department': 'هندسة البرمجيات',
      'university': 'الجامعة الأردنية',
      'mutualFriends': 4,
      'image': null,
    },
    {
      'id': 6,
      'name': 'رنا ماجد',
      'department': 'علم الحاسوب',
      'university': 'جامعة العلوم والتكنولوجيا',
      'mutualFriends': 2,
      'image': null,
    },
  ];

  // ============================================================
  // دوال جديدة: حظر وإزالة صديق
  // ============================================================

  void _removeFriend(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'إزالة صديق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في إزالة ${friends[index]['name']} من قائمة الزملاء؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    friends.removeAt(index);
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم إزالة الصديق من القائمة'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تأكيد الإزالة'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _blockFriend(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'حظر صديق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في حظر ${friends[index]['name']}؟ سيتم إزالته من قائمة الزملاء ولن يتمكن من التواصل معك.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    friends.removeAt(index);
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⛔ تم حظر الصديق بنجاح'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تأكيد الحظر'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startChat(String friendName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const ChatScreen(),
    ),
  );
}

  void _showSearchDialog() {
    final controller = TextEditingController();
    final all = <Map<String, dynamic>>[
      ...friends,
      ...suggestedFriends,
      ...friendRequests,
    ];
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;

    showDialog(
      context: context,
      builder: (dialogContext) {
        List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(all);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void search(String value) {
              final q = value.trim().toLowerCase();
              setDialogState(() {
                results = q.isEmpty
                    ? List<Map<String, dynamic>>.from(all)
                    : all.where((f) =>
                        '${f['name']}'.toLowerCase().contains(q) ||
                        '${f['department']}'.toLowerCase().contains(q) ||
                        '${f['university']}'.toLowerCase().contains(q)).toList();
              });
            }

            return AlertDialog(
              title: Text(isArabic ? '🔎 البحث عن زميل' : '🔎 Search friends'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: search,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'الاسم أو التخصص أو الجامعة' : 'Name, major or university',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            search('');
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 280,
                      child: results.isEmpty
                          ? Center(child: Text(isArabic ? 'لا توجد نتائج' : 'No results'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, index) {
                                final friend = results[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${friend['name']}'.isNotEmpty ? '${friend['name']}'[0] : '?'),
                                  ),
                                  title: Text('${friend['name']}'),
                                  subtitle: Text('${friend['department'] ?? ''}'),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    _startChat('${friend['name']}');
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _acceptRequest(int index) {
    setState(() {
      final request = friendRequests.removeAt(index);
      friends.insert(0, {
        'id': request['id'],
        'name': request['name'],
        'department': request['department'],
        'university': request['university'],
        'status': 'online',
        'lastSeen': 'الآن',
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم قبول طلب الصداقة!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _rejectRequest(int index) {
    setState(() {
      friendRequests.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ تم رفض طلب الصداقة'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _sendFriendRequest(int index) {
    setState(() {
      final friend = suggestedFriends.removeAt(index);
      friendRequests.insert(0, {
        'id': friend['id'],
        'name': friend['name'],
        'department': friend['department'],
        'university': friend['university'],
        'mutualFriends': friend['mutualFriends'],
        'image': friend['image'],
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم إرسال طلب صداقة!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '👥 الزملاء' : '👥 Friends',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _showSearchDialog,
              icon: const Icon(Icons.search_rounded),
              tooltip: isArabic ? 'بحث عن زميل' : 'Search friends',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FriendTabButton(
                    text: isArabic
                        ? 'الزملاء (${friends.length})'
                        : 'Friends (${friends.length})',
                    isSelected: selectedTab == 0,
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FriendTabButton(
                    text: isArabic
                        ? 'الطلبات (${friendRequests.length})'
                        : 'Requests (${friendRequests.length})',
                    isSelected: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FriendTabButton(
                    text: isArabic
                        ? 'مقترحين (${suggestedFriends.length})'
                        : 'Suggested (${suggestedFriends.length})',
                    isSelected: selectedTab == 2,
                    onTap: () {
                      setState(() {
                        selectedTab = 2;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: selectedTab == 0
                  ? _buildFriendsList(isArabic)
                  : selectedTab == 1
                      ? _buildFriendRequestsList(isArabic)
                      : _buildSuggestedFriendsList(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FRIENDS LIST (مع أزرار الحظر والإزالة)
  // ============================================================

  Widget _buildFriendsList(bool isArabic) {
    if (friends.isEmpty) {
      return _EmptyState(
        icon: Icons.people_outline_rounded,
        title: isArabic ? 'لا يوجد زملاء بعد' : 'No friends yet',
        subtitle: isArabic
            ? 'ابحث عن زملائك في الجامعة وأضفهم'
            : 'Search for your university friends and add them',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        final isOnline = friend['status'] == 'online';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ==============================================
                // Avatar
                // ==============================================
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFDDF6F3),
                      child: Icon(
                        Icons.person_rounded,
                        color: Color(0xFF087F78),
                        size: 28,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // ==============================================
                // Info
                // ==============================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${friend['department']} • ${friend['university']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline
                            ? (isArabic ? '🟢 متصل' : '🟢 Online')
                            : (isArabic ? '⚫ غير متصل' : '⚫ Offline'),
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // ==============================================
                // Chat Button
                // ==============================================
                IconButton(
                  onPressed: () => _startChat(friend['name']),
                  icon: const Icon(
                    Icons.chat_outlined,
                    color: Color(0xFF12AFA5),
                    size: 22,
                  ),
                ),
                // ==============================================
                // More Options (Remove / Block)
                // ==============================================
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      _removeFriend(index);
                    } else if (value == 'block') {
                      _blockFriend(index);
                    }
                  },
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_rounded, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('إزالة من الزملاء'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حظر'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FRIEND REQUESTS LIST
  // ============================================================

  Widget _buildFriendRequestsList(bool isArabic) {
    if (friendRequests.isEmpty) {
      return _EmptyState(
        icon: Icons.person_add_disabled_rounded,
        title: isArabic ? 'لا توجد طلبات صداقة' : 'No friend requests',
        subtitle: isArabic
            ? 'عندما يرسل لك أحدهم طلباً، سيظهر هنا'
            : 'When someone sends you a request, it will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: friendRequests.length,
      itemBuilder: (context, index) {
        final request = friendRequests[index];
        return _FriendRequestCard(
          name: request['name'],
          department: request['department'],
          university: request['university'],
          mutualFriends: request['mutualFriends'],
          isArabic: isArabic,
          onAccept: () => _acceptRequest(index),
          onReject: () => _rejectRequest(index),
        );
      },
    );
  }

  // ============================================================
  // SUGGESTED FRIENDS LIST
  // ============================================================

  Widget _buildSuggestedFriendsList(bool isArabic) {
    if (suggestedFriends.isEmpty) {
      return _EmptyState(
        icon: Icons.person_search_rounded,
        title: isArabic ? 'لا توجد اقتراحات' : 'No suggestions',
        subtitle: isArabic
            ? 'سوف نقترح لك أشخاصاً قد تعرفهم'
            : 'We will suggest people you might know',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: suggestedFriends.length,
      itemBuilder: (context, index) {
        final friend = suggestedFriends[index];
        return _SuggestedFriendCard(
          name: friend['name'],
          department: friend['department'],
          university: friend['university'],
          mutualFriends: friend['mutualFriends'],
          isArabic: isArabic,
          onAdd: () => _sendFriendRequest(index),
        );
      },
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
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

// ============================================================
// TAB BUTTON
// ============================================================

class _FriendTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendTabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF12AFA5)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF12AFA5)
                  : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FRIEND REQUEST CARD
// ============================================================

class _FriendRequestCard extends StatelessWidget {
  final String name;
  final String department;
  final String university;
  final int mutualFriends;
  final bool isArabic;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FriendRequestCard({
    required this.name,
    required this.department,
    required this.university,
    required this.mutualFriends,
    required this.isArabic,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFDDF6F3),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF087F78),
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$department • $university',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? '$mutualFriends زميل مشترك'
                        : '$mutualFriends mutual friends',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12AFA5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: onAccept,
                    icon: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: onReject,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SUGGESTED FRIEND CARD
// ============================================================

class _SuggestedFriendCard extends StatelessWidget {
  final String name;
  final String department;
  final String university;
  final int mutualFriends;
  final bool isArabic;
  final VoidCallback onAdd;

  const _SuggestedFriendCard({
    required this.name,
    required this.department,
    required this.university,
    required this.mutualFriends,
    required this.isArabic,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFDDF6F3),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF087F78),
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$department • $university',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? '$mutualFriends زميل مشترك'
                        : '$mutualFriends mutual friends',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12AFA5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isArabic ? 'إضافة' : 'Add',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}