import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services_study_files.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

// ============================================================
// BOOKS SCREEN
// ============================================================

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  String searchQuery = '';
  String selectedFilter = 'All';
  bool showStudyFiles = false;
  bool loadingStudyFiles = false;
  List<Map<String, dynamic>> studyFiles = [];

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
    _loadStudyFiles();
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
                          color: const Color(0xFFDDF6F3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(_fileIcon(picked.extension), color: const Color(0xFF087F78), size: 32),
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
      final url = await ZameelStudyFilesService.createSignedUrl(file['storage_path'] as String);
      if (url == null) throw Exception('No file URL');
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'تعذر فتح الملف' : 'Could not open the file')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'تعذر فتح الملف: $e' : 'Could not open file: $e')));
      }
    }
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
      final title = isArabic ? book['title_ar'] : book['title_en'];
      final author = isArabic ? book['author_ar'] : book['author_en'];
      final subject = isArabic ? book['subject_ar'] : book['subject_en'];
      final type = isArabic ? book['type_ar'] : book['type_en'];

      final matchesSearch = title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          author.toLowerCase().contains(searchQuery.toLowerCase()) ||
          subject.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesFilter = selectedFilter == 'All' || type == selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

 void _addBook() {
  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  final isArabic = languageProvider.isArabic;

  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final subjectController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  String selectedType = isArabic ? 'بيع' : 'Sale';
  String selectedCondition = isArabic ? 'جيد' : 'Good';

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Directionality(
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
                      selectedType = value;
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
              onPressed: () {
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

                setState(() {
                  books.insert(0, {
                    'id': books.length + 1,
                    'title_ar': titleController.text.trim(),
                    'title_en': titleController.text.trim(),
                    'author_ar': authorController.text.trim(),
                    'author_en': authorController.text.trim(),
                    'subject_ar': subjectController.text.trim(),
                    'subject_en': subjectController.text.trim(),
                    'university_ar': 'الجامعة الأردنية',
                    'university_en': 'University of Jordan',
                    'college_ar': 'كلية تكنولوجيا المعلومات',
                    'college_en': 'Faculty of Information Technology',
                    'department_ar': 'علم الحاسوب',
                    'department_en': 'Computer Science',
                    'type_ar': isArabic ? selectedType : (selectedType == 'Sale' ? 'بيع' : selectedType),
                    'type_en': isArabic ? (selectedType == 'بيع' ? 'Sale' : selectedType) : selectedType,
                    'price': selectedType == 'بيع' || selectedType == 'Sale'
                        ? '${priceController.text.trim()} دينار'
                        : (isArabic ? selectedType : selectedType),
                    'image': null,
                    'condition_ar': isArabic ? selectedCondition : (selectedCondition == 'Excellent' ? 'ممتاز' : selectedCondition),
                    'condition_en': isArabic ? (selectedCondition == 'ممتاز' ? 'Excellent' : selectedCondition) : selectedCondition,
                    'description_ar': descriptionController.text.trim().isNotEmpty
                        ? descriptionController.text.trim()
                        : (isArabic ? 'لا يوجد وصف' : 'No description'),
                    'description_en': descriptionController.text.trim().isNotEmpty
                        ? descriptionController.text.trim()
                        : (isArabic ? 'لا يوجد وصف' : 'No description'),
                  });
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? '✅ تم إضافة الكتاب بنجاح!' : '✅ Book added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12AFA5),
                foregroundColor: Colors.white,
              ),
              child: Text(isArabic ? 'إضافة' : 'Add'),
            ),
          ],
        ),
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
                  fillColor: Colors.grey.shade100,
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
                        backgroundColor: Colors.grey.shade200,
                        selectedColor: const Color(0xFFDDF6F3),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF087F78) : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: filteredBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(isArabic ? 'لا توجد كتب' : 'No books found', style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(isArabic ? 'أضف كتاباً جديداً لتبدأ المبادلة' : 'Add a new book to start exchanging', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) => _BookCard(book: filteredBooks[index]),
                      ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Card(
                  elevation: 0,
                  color: const Color(0xFFDDF6F3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded, color: Color(0xFF087F78), size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isArabic ? 'ارفع مذكراتك وملفات المحاضرات بصيغة PDF أو Word أو PowerPoint.' : 'Upload lecture notes and study materials as PDF, Word, or PowerPoint files.',
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
                                const Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(isArabic ? 'لا توجد ملفات دراسية بعد' : 'No study files yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Text(isArabic ? 'ارفع أول ملف من زر رفع.' : 'Upload your first file using the Upload button.', style: const TextStyle(color: Colors.grey)),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFDDF6F3),
                                    child: Icon(_fileIcon(extension), color: const Color(0xFF087F78)),
                                  ),
                                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text([file['file_name']?.toString() ?? '', if (course.isNotEmpty) course, sizeLabel].where((e) => e.isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      if (action == 'open') _openStudyFile(file);
                                      if (action == 'delete') _deleteStudyFile(file);
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'open', child: Text(isArabic ? 'فتح الملف' : 'Open file')),
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
          backgroundColor: const Color(0xFF12AFA5),
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
        return Colors.blue;
      case 'إعارة':
      case 'Lend':
        return Colors.orange;
      case 'تبرع':
      case 'Donate':
        return Colors.purple;
      default:
        return Colors.grey;
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
          color: Colors.grey.shade200,
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
                  color: const Color(0xFFDDF6F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 36,
                  color: Color(0xFF087F78),
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
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
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
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if ((isArabic ? book['type_ar'] : book['type_en']) == 'بيع' || (isArabic ? book['type_ar'] : book['type_en']) == 'Sale')
                      Text(
                        book['price'],
                        style: const TextStyle(
                          color: Color(0xFF12AFA5),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
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
                  color: const Color(0xFFDDF6F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: Color(0xFF087F78),
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
                  color: Colors.grey.shade600,
                ),
              ),

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
                                  actionText = 'تبرع';
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
                                  actionText = 'Donate';
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
                                content: Text(
                                  isArabic
                                      ? 'هل أنت متأكد من رغبتك في $actionText كتاب "${book['title_ar']}" للمؤلف ${book['author_ar']}؟'
                                      : 'Are you sure you want to $actionText "${book['title_en']}" by ${book['author_en']}?',
                                  style: const TextStyle(fontSize: 15, height: 1.5),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                    },
                                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isArabic
                                                ? '✅ تم إرسال طلب $actionText بنجاح!'
                                                : '✅ $actionText request sent successfully!'
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF12AFA5),
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
                        backgroundColor: const Color(0xFF12AFA5),
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
                                : '🎁 طلب تبرع')
                            : (book['type_en'] == 'Sale'
                                ? '💰 Buy Book'
                                : book['type_en'] == 'Exchange'
                                ? '🔄 Request Exchange'
                                : book['type_en'] == 'Lend'
                                ? '📖 Request Borrow'
                                : '🎁 Request Donate'),
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final title = isArabic ? book['title_ar'] : book['title_en'];
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            final messageController = TextEditingController(
                              text: isArabic
                                  ? 'مرحباً، هل ما زال كتاب «$title» متاحاً؟'
                                  : 'Hello, is "$title" still available?',
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
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isArabic
                                            ? '✅ تم تجهيز الرسالة لصاحب الكتاب'
                                            : '✅ Message prepared for the book owner'),
                                        backgroundColor: const Color(0xFF12AFA5),
                                      ),
                                    );
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
                        color: Color(0xFF12AFA5),
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
        color: Colors.grey.shade100,
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