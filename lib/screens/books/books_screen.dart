import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services_study_files.dart';
import '../../services_book_exchange.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';
import 'package:zameel/config.dart';
import '../chat/chat_screen.dart';
import 'zameel_library_screen.dart';

// ============================================================
// BOOKS SCREEN
// ============================================================

class BooksScreen extends StatefulWidget {
  final String? initialRequestId;
  final bool initialIncomingRequests;

  const BooksScreen({
    super.key,
    this.initialRequestId,
    this.initialIncomingRequests = false,
  });

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  String searchQuery = '';
  String selectedFilter = 'All';
  bool showStudyFiles = false;
  bool loadingStudyFiles = false;
  List<Map<String, dynamic>> studyFiles = [];
  String _myUniversity = '';
  String _myCollege = '';
  String _myDepartment = '';
  String _bookScope = 'college';
  bool _booksLoading = true;
  String? _booksError;

  final List<String> filters = ['All', 'Sale', 'Exchange', 'Lend', 'Donate'];

  final List<Map<String, dynamic>> books = [
    {
      'id': 1,
      'title_ar': 'مقدمة في قواعد البيانات',
      'title_en': 'Introduction to Databases',
      'author_ar': 'د. أحمد العلي',
      'author_en': 'Dr. Ahmad Al-Ali',
      'subject_ar': 'قواعد البيانات',
      'subject_en': 'Databases',
      'university_ar': 'الجامعة الأردنية',
      'university_en': 'University of Jordan',
      'college_ar': 'كلية تكنولوجيا المعلومات',
      'college_en': 'Faculty of Information Technology',
      'department_ar': 'علم الحاسوب',
      'department_en': 'Computer Science',
      'type_ar': 'بيع',
      'type_en': 'Sale',
      'price': '10 دينار',
      'image': null,
      'condition_ar': 'جيد جداً',
      'condition_en': 'Very Good',
      'description_ar': 'كتاب شامل لمادة قواعد البيانات، مناسب لطلاب السنة الثانية والثالثة.',
      'description_en': 'A comprehensive book for the Databases course, suitable for second and third-year students.',
    },
    {
      'id': 2,
      'title_ar': 'هندسة البرمجيات',
      'title_en': 'Software Engineering',
      'author_ar': 'د. محمد سعيد',
      'author_en': 'Dr. Mohammad Saeed',
      'subject_ar': 'هندسة البرمجيات',
      'subject_en': 'Software Engineering',
      'university_ar': 'الجامعة الأردنية',
      'university_en': 'University of Jordan',
      'college_ar': 'كلية تكنولوجيا المعلومات',
      'college_en': 'Faculty of Information Technology',
      'department_ar': 'هندسة البرمجيات',
      'department_en': 'Software Engineering',
      'type_ar': 'مبادلة',
      'type_en': 'Exchange',
      'price': 'مبادلة',
      'image': null,
      'condition_ar': 'ممتاز',
      'condition_en': 'Excellent',
      'description_ar': 'كتاب هندسة البرمجيات، الطبعة الثالثة، يحتوي على أمثلة عملية.',
      'description_en': 'Software Engineering book, 3rd edition, includes practical examples.',
    },
    {
      'id': 3,
      'title_ar': 'الرياضيات المتقدمة',
      'title_en': 'Advanced Mathematics',
      'author_ar': 'د. خالد الحسين',
      'author_en': 'Dr. Khaled Al-Hussein',
      'subject_ar': 'الرياضيات',
      'subject_en': 'Mathematics',
      'university_ar': 'الجامعة الأردنية',
      'university_en': 'University of Jordan',
      'college_ar': 'كلية العلوم',
      'college_en': 'Faculty of Science',
      'department_ar': 'الرياضيات',
      'department_en': 'Mathematics',
      'type_ar': 'إعارة',
      'type_en': 'Lend',
      'price': 'إعارة',
      'image': null,
      'condition_ar': 'جيد',
      'condition_en': 'Good',
      'description_ar': 'كتاب الرياضيات المتقدمة لطلاب الهندسة والعلوم.',
      'description_en': 'Advanced Mathematics book for engineering and science students.',
    },
    {
      'id': 4,
      'title_ar': 'الإدارة المالية',
      'title_en': 'Financial Management',
      'author_ar': 'د. عمر الخطيب',
      'author_en': 'Dr. Omar Al-Khatib',
      'subject_ar': 'إدارة مالية',
      'subject_en': 'Financial Management',
      'university_ar': 'الجامعة الأردنية',
      'university_en': 'University of Jordan',
      'college_ar': 'كلية الأعمال',
      'college_en': 'Faculty of Business',
      'department_ar': 'إدارة الأعمال',
      'department_en': 'Business Administration',
      'type_ar': 'تبرع',
      'type_en': 'Donate',
      'price': 'تبرع',
      'image': null,
      'condition_ar': 'ممتاز',
      'condition_en': 'Excellent',
      'description_ar': 'كتاب الإدارة المالية، مناسب لطلاب السنة الرابعة.',
      'description_en': 'Financial Management book, suitable for fourth-year students.',
    },
    {
      'id': 5,
      'title_ar': 'نظم التشغيل',
      'title_en': 'Operating Systems',
      'author_ar': 'د. نزار حسن',
      'author_en': 'Dr. Nizar Hassan',
      'subject_ar': 'نظم التشغيل',
      'subject_en': 'Operating Systems',
      'university_ar': 'جامعة اليرموك',
      'university_en': 'Yarmouk University',
      'college_ar': 'كلية تكنولوجيا المعلومات',
      'college_en': 'Faculty of Information Technology',
      'department_ar': 'علم الحاسوب',
      'department_en': 'Computer Science',
      'type_ar': 'بيع',
      'type_en': 'Sale',
      'price': '8 دينار',
      'image': null,
      'condition_ar': 'جيد',
      'condition_en': 'Good',
      'description_ar': 'كتاب نظم التشغيل، شرح مفصل مع أمثلة.',
      'description_en': 'Operating Systems book, detailed explanation with examples.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Legacy demo entries are intentionally retained in source, but production
    // browsing starts empty and is filled only from Supabase.
    books.clear();
    _loadAcademicProfile();
    _loadBooks();
    _loadStudyFiles();
    if (widget.initialRequestId?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _showBookRequests(
          incoming: widget.initialIncomingRequests,
          highlightRequestId: widget.initialRequestId,
        );
      });
    }
  }

  Future<void> _loadBooks() async {
    if (mounted) setState(() { _booksLoading = true; _booksError = null; });
    try {
      final loaded = await ZameelBookExchangeService.listBooks();
      if (!mounted) return;
      setState(() {
        books
          ..clear()
          ..addAll(loaded);
        _booksLoading = false;
        _booksError = null;
      });
    } catch (e) {
      debugPrint('Book listings load failed: $e');
      if (!mounted) return;
      setState(() {
        books.clear();
        _booksLoading = false;
        _booksError = e.toString();
      });
    }
  }

  Future<void> _showBookRequests({required bool incoming, String? highlightRequestId}) async {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    try {
      final allRequests = await ZameelBookExchangeService.bookRequests();
      final requests = allRequests.where((request) =>
        incoming ? request['member_role'] == 'owner' : request['member_role'] == 'requester').toList();
      if (highlightRequestId?.isNotEmpty == true) {
        requests.sort((a, b) {
          final aMatch = a['request_id']?.toString() == highlightRequestId;
          final bMatch = b['request_id']?.toString() == highlightRequestId;
          if (aMatch == bMatch) return 0;
          return aMatch ? -1 : 1;
        });
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Row(children: [
                  Icon(incoming ? Icons.inventory_rounded : Icons.receipt_long_rounded, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(incoming ? (ar ? 'طلبات الكتب الواردة' : 'Incoming book requests') : (ar ? 'طلباتي' : 'My requests'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ])),
                Expanded(child: requests.isEmpty
                  ? Center(child: Text(incoming
                      ? (ar ? 'لا توجد طلبات كتب واردة' : 'No incoming book requests')
                      : (ar ? 'لم تطلب أي كتاب بعد' : 'You have not requested any books yet')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: requests.length,
                      itemBuilder: (_, index) {
                        final request = requests[index];
                        final status = request['request_status']?.toString() ?? '';
                        final pending = status == 'pending' && request['member_role'] == 'owner';
                        final accepted = status == 'accepted';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryLight,
                              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                            ),
                            title: Text(request['listing_title']?.toString() ?? ''),
                            subtitle: Text([
                              incoming ? request['requester_name']?.toString() ?? '' : request['owner_name']?.toString() ?? '',
                              _bookRequestRoleLabel(request, ar),
                              if (incoming) request['requester_university']?.toString() ?? '',
                              if (incoming) request['requester_college']?.toString() ?? '',
                              if ((request['initial_message']?.toString() ?? '').isNotEmpty)
                                '“${request['initial_message']}”',
                              _requestStatusLabel(request['request_status']?.toString() ?? '', ar),
                            ].where((value) => value.isNotEmpty).join(' • ')),
                            onTap: accepted ? () => _openAcceptedBookChat(request) : null,
                            trailing: pending
                                ? Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: ar ? 'قبول' : 'Accept',
                                        onPressed: () async {
                                          await ZameelBookExchangeService.respond(request['request_id'].toString(), accept: true);
                                          setSheetState(() => request['request_status'] = 'accepted');
                                          await _loadBooks();
                                        },
                                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                      ),
                                      IconButton(
                                        tooltip: ar ? 'رفض' : 'Reject',
                                        onPressed: () async {
                                          await ZameelBookExchangeService.respond(request['request_id'].toString(), accept: false);
                                          setSheetState(() => request['request_status'] = 'rejected');
                                        },
                                        icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                                      ),
                                    ],
                                  )
                                : accepted
                                    ? const Icon(Icons.chat_bubble_rounded, color: AppTheme.primary)
                                    : null,
                          ),
                        );
                      },
                    )),
              ]),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ar ? 'تعذر تحميل الطلبات' : 'Could not load requests'}: $e')));
    }
  }

  Future<void> _openAcceptedBookChat(Map<String, dynamic> request) async {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    try {
      final chat = await ZameelBookExchangeService.openAcceptedConversation(request['request_id'].toString());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: chat['conversation_id'].toString(),
            partnerId: chat['partner_id'].toString(),
            partnerName: chat['partner_name']?.toString() ?? (ar ? 'زميل' : 'Colleague'),
            allowCalls: false,
            contextLabel: _bookChatContextLabel(request, ar),
            bookRequestId: request['request_id'].toString(),
            bookOfferType: request['listing_offer_type']?.toString(),
            bookMemberRole: request['member_role']?.toString(),
            contextPhone: chat['contact_phone']?.toString(),
          ),
        ),
      );
      await _loadBooks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ar ? 'تعذر فتح محادثة الكتاب' : 'Could not open book chat'}: $e')));
    }
  }

  String _bookRequestRoleLabel(Map<String, dynamic> request, bool ar) {
    final type = request['listing_offer_type']?.toString() ?? 'sale';
    final role = request['member_role']?.toString() ?? '';
    if (type == 'donate') {
      if (role == 'owner') return ar ? 'أنت المتبرع • الطرف الآخر طالب الحصول على الكتاب' : 'You are the donor • the other person is requesting the book';
      return ar ? 'أنت طالب الحصول على الكتاب • الطرف الآخر هو المتبرع' : 'You are requesting the book • the other person is the donor';
    }
    if (type == 'lend') {
      return role == 'owner'
          ? (ar ? 'أنت المُعير' : 'You are the lender')
          : (ar ? 'أنت المستعير' : 'You are the borrower');
    }
    if (type == 'sale') {
      return role == 'owner'
          ? (ar ? 'أنت البائع' : 'You are the seller')
          : (ar ? 'أنت المشتري' : 'You are the buyer');
    }
    if (type == 'exchange') return ar ? 'مبادلة كتاب' : 'Book exchange';
    return '';
  }

  String _bookChatContextLabel(Map<String, dynamic> request, bool ar) {
    final title = request['listing_title']?.toString() ?? '';
    final type = request['listing_offer_type']?.toString() ?? 'sale';
    final role = request['member_role']?.toString() ?? '';
    if (type == 'donate') {
      return role == 'owner'
          ? '${ar ? 'تبرع بالكتاب' : 'Book donation'} • $title'
          : '${ar ? 'استلام كتاب متبرع به' : 'Receiving donated book'} • $title';
    }
    if (type == 'lend') {
      return role == 'owner'
          ? '${ar ? 'إعارة كتاب' : 'Lending book'} • $title'
          : '${ar ? 'استعارة كتاب' : 'Borrowing book'} • $title';
    }
    if (type == 'sale') {
      return role == 'owner'
          ? '${ar ? 'بيع كتاب' : 'Selling book'} • $title'
          : '${ar ? 'شراء كتاب' : 'Buying book'} • $title';
    }
    return '${ar ? 'مبادلة كتاب' : 'Book exchange'} • $title';
  }

  String _requestStatusLabel(String status, bool ar) {
    const arLabels = {'pending':'بانتظار الموافقة','accepted':'مقبول — الدردشة متاحة','rejected':'مرفوض','cancelled':'ملغى','completed':'تم التسليم'};
    const enLabels = {'pending':'Waiting for approval','accepted':'Accepted — chat available','rejected':'Rejected','cancelled':'Cancelled','completed':'Handed over'};
    return (ar ? arLabels : enLabels)[status] ?? status;
  }

  Future<void> _loadAcademicProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client.from('users').select('university,college,department').eq('id', uid).maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _myUniversity = row['university']?.toString().trim() ?? '';
        _myCollege = row['college']?.toString().trim() ?? '';
        _myDepartment = row['department']?.toString().trim() ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadStudyFiles() async {
    if (!ZameelStudyFilesService.signedIn) return;
    setState(() => loadingStudyFiles = true);
    try {
      final files = await ZameelStudyFilesService.listFiles();
      if (!mounted) return;
      setState(() => studyFiles = files);
    } catch (e) {
      debugPrint('Study files load failed: $e');
    } finally {
      if (mounted) setState(() => loadingStudyFiles = false);
    }
  }

  Future<void> _pickStudyFile() async {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'تعذر قراءة الملف. حاول مرة أخرى.' : 'Could not read the file. Please try again.')),
        );
      }
      return;
    }

    final titleController = TextEditingController(text: picked.name.replaceFirst(RegExp(r'\.[^.]+$'), ''));
    final courseController = TextEditingController();
    bool uploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                title: Text(isArabic ? 'رفع ملف دراسي' : 'Upload study file'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(_fileIcon(picked.extension), color: AppTheme.primaryDark, size: 32),
                            const SizedBox(width: 10),
                            Expanded(child: Text(picked.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleController,
                        enabled: !uploading,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'اسم الملف' : 'File title',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: courseController,
                        enabled: !uploading,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'المادة / المساق (اختياري)' : 'Course / subject (optional)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: uploading ? null : () => Navigator.pop(dialogContext),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) return;
                            setDialogState(() => uploading = true);
                            try {
                              await ZameelStudyFilesService.uploadFile(
                                bytes: bytes,
                                filename: picked.name,
                                title: titleController.text.trim(),
                                course: courseController.text.trim(),
                              );
                              if (!mounted) return;
                              Navigator.pop(dialogContext);
                              await _loadStudyFiles();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isArabic ? '✅ تم رفع الملف بنجاح' : '✅ File uploaded successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => uploading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isArabic ? 'تعذر رفع الملف: $e' : 'File upload failed: $e')),
                                );
                              }
                            }
                          },
                    icon: uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(isArabic ? 'رفع' : 'Upload'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
    courseController.dispose();
  }

  Future<void> _openStudyFile(Map<String, dynamic> file) async {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    try {
      final path = file['storage_path']?.toString() ?? '';
      final extension = file['file_extension']?.toString().toLowerCase() ?? '';
      Uint8List bytes;
      if (extension == 'pdf') {
        try {
          bytes = await _downloadBrandedPdf(path);
        } catch (e) {
          debugPrint('Branded PDF fallback: $e');
          bytes = await ZameelStudyFilesService.downloadFile(path);
        }
      } else {
        bytes = await ZameelStudyFilesService.downloadFile(path);
      }
      final originalName = file['file_name']?.toString() ?? 'study_file';
      final brandedName = originalName.startsWith('Zameel_')
          ? originalName
          : 'Zameel_$originalName';
      final savedPath = await FilePicker.saveFile(
        dialogTitle: isArabic ? 'حفظ الملف الدراسي' : 'Save study file',
        fileName: brandedName,
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null
              ? (isArabic ? 'تم إلغاء التنزيل' : 'Download cancelled')
              : (isArabic ? '✅ تم تنزيل الملف مباشرة' : '✅ File downloaded')),
          backgroundColor: savedPath == null ? null : Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'تعذر تنزيل الملف: $e' : 'Could not download file: $e')));
      }
    }
  }

  Future<Uint8List> _downloadBrandedPdf(String storagePath) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('Authentication required');
    final logoData = await rootBundle.load('assets/branding/zameel_mark.png');
    final response = await http.post(
      Uri.parse('${ZameelConfig.supabaseUrl}/functions/v1/brand-study-file'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'storage_path': storagePath,
        'logo_base64': base64Encode(logoData.buffer.asUint8List()),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('PDF branding failed (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  Future<void> _deleteStudyFile(Map<String, dynamic> file) async {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'حذف الملف؟' : 'Delete file?'),
        content: Text(isArabic ? 'سيتم حذف الملف نهائياً من ملفاتك.' : 'This will permanently remove the file from your study files.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isArabic ? 'حذف' : 'Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ZameelStudyFilesService.deleteFile(file);
      await _loadStudyFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'تعذر حذف الملف: $e' : 'Could not delete file: $e')));
    }
  }

  IconData _fileIcon(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  List<Map<String, dynamic>> get filteredBooks {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return books.where((book) {
      final title = (isArabic ? book['title_ar'] : book['title_en']).toString();
      final author = (isArabic ? book['author_ar'] : book['author_en']).toString();
      final subject = (isArabic ? book['subject_ar'] : book['subject_en']).toString();
      final type = (isArabic ? book['type_ar'] : book['type_en']).toString();
      final bookUniversity = (isArabic ? book['university_ar'] : book['university_en']).toString().trim();
      final bookCollege = (isArabic ? book['college_ar'] : book['college_en']).toString().trim();

      final sameUniversity = _myUniversity.isNotEmpty &&
          bookUniversity.toLowerCase() == _myUniversity.toLowerCase();
      final sameCollege = sameUniversity && _myCollege.isNotEmpty &&
          bookCollege.toLowerCase() == _myCollege.toLowerCase();
      final matchesAcademicScope = switch (_bookScope) {
        'all' => true,
        'university' => sameUniversity,
        _ => sameCollege,
      };
      final q = searchQuery.toLowerCase();
      final matchesSearch = title.toLowerCase().contains(q) ||
          author.toLowerCase().contains(q) ||
          subject.toLowerCase().contains(q);
      final matchesFilter = selectedFilter == 'All' || selectedFilter == 'الكل' || type == selectedFilter;
      return matchesAcademicScope && matchesSearch && matchesFilter;
    }).toList();
  }

 void _addBook() {
  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  final isArabic = languageProvider.isArabic;

  if (_myUniversity.isEmpty || _myCollege.isEmpty || _myDepartment.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'أكمل الجامعة والكلية والتخصص في ملفك الشخصي أولاً.' : 'Complete your university, college, and major in your profile first.')));
    return;
  }

  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final subjectController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final phoneController = TextEditingController();
  String selectedType = isArabic ? 'بيع' : 'Sale';
  String selectedCondition = isArabic ? 'جيد' : 'Good';

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            isArabic ? 'إضافة كتاب جديد' : 'Add a New Book',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'عنوان الكتاب' : 'Book Title',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: authorController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'اسم المؤلف' : 'Author Name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'المادة الدراسية' : 'Subject',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'نوع العرض' : 'Offer Type',
                    border: const OutlineInputBorder(),
                  ),
                  items: isArabic
                      ? const [
                          DropdownMenuItem(value: 'بيع', child: Text('💰 بيع')),
                          DropdownMenuItem(value: 'مبادلة', child: Text('🔄 مبادلة')),
                          DropdownMenuItem(value: 'إعارة', child: Text('📖 إعارة')),
                          DropdownMenuItem(value: 'تبرع', child: Text('🎁 تبرع')),
                        ]
                      : const [
                          DropdownMenuItem(value: 'Sale', child: Text('💰 Sale')),
                          DropdownMenuItem(value: 'Exchange', child: Text('🔄 Exchange')),
                          DropdownMenuItem(value: 'Lend', child: Text('📖 Lend')),
                          DropdownMenuItem(value: 'Donate', child: Text('🎁 Donate')),
                        ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedType = value;
                        if (value != 'بيع' && value != 'Sale') priceController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                if (selectedType == 'بيع' || selectedType == 'Sale') ...[
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'السعر (دينار)' : 'Price (JOD)',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                ],

                DropdownButtonFormField<String>(
                  value: selectedCondition,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'حالة الكتاب' : 'Book Condition',
                    border: const OutlineInputBorder(),
                  ),
                  items: isArabic
                      ? const [
                          DropdownMenuItem(value: 'ممتاز', child: Text('⭐ ممتاز')),
                          DropdownMenuItem(value: 'جيد جداً', child: Text('👍 جيد جداً')),
                          DropdownMenuItem(value: 'جيد', child: Text('👌 جيد')),
                          DropdownMenuItem(value: 'مقبول', child: Text('📖 مقبول')),
                        ]
                      : const [
                          DropdownMenuItem(value: 'Excellent', child: Text('⭐ Excellent')),
                          DropdownMenuItem(value: 'Very Good', child: Text('👍 Very Good')),
                          DropdownMenuItem(value: 'Good', child: Text('👌 Good')),
                          DropdownMenuItem(value: 'Acceptable', child: Text('📖 Acceptable')),
                        ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedCondition = value;
                    }
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'وصف الكتاب (اختياري)' : 'Description (Optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم الهاتف للتواصل (اختياري)' : 'Contact phone (optional)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'يرجى إدخال عنوان الكتاب' : 'Please enter a book title')),
                  );
                  return;
                }
                if (authorController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'يرجى إدخال اسم المؤلف' : 'Please enter an author name')),
                  );
                  return;
                }
                if (subjectController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'يرجى إدخال المادة الدراسية' : 'Please enter a subject')),
                  );
                  return;
                }

                try {
                  await ZameelBookExchangeService.createBook(
                    title: titleController.text.trim(),
                    author: authorController.text.trim(),
                    subject: subjectController.text.trim(),
                    university: _myUniversity,
                    college: _myCollege,
                    department: _myDepartment,
                    offerType: selectedType,
                    condition: selectedCondition,
                    description: descriptionController.text.trim(),
                    price: priceController.text.trim(),
                    contactPhone: phoneController.text.trim(),
                  );
                  await _loadBooks();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isArabic ? 'تعذر إضافة الكتاب' : 'Could not add book'}: $e')));
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? '✅ تم إضافة الكتاب بنجاح!' : '✅ Book added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isArabic ? 'إضافة' : 'Add'),
            ),
          ],
        )),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final currentFilters = isArabic
        ? ['الكل', 'بيع', 'مبادلة', 'إعارة', 'تبرع']
        : ['All', 'Sale', 'Exchange', 'Lend', 'Donate'];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? 'مبادلة الكتب' : 'Book Exchange',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: isArabic ? 'طلباتي' : 'My requests',
              onPressed: () => _showBookRequests(incoming: false),
              icon: const Icon(Icons.receipt_long_rounded),
            ),
            IconButton(
              tooltip: isArabic ? 'طلبات الكتب الواردة' : 'Incoming book requests',
              onPressed: () => _showBookRequests(incoming: true),
              icon: const Icon(Icons.inventory_rounded),
            ),
            IconButton(
              onPressed: _addBook,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            // SEARCH BAR
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: isArabic ? 'ابحث عن كتاب، مؤلف، مادة...' : 'Search for a book, author, subject...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppTheme.muted.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ZameelLibraryScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: AppTheme.signatureGradientRtl,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.local_library_rounded,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'مكتبة زميل' : 'Zameel Library',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isArabic
                                    ? 'كتب وملخصات مفهرسة حسب التخصص مع بحث ذكي'
                                    : 'Books and summaries by subject with smart search',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(isArabic ? 'الكتب' : 'Books'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.folder_copy_rounded),
                    label: Text(isArabic ? 'ملفات دراسية' : 'Study Files'),
                  ),
                ],
                selected: {showStudyFiles},
                onSelectionChanged: (value) => setState(() => showStudyFiles = value.first),
              ),
            ),

            if (!showStudyFiles) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isArabic ? 'نطاق عروض الكتب' : 'Book listing scope',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _bookScope,
                      items: [
                        DropdownMenuItem(value: 'college', child: Text(isArabic ? 'كليتي' : 'My college')),
                        DropdownMenuItem(value: 'university', child: Text(isArabic ? 'جامعتي' : 'My university')),
                        DropdownMenuItem(value: 'all', child: Text(isArabic ? 'الكل' : 'All')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _bookScope = value);
                      },
                    ),
                  ],
                ),
              ),
              // FILTER CHIPS
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: currentFilters.length,
                  itemBuilder: (context, index) {
                    final filter = currentFilters[index];
                    final isSelected = filter == selectedFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => selectedFilter = filter),
                        backgroundColor: AppTheme.muted.shade200,
                        selectedColor: AppTheme.primaryLight,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primaryDark : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _booksLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _booksError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off_rounded, size: 60, color: AppTheme.muted),
                                  const SizedBox(height: 12),
                                  Text(isArabic ? 'تعذر تحميل عروض الكتب' : 'Could not load book listings', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 10),
                                  FilledButton.icon(onPressed: _loadBooks, icon: const Icon(Icons.refresh_rounded), label: Text(isArabic ? 'إعادة المحاولة' : 'Retry')),
                                ],
                              ),
                            ),
                          )
                        : filteredBooks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 64, color: AppTheme.muted),
                                    const SizedBox(height: 12),
                                    Text(isArabic ? 'لا توجد كتب في هذا النطاق' : 'No books in this scope', style: const TextStyle(fontSize: 18, color: AppTheme.muted, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(isArabic ? 'غيّر النطاق أو أضف كتاباً جديداً' : 'Change the scope or add a new book', style: const TextStyle(color: AppTheme.muted, fontSize: 14)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBooks,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: filteredBooks.length,
                                  itemBuilder: (context, index) => _BookCard(book: filteredBooks[index]),
                                ),
                              ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Card(
                  elevation: 0,
                  color: AppTheme.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded, color: AppTheme.primaryDark, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isArabic ? 'هذه المكتبة مخصصة لطلاب كليتك فقط. ارفع مذكراتك وملفات المحاضرات بصيغة PDF أو Word أو PowerPoint.' : 'This library is limited to students in your college. Upload lecture notes and study materials as PDF, Word, or PowerPoint files.',
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _pickStudyFile,
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: Text(isArabic ? 'رفع' : 'Upload'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: loadingStudyFiles
                    ? const Center(child: CircularProgressIndicator())
                    : studyFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.muted),
                                const SizedBox(height: 12),
                                Text(isArabic ? 'لا توجد ملفات دراسية بعد' : 'No study files yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.muted)),
                                const SizedBox(height: 6),
                                Text(isArabic ? 'ارفع أول ملف من زر رفع.' : 'Upload your first file using the Upload button.', style: const TextStyle(color: AppTheme.muted)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: studyFiles.length,
                            itemBuilder: (context, index) {
                              final file = studyFiles[index];
                              final extension = file['file_extension']?.toString() ?? '';
                              final size = (file['file_size'] as num?)?.toInt() ?? 0;
                              final sizeLabel = size >= 1024 * 1024
                                  ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                  : '${(size / 1024).toStringAsFixed(0)} KB';
                              final title = file['title']?.toString() ?? file['file_name']?.toString() ?? 'File';
                              final course = file['course']?.toString() ?? '';
                              final isMine = file['user_id']?.toString() == Supabase.instance.client.auth.currentUser?.id;
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.muted.shade200)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryLight,
                                    child: Icon(_fileIcon(extension), color: AppTheme.primaryDark),
                                  ),
                                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text([file['file_name']?.toString() ?? '', if (course.isNotEmpty) course, sizeLabel].where((e) => e.isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      if (action == 'open') _openStudyFile(file);
                                      if (action == 'delete') _deleteStudyFile(file);
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'open', child: Text(isArabic ? 'تنزيل الملف' : 'Download file')),
                                      if (isMine) PopupMenuItem(value: 'delete', child: Text(isArabic ? 'حذف' : 'Delete')),
                                    ],
                                  ),
                                  onTap: () => _openStudyFile(file),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          onPressed: _addBook,
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

// ============================================================
// BOOK CARD
// ============================================================

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([ZameelBookExchangeService.myLibrary(), ZameelBookExchangeService.myLibrarySummary()]);
      if (!mounted) return;
      setState(() { _items = results[0] as List<Map<String, dynamic>>; _summary = results[1] as Map<String, dynamic>; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _add(bool ar) async {
    final controller = TextEditingController();
    bool read = false;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (_, setDialogState) => AlertDialog(
      title: Text(ar ? 'إضافة كتاب إلى مكتبتي' : 'Add a book to My Library'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: controller, decoration: InputDecoration(labelText: ar ? 'عنوان الكتاب' : 'Book title')),
        CheckboxListTile(value: read, onChanged: (v) => setDialogState(() => read = v ?? false), title: Text(ar ? 'قرأت هذا الكتاب' : 'I read this book'), contentPadding: EdgeInsets.zero),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        FilledButton(onPressed: () async { await ZameelBookExchangeService.addOwnedOrReadBook(title: controller.text, read: read); if (dialogContext.mounted) Navigator.pop(dialogContext, true); }, child: Text(ar ? 'إضافة' : 'Add'))],
    )));
    if (saved == true) _load();
  }

  String _label(String category, bool ar) {
    const labelsAr = {'owned':'أملكه','read':'قرأته','added':'أضفته','sold':'مباع','exchanged':'متبادل','donated':'متبرع به','loaned':'مُعار','borrowed':'مستعار'};
    const labelsEn = {'owned':'Owned','read':'Read','added':'Added','sold':'Sold','exchanged':'Exchanged','donated':'Donated','loaned':'Loaned','borrowed':'Borrowed'};
    return (ar ? labelsAr : labelsEn)[category] ?? category;
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final count = _summary['completed_operations']?.toString() ?? '0';
    final ambassador = (_summary['title_label']?.toString() ?? '').isNotEmpty;
    return Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: Text(ar ? 'مكتبتي' : 'My Library'), actions: [IconButton(onPressed: () => _add(ar), icon: const Icon(Icons.add_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: ListTile(leading: Icon(ambassador ? Icons.workspace_premium_rounded : Icons.auto_stories_rounded, color: AppTheme.primary),
          title: Text(ambassador ? (ar ? 'سفير المعرفة' : 'Knowledge Ambassador') : (ar ? '$count عملية مكتملة' : '$count completed operations'), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(ambassador ? (ar ? '$count عملية مكتملة' : '$count completed operations') : (ar ? 'أكمل 100 عملية لتحصل على اللقب' : 'Complete 100 operations to earn the title')))),
        const SizedBox(height: 10),
        if (_items.isEmpty) Padding(padding: const EdgeInsets.only(top: 80), child: Center(child: Text(ar ? 'مكتبتك فارغة؛ أضف أول كتاب.' : 'Your library is empty. Add your first book.'))),
        ..._items.map((item) => Card(child: ListTile(leading: const Icon(Icons.menu_book_rounded, color: AppTheme.primary), title: Text(item['title']?.toString() ?? ''),
          subtitle: Text(_label(item['category']?.toString() ?? '', ar)),
          trailing: item['operation_completed'] == true ? const Icon(Icons.verified_rounded, color: Colors.green) : IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { await ZameelBookExchangeService.removeLibraryBook(item['entry_id'].toString()); _load(); })))),
      ])),
    ));
  }
}

class _BookCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _BookCard({
    required this.book,
  });

  Color _getTypeColor(String type) {
    switch (type) {
      case 'بيع':
      case 'Sale':
        return Colors.green;
      case 'مبادلة':
      case 'Exchange':
        return AppTheme.primary;
      case 'إعارة':
      case 'Lend':
        return Colors.orange;
      case 'تبرع':
      case 'Donate':
        return AppTheme.primaryDark;
      default:
        return AppTheme.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.muted.shade200,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailsScreen(book: book),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 36,
                  color: AppTheme.primaryDark,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? book['title_ar'] : book['title_en'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isArabic ? book['author_ar'] : book['author_en'],
                      style: TextStyle(
                        color: AppTheme.muted.shade600,
                        fontSize: 13,
                      ),
                    ),
                    if ((book['owner_name']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: (book['owner_image']?.toString() ?? '').isNotEmpty
                              ? NetworkImage(book['owner_image'].toString())
                              : null,
                          child: (book['owner_image']?.toString() ?? '').isEmpty ? const Icon(Icons.person, size: 12) : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(book['owner_name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryDark))),
                      ]),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(isArabic ? book['type_ar'] : book['type_en']).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isArabic ? book['type_ar'] : book['type_en'],
                            style: TextStyle(
                              color: _getTypeColor(isArabic ? book['type_ar'] : book['type_en']),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? book['department_ar'] : book['department_en'],
                          style: TextStyle(
                            color: AppTheme.muted.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if ((isArabic ? book['type_ar'] : book['type_en']) == 'بيع' || (isArabic ? book['type_ar'] : book['type_en']) == 'Sale')
                      Text(
                        book['price'],
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              if (book['owner_id']?.toString() == Supabase.instance.client.auth.currentUser?.id)
                IconButton(
                  tooltip: isArabic ? 'إزالة العرض' : 'Remove listing',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () async {
                    await ZameelBookExchangeService.withdrawBook(book['id'].toString());
                    if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BooksScreen()));
                  },
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOOK DETAILS SCREEN
// ============================================================

class BookDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> book;

  const BookDetailsScreen({
    super.key,
    required this.book,
  });

  Future<String?> _chooseOfferedBook(BuildContext context, bool ar) async {
    final mine = await ZameelBookExchangeService.myAvailableBooks();
    if (!context.mounted) return null;
    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'يجب أن تعرض كتاباً لك أولاً لتحديده في المبادلة.' : 'List one of your books first so you can offer it in exchange.')));
      return null;
    }
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'اختر كتابك المقترح للمبادلة' : 'Choose your offered book'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mine.length,
            itemBuilder: (_, index) => ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: AppTheme.primary),
              title: Text(mine[index]['title']?.toString() ?? ''),
              subtitle: Text(mine[index]['author']?.toString() ?? ''),
              onTap: () => Navigator.pop(dialogContext, mine[index]['id']?.toString()),
            ),
          ),
        ),
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
            isArabic ? 'تفاصيل الكتاب' : 'Book Details',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: AppTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                isArabic ? book['title_ar'] : book['title_en'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '👤 ${isArabic ? book['author_ar'] : book['author_en']}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.muted.shade600,
                ),
              ),
              if ((book['owner_name']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: (book['owner_image']?.toString() ?? '').isNotEmpty ? NetworkImage(book['owner_image'].toString()) : null,
                    child: (book['owner_image']?.toString() ?? '').isEmpty ? const Icon(Icons.person_rounded) : null,
                  ),
                  title: Text(book['owner_name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([book['owner_university'], book['owner_college']]
                      .map((v) => v?.toString() ?? '').where((v) => v.isNotEmpty).join(' • ')),
                  trailing: Chip(label: Text(isArabic ? 'متاح' : 'Available')),
                ),
              ],

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag('📚 ${isArabic ? book['subject_ar'] : book['subject_en']}'),
                  _buildTag('🏫 ${isArabic ? book['university_ar'] : book['university_en']}'),
                  _buildTag('🏛️ ${isArabic ? book['college_ar'] : book['college_en']}'),
                  _buildTag('📖 ${isArabic ? book['department_ar'] : book['department_en']}'),
                  _buildTag('📝 ${isArabic ? book['condition_ar'] : book['condition_en']}'),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                isArabic ? 'الوصف' : 'Description',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? book['description_ar'] : book['description_en'],
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            String actionText = '';
                            String actionEmoji = '';
                            final isDonation = book['type_ar'] == 'تبرع' || book['type_en'] == 'Donate';
                            final messageController = TextEditingController(
                              text: isDonation
                                  ? (isArabic
                                      ? 'مرحباً، أرغب في الحصول على هذا الكتاب المتبرع به والتنسيق معك لاستلامه. شكراً لتبرعك.'
                                      : 'Hello, I would like to receive this donated book and arrange its handover. Thank you for donating it.')
                                  : (isArabic
                                      ? 'مرحباً، أرغب في حجز هذا الكتاب والتنسيق معك لاستلامه.'
                                      : 'Hello, I would like to reserve this book and arrange its handover.'),
                            );

                            if (isArabic) {
                              switch (book['type_ar']) {
                                case 'بيع':
                                  actionText = 'شراء';
                                  actionEmoji = '💰';
                                  break;
                                case 'مبادلة':
                                  actionText = 'مبادلة';
                                  actionEmoji = '🔄';
                                  break;
                                case 'إعارة':
                                  actionText = 'إعارة';
                                  actionEmoji = '📖';
                                  break;
                                case 'تبرع':
                                  actionText = 'الحصول على';
                                  actionEmoji = '🎁';
                                  break;
                                default:
                                  actionText = 'طلب';
                                  actionEmoji = '📚';
                              }
                            } else {
                              switch (book['type_en']) {
                                case 'Sale':
                                  actionText = 'Buy';
                                  actionEmoji = '💰';
                                  break;
                                case 'Exchange':
                                  actionText = 'Exchange';
                                  actionEmoji = '🔄';
                                  break;
                                case 'Lend':
                                  actionText = 'Borrow';
                                  actionEmoji = '📖';
                                  break;
                                case 'Donate':
                                  actionText = 'Receive';
                                  actionEmoji = '🎁';
                                  break;
                                default:
                                  actionText = 'Request';
                                  actionEmoji = '📚';
                              }
                            }

                            return Directionality(
                              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                              child: AlertDialog(
                                title: Text(
                                  '$actionEmoji ${isArabic ? 'تأكيد $actionText' : 'Confirm $actionText'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'هل أنت متأكد من رغبتك في $actionText كتاب "${book['title_ar']}" للمؤلف ${book['author_ar']}؟'
                                          : 'Are you sure you want to $actionText "${book['title_en']}" by ${book['author_en']}?',
                                      style: const TextStyle(fontSize: 15, height: 1.5),
                                    ),
                                    if (book['type_en'] == 'Sale' || book['type_ar'] == 'بيع') ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppTheme.accentSoft, borderRadius: BorderRadius.circular(12)),
                                        child: Text(
                                          isArabic
                                              ? 'تنبيه أمان: لا تدفع أي مبلغ مقدمًا، ولا تحوّل المال قبل معاينة الكتاب واستلامه والتأكد من مطابقته للوصف. رتّب اللقاء في مكان عام وآمن. يوفّر زميل وسيلة للتواصل فقط، ولا يتحمل مسؤولية الاتفاقات المالية أو حالات الاحتيال بين المستخدمين.'
                                              : 'Safety notice: Never pay in advance or transfer money before inspecting and receiving the book. Meet in a safe public place. Zameel only provides communication tools and is not responsible for financial agreements or fraud between users.',
                                          style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: messageController,
                                      minLines: 2,
                                      maxLines: 4,
                                      maxLength: 1500,
                                      decoration: InputDecoration(
                                        labelText: isArabic ? 'رسالتك لصاحب الكتاب' : 'Your message to the owner',
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                    },
                                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await ZameelBookExchangeService.requestBook(book, message: messageController.text);
                                        if (!context.mounted) return;
                                        Navigator.pop(dialogContext);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isArabic ? '✅ تم إرسال طلب $actionText إلى صاحب الكتاب' : '✅ Request sent to the book owner'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isArabic ? 'تعذر إرسال الطلب' : 'Could not send request'}: $e')));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(isArabic ? 'تأكيد' : 'Confirm'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isArabic
                            ? (book['type_ar'] == 'بيع'
                                ? '💰 شراء الكتاب'
                                : book['type_ar'] == 'مبادلة'
                                ? '🔄 طلب مبادلة'
                                : book['type_ar'] == 'إعارة'
                                ? '📖 طلب إعارة'
                                : '🎁 طلب الحصول على الكتاب')
                            : (book['type_en'] == 'Sale'
                                ? '💰 Buy Book'
                                : book['type_en'] == 'Exchange'
                                ? '🔄 Request Exchange'
                                : book['type_en'] == 'Lend'
                                ? '📖 Request Borrow'
                                : '🎁 Request Donated Book'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.muted.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final title = isArabic ? book['title_ar'] : book['title_en'];
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            final isDonation = book['type_ar'] == 'تبرع' || book['type_en'] == 'Donate';
                            final messageController = TextEditingController(
                              text: isDonation
                                  ? (isArabic
                                      ? 'مرحباً، هل ما زال كتاب «$title» المتبرع به متاحاً للحصول عليه؟'
                                      : 'Hello, is the donated book "$title" still available to receive?')
                                  : (isArabic
                                      ? 'مرحباً، هل ما زال كتاب «$title» متاحاً؟'
                                      : 'Hello, is "$title" still available?'),
                            );
                            return AlertDialog(
                              title: Text(isArabic ? '💬 التواصل مع صاحب الكتاب' : '💬 Contact book owner'),
                              content: TextField(
                                controller: messageController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'رسالتك' : 'Your message',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await ZameelBookExchangeService.requestBook(book, message: messageController.text);
                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(isArabic ? '✅ تم إرسال طلب الحجز والرسالة' : '✅ Reservation request and message sent'),
                                        backgroundColor: AppTheme.primary,
                                      ));
                                    } catch (e) {
                                      if (dialogContext.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isArabic ? 'تعذر إرسال الطلب' : 'Could not send request'}: $e')));
                                    }
                                  },
                                  child: Text(isArabic ? 'إرسال' : 'Send'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(
                        Icons.chat_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
        ),
      ),
    );
  }
}

class BookExchangeChatScreen extends StatefulWidget {
  final String requestId;
  final String title;
  const BookExchangeChatScreen({super.key, required this.requestId, required this.title});

  @override
  State<BookExchangeChatScreen> createState() => _BookExchangeChatScreenState();
}

class _BookExchangeChatScreenState extends State<BookExchangeChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _contact = {};
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _messagesChannel = ZameelBookExchangeService.subscribeToBookRequestMessages(
      widget.requestId,
      () => _load(silent: true),
    );
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final messages = await ZameelBookExchangeService.requestMessages(widget.requestId);
      final contact = await ZameelBookExchangeService.requestContact(widget.requestId);
      if (!mounted) return;
      setState(() { _messages = messages; _contact = contact; });
    } catch (e) {
      if (!silent) debugPrint('Book chat load failed: $e');
    }
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    await ZameelBookExchangeService.sendRequestMessage(widget.requestId, value);
    await _load();
  }

  @override
  void dispose() {
    ZameelBookExchangeService.removeRealtimeChannel(_messagesChannel);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final phone = _contact['phone']?.toString() ?? '';
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(ar ? 'إتمام عملية الكتاب؟' : 'Complete book handover?'),
                    content: Text(ar ? 'بعد التأكيد سيختفي الكتاب من العروض المتاحة وتبقى المحادثة محفوظة.' : 'The book will be removed from available listings and this chat will remain recorded.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(ar ? 'إتمام' : 'Complete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ZameelBookExchangeService.completeRequest(widget.requestId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.task_alt_rounded),
              label: Text(ar ? 'تم التسليم' : 'Handed over'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (phone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone_rounded, color: AppTheme.primary),
                title: Text(ar ? 'رقم صاحب الكتاب' : 'Book owner phone'),
                subtitle: SelectableText(phone),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (_, index) {
                  final message = _messages[index];
                  final mine = message['sender_id']?.toString() == me;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine ? AppTheme.primaryLight : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(message['message_text']?.toString() ?? ''),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: ar ? 'اكتب للتنسيق حول التسليم…' : 'Coordinate the handover…'))),
                    IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
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
