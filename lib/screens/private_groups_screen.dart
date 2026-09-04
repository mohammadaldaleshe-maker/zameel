import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// ============================================================
// PRIVATE GROUPS SCREEN - المجموعات الخاصة (معدل)
// ============================================================

class PrivateGroupsScreen extends StatefulWidget {
  const PrivateGroupsScreen({super.key});

  @override
  State<PrivateGroupsScreen> createState() => _PrivateGroupsScreenState();
}

class _PrivateGroupsScreenState extends State<PrivateGroupsScreen> {
  List<Map<String, dynamic>> groups = [
    {
      'id': 1,
      'name_ar': 'نادي البرمجة',
      'name_en': 'Programming Club',
      'description_ar': 'مجموعة لمحبي البرمجة وتبادل المعرفة',
      'description_en': 'A group for programming enthusiasts and knowledge sharing',
      'members': 156,
      'isPrivate': true,
      'isJoined': true,
      'image': Icons.code_rounded,
      'color': 0xFF12AFA5,
    },
    {
      'id': 2,
      'name_ar': 'قسم علم الحاسوب',
      'name_en': 'Computer Science Department',
      'description_ar': 'لطلاب علم الحاسوب في الجامعة الأردنية',
      'description_en': 'For Computer Science students at UJ',
      'members': 320,
      'isPrivate': true,
      'isJoined': false,
      'image': Icons.computer_rounded,
      'color': 0xFF2196F3,
    },
    {
      'id': 3,
      'name_ar': 'مكتبة زميل',
      'name_en': 'Zameel Library',
      'description_ar': 'مشاركة الكتب والملخصات الجامعية',
      'description_en': 'Sharing books and university summaries',
      'members': 89,
      'isPrivate': false,
      'isJoined': true,
      'image': Icons.menu_book_rounded,
      'color': 0xFFFF9800,
    },
    {
      'id': 4,
      'name_ar': 'نادي الروبوتيكس',
      'name_en': 'Robotics Club',
      'description_ar': 'مجموعة المهتمين بالروبوتات والذكاء الاصطناعي',
      'description_en': 'A group for robotics and AI enthusiasts',
      'members': 67,
      'isPrivate': true,
      'isJoined': false,
      'image': Icons.settings_rounded,
      'color': 0xFF9C27B0,
    },
  ];

  void _createGroup() {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'إنشاء مجموعة خاصة' : 'Create private group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isArabic ? 'اسم المجموعة' : 'Group name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isArabic ? 'الوصف' : 'Description',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              setState(() {
                groups.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'name_ar': name,
                  'name_en': name,
                  'description_ar': descriptionController.text.trim(),
                  'description_en': descriptionController.text.trim(),
                  'members': 1,
                  'isPrivate': true,
                  'isJoined': true,
                  'image': Icons.lock_rounded,
                  'color': 0xFF12AFA5,
                });
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isArabic ? '✅ تم إنشاء المجموعة' : '✅ Group created'),
                  backgroundColor: const Color(0xFF12AFA5),
                ),
              );
            },
            child: Text(isArabic ? 'إنشاء' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _toggleJoin(int index) {
    setState(() {
      groups[index]['isJoined'] = !groups[index]['isJoined'];
      if (groups[index]['isJoined']) {
        groups[index]['members']++;
      } else {
        groups[index]['members']--;
      }
    });

    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final groupName = isArabic ? groups[index]['name_ar'] : groups[index]['name_en'];
    final isJoined = groups[index]['isJoined'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isJoined
              ? (isArabic ? '✅ انضممت إلى $groupName' : '✅ Joined $groupName')
              : (isArabic ? '❌ غادرت $groupName' : '❌ Left $groupName'),
        ),
        backgroundColor: isJoined ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
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
            isArabic ? '👥 المجموعات الخاصة' : '👥 Private Groups',
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
            IconButton(
              onPressed: _createGroup,
              icon: const Icon(Icons.add_rounded),
              tooltip: isArabic ? 'إضافة مجموعة' : 'Add group',
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final color = Color(group['color']);
            final isPrivate = group['isPrivate'] ?? false;
            final isJoined = group['isJoined'] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      group['image'],
                      color: color,
                      size: 30,
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
                                isArabic ? group['name_ar'] : group['name_en'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isPrivate)
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isArabic ? group['description_ar'] : group['description_en'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${group['members']} ${isArabic ? 'عضو' : 'members'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _toggleJoin(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJoined ? Colors.grey.shade200 : color,
                      foregroundColor: isJoined ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      isJoined
                          ? (isArabic ? 'مغادرة' : 'Leave')
                          : (isArabic ? 'انضمام' : 'Join'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isJoined ? Colors.grey.shade600 : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}