import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';

// ============================================================
// ZAMEEL MEET SCREEN
// ============================================================

class MeetScreen extends StatefulWidget {
  const MeetScreen({super.key});

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  int selectedTab = 0; // 0 = إنشاء اجتماع, 1 = الانضمام, 2 = الاجتماعات السابقة

  final List<Map<String, dynamic>> pastMeetings = [
    {
      'id': 1,
      'title': 'اجتماع فريق البرمجة',
      'date': '2024-06-15',
      'time': '14:30',
      'participants': 12,
      'duration': '1:30',
    },
    {
      'id': 2,
      'title': 'محاضرة قواعد البيانات',
      'date': '2024-06-14',
      'time': '10:00',
      'participants': 45,
      'duration': '2:00',
    },
    {
      'id': 3,
      'title': 'لقاء مع مشرف التخرج',
      'date': '2024-06-13',
      'time': '16:00',
      'participants': 3,
      'duration': '0:45',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '🎥 Zameel Meet' : '🎥 Zameel Meet',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ====================================================
            // TABS
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _MeetTabButton(
                    text: isArabic ? '➕ إنشاء' : '➕ Create',
                    isSelected: selectedTab == 0,
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _MeetTabButton(
                    text: isArabic ? '🔗 انضمام' : '🔗 Join',
                    isSelected: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _MeetTabButton(
                    text: isArabic ? '📋 سابقة' : '📋 History',
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

            // ====================================================
            // CONTENT
            // ====================================================
            Expanded(
              child: selectedTab == 0
                  ? _buildCreateTab(isArabic)
                  : selectedTab == 1
                      ? _buildJoinTab(isArabic)
                      : _buildHistoryTab(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CREATE TAB (إنشاء اجتماع)
  // ============================================================

  Widget _buildCreateTab(bool isArabic) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController timeController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // صورة توضيحية
          // ==============================================
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF12AFA5),
                  Color(0xFF087F78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_call_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'ابدأ اجتماعك الآن',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==============================================
          // عنوان الاجتماع
          // ==============================================
          Text(
            isArabic ? '📝 عنوان الاجتماع' : '📝 Meeting Title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'مثال: اجتماع فريق البرمجة'
                  : 'Example: Programming team meeting',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),

          const SizedBox(height: 16),

          // ==============================================
          // التاريخ والوقت
          // ==============================================
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? '📅 التاريخ' : '📅 Date',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        hintText: '2024-06-20',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? '⏰ الوقت' : '⏰ Time',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(
                        hintText: '14:30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ==============================================
          // زر إنشاء الاجتماع
          // ==============================================
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ يرجى إدخال عنوان الاجتماع'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // محاكاة إنشاء الاجتماع
                showDialog(
                  context: context,
                  builder: (context) {
                    return Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          '🎉 تم إنشاء الاجتماع!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? '✅ تم إنشاء الاجتماع بنجاح'
                                  : '✅ Meeting created successfully',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📌 ${titleController.text}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '📅 ${dateController.text} • ⏰ ${timeController.text}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF12AFA5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    color: Color(0xFF12AFA5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'https://zameel.meet/join/xyz123',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF12AFA5),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('🔗 تم نسخ الرابط!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                      color: Color(0xFF12AFA5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(isArabic ? 'إغلاق' : 'Close'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // محاكاة بدء الاجتماع
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MeetingRoomScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.video_call_rounded),
                            label: Text(
                              isArabic ? 'بدء الاجتماع' : 'Start Meeting',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF12AFA5),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: const Icon(Icons.video_call_rounded),
              label: Text(
                isArabic ? '🚀 إنشاء اجتماع' : '🚀 Create Meeting',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12AFA5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // JOIN TAB (الانضمام إلى اجتماع)
  // ============================================================

  Widget _buildJoinTab(bool isArabic) {
    final TextEditingController codeController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // صورة توضيحية
          // ==============================================
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF9800),
                  Color(0xFFE65100),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انضم إلى اجتماع موجود',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==============================================
          // رمز الاجتماع
          // ==============================================
          Text(
            isArabic ? '🔑 رمز الاجتماع' : '🔑 Meeting Code',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              hintText: isArabic ? 'مثال: xyz123' : 'Example: xyz123',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),

          const SizedBox(height: 16),

          // ==============================================
          // زر الانضمام
          // ==============================================
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                if (codeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ يرجى إدخال رمز الاجتماع'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // محاكاة الانضمام
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetingRoomScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.login_rounded),
              label: Text(
                isArabic ? '🔗 انضمام إلى الاجتماع' : '🔗 Join Meeting',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY TAB (الاجتماعات السابقة)
  // ============================================================

  Widget _buildHistoryTab(bool isArabic) {
    if (pastMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد اجتماعات سابقة' : 'No past meetings',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'اجتماعاتك السابقة ستظهر هنا'
                  : 'Your past meetings will appear here',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pastMeetings.length,
      itemBuilder: (context, index) {
        final meeting = pastMeetings[index];
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
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF12AFA5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.video_call_rounded,
                color: Color(0xFF12AFA5),
                size: 28,
              ),
            ),
            title: Text(
              meeting['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📅 ${meeting['date']} • ⏰ ${meeting['time']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '👥 ${meeting['participants']} مشارك • ⏱️ ${meeting['duration']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? '📋 عرض تفاصيل ${meeting['title']}'
                          : '📋 Viewing ${meeting['title']} details',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// MEET TAB BUTTON
// ============================================================

class _MeetTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _MeetTabButton({
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
// MEETING ROOM SCREEN (شاشة الاجتماع)
// ============================================================

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({super.key});

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  bool isMuted = false;
  bool isVideoOn = true;
  bool isScreenSharing = false;
  bool isChatOpen = false;

  final List<Map<String, dynamic>> participants = [
    {'name': 'أحمد', 'isVideo': true, 'isMuted': false, 'color': 0xFF12AFA5},
    {'name': 'سارة', 'isVideo': true, 'isMuted': true, 'color': 0xFFFF9800},
    {'name': 'محمد', 'isVideo': false, 'isMuted': false, 'color': 0xFF2196F3},
    {'name': 'نور', 'isVideo': true, 'isMuted': false, 'color': 0xFF9C27B0},
  ];

  final List<Map<String, String>> chatMessages = [
    {'sender': 'أحمد', 'message': 'مرحباً جميعاً 👋', 'time': '14:32'},
    {'sender': 'سارة', 'message': 'أهلاً! هل الجميع هنا؟', 'time': '14:33'},
    {'sender': 'محمد', 'message': 'نعم، أنا هنا ✅', 'time': '14:33'},
  ];

  final TextEditingController _chatController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ====================================================
            // MAIN CONTENT
            // ====================================================
            Column(
              children: [
                // ==============================================
                // شريط الحالة
                // ==============================================
                Container(
                  padding: const EdgeInsets.only(top: 40, right: 16, left: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${participants.length} ${isArabic ? 'مشارك' : 'Participants'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '00:00',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ==============================================
                // شبكة المشاركين
                // ==============================================
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      final Color color = Color(participant['color']);
                      final bool hasVideo = participant['isVideo'];
                      final bool isMuted = participant['isMuted'];

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: index == 0 ? Colors.green : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // ==============================================
                            // فيديو وهمي (صورة)
                            // ==============================================
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 35,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    participant['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (index == 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'أنت',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // ==============================================
                            // أيقونة كتم الصوت
                            // ==============================================
                            if (isMuted)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mic_off_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),

                            // ==============================================
                            // أيقونة كاميرا
                            // ==============================================
                            if (!hasVideo)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.videocam_off_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ==============================================
                // أزرار التحكم
                // ==============================================
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: isMuted ? (isArabic ? 'كتم' : 'Mute') : (isArabic ? 'صوت' : 'Sound'),
                        color: isMuted ? Colors.red : Colors.white,
                        onTap: () {
                          setState(() {
                            isMuted = !isMuted;
                          });
                        },
                      ),
                      _ControlButton(
                        icon: isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        label: isVideoOn ? (isArabic ? 'كاميرا' : 'Camera') : (isArabic ? 'إيقاف' : 'Off'),
                        color: isVideoOn ? Colors.white : Colors.red,
                        onTap: () {
                          setState(() {
                            isVideoOn = !isVideoOn;
                          });
                        },
                      ),
                      _ControlButton(
                        icon: isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                        label: isScreenSharing ? (isArabic ? 'إيقاف' : 'Stop') : (isArabic ? 'مشاركة' : 'Share'),
                        color: isScreenSharing ? Colors.red : Colors.white,
                        onTap: () {
                          setState(() {
                            isScreenSharing = !isScreenSharing;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isScreenSharing
                                    ? (isArabic ? '🖥️ جارٍ مشاركة الشاشة' : '🖥️ Screen sharing started')
                                    : (isArabic ? '🖥️ تم إيقاف مشاركة الشاشة' : '🖥️ Screen sharing stopped'),
                              ),
                              backgroundColor: isScreenSharing ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      ),
                      _ControlButton(
                        icon: Icons.chat_rounded,
                        label: isArabic ? 'دردشة' : 'Chat',
                        color: isChatOpen ? Colors.blue : Colors.white,
                        onTap: () {
                          setState(() {
                            isChatOpen = !isChatOpen;
                          });
                        },
                      ),
                      _ControlButton(
                        icon: Icons.call_end_rounded,
                        label: isArabic ? 'إنهاء' : 'End',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ====================================================
            // CHAT OVERLAY (دردشة جانبية)
            // ====================================================
            if (isChatOpen)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 300,
                child: Container(
                  color: Colors.grey.shade900,
                  child: Column(
                    children: [
                      // ==============================================
                      // رأس الدردشة
                      // ==============================================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '💬 الدردشة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  isChatOpen = false;
                                });
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ==============================================
                      // رسائل الدردشة
                      // ==============================================
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = chatMessages[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        msg['sender']!,
                                        style: const TextStyle(
                                          color: Color(0xFF12AFA5),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg['time']!,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['message']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // ==============================================
                      // إدخال الرسالة
                      // ==============================================
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          border: Border(
                            top: BorderSide(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'اكتب رسالة...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade700,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    setState(() {
                                      chatMessages.add({
                                        'sender': 'أنت',
                                        'message': value.trim(),
                                        'time': DateTime.now().toString().substring(11, 16),
                                      });
                                      _chatController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: const Color(0xFF12AFA5),
                              child: IconButton(
                                onPressed: () {
                                  final text = _chatController.text.trim();
                                  if (text.isNotEmpty) {
                                    setState(() {
                                      chatMessages.add({
                                        'sender': 'أنت',
                                        'message': text,
                                        'time': DateTime.now().toString().substring(11, 16),
                                      });
                                      _chatController.clear();
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
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
}

// ============================================================
// CONTROL BUTTON
// ============================================================

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color == Colors.red ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}