import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';
import 'theme/app_theme.dart';

import 'screens/comments/comments_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/books/books_screen.dart';
import 'screens/stories/stories_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/graduation/graduation_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/business/business_screen.dart';
import 'screens/campus/campus_screen.dart';
import 'screens/meet/meet_screen.dart';
import 'screens/jobs/jobs_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/ai/ai_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/search/search_screen.dart';

import 'screens/auth/welcome_screen.dart';

import 'screens/saved_posts_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/home/zameel_daily_hub.dart';
import 'screens/social/zameel_social_studio.dart';
import 'screens/polls_screen.dart';
import 'screens/private_groups_screen.dart';

import 'providers/language_provider.dart';
import 'l10n/translations.dart';
import 'widgets/video_player_widget.dart';
import 'providers/user_provider.dart';
import 'screens/profile/profile_screen.dart';
import 'config.dart';

final GlobalKey<NavigatorState> zameelNavigatorKey = GlobalKey<NavigatorState>();


Future<void> _openGraduationDeepLink(Uri uri) async {
  final nav = zameelNavigatorKey.currentState;
  if (nav == null || uri.scheme != 'zameel' || uri.host != 'graduation') return;
  final parts = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return;
  final token = uri.queryParameters['token'];
  nav.push(MaterialPageRoute(builder: (_) => GraduationBookScreen(bookId: parts.first, inviteToken: token)));
}

Future<void> _initAppLinks() async {
  final links = AppLinks();
  try {
    final initial = await links.getInitialLink();
    if (initial != null) {
      Future<void>.delayed(const Duration(milliseconds: 900), () => _openGraduationDeepLink(initial));
    }
  } catch (_) {}
  links.uriLinkStream.listen(_openGraduationDeepLink, onError: (_) {});
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: ZameelConfig.supabaseUrl,
    publishableKey: ZameelConfig.supabasePublishableKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
     ],
     child: const ZameelApp(),
   ),
  );
  await _initAppLinks();
 }

// ============================================================
// AUTH GATE
// إدارة جلسة المستخدم وتحديد الشاشة المناسبة
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _initialScreen;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initialScreen = _getInitialScreen();

    _authSubscription = Supabase.instance.client.auth
        .onAuthStateChange
        .listen((data) {
      if (!mounted) return;

      setState(() {
        _initialScreen = data.session == null
            ? Future.value(const WelcomeScreen())
            : _getInitialScreen();
      });
    });
  }

  Future<Widget> _getInitialScreen() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        return const WelcomeScreen();
      }

      final user = session.user;

      final profile = await supabase
          .from('users')
          .select('university, college, department')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return const UniversityScreen();
      }

      final universityName =
          (profile['university'] ?? '').toString().trim();
      final collegeName =
          (profile['college'] ?? '').toString().trim();
      final departmentName =
          (profile['department'] ?? '').toString().trim();

      if (universityName.isEmpty ||
          collegeName.isEmpty ||
          departmentName.isEmpty) {
        return const UniversityScreen();
      }

      final university = universities.firstWhere(
        (u) => u.name == universityName,
        orElse: () => throw Exception(
          'University not found: $universityName',
        ),
      );

      final college = university.colleges.firstWhere(
        (c) => c.name == collegeName,
        orElse: () => throw Exception(
          'College not found: $collegeName',
        ),
      );

      return HomeFeedScreen(
        university: university,
        college: college,
        department: departmentName,
      );
    } catch (e, stackTrace) {
      debugPrint('AuthGate error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return const WelcomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const WelcomeScreen();
        }

        return snapshot.data ?? const WelcomeScreen();
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

Future<bool> deleteCurrentAccount() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    await Supabase.instance.client.rpc('delete_my_account');
    await Supabase.instance.client.auth.signOut();
    return true;
  } catch (e) {
    debugPrint('Account deletion failed: $e');
    return false;
  }
}

// ============================================================
// ZAMEEL APP
// ============================================================

class ZameelApp extends StatelessWidget {
  const ZameelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
      navigatorKey: zameelNavigatorKey,
      debugShowCheckedModeBanner: false,
          title: Translations.translate(
            'app_title',
            languageProvider.currentLanguage,
          ),
          locale: languageProvider.currentLocale,
          supportedLocales: const [
            Locale('ar', ''),
            Locale('en', ''),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme.copyWith(
            scaffoldBackgroundColor: AppTheme.background,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

// ============================================================
// COLORS - Glassmorphism Theme
// ============================================================

const Color primaryColor = Color(0xFF18D4C6);
const Color primaryLight = Color(0xFFE7FCF9);
const Color secondaryColor = Color(0xFF079E93);
const Color accentColor = Color(0xFF18D4C6);
const Color redColor = Color(0xFFFF3B30);

const Color glassColor = Color(0x33FFFFFF);
const Color glassBorder = Color(0x66FFFFFF);

const Color gradientStart = Color(0xFF18D4C6);
const Color gradientEnd = Color(0xFF079E93);


// Demo content remains visible alongside real Supabase content. These entries
// are local-only and are never written into the user's real database.
const List<Map<String, dynamic>> _demoUsers = [
  {'id': '00000000-0000-4000-8000-000000000001', 'name': 'ليان الخطيب', 'gender': 'female', 'role': 'student', 'department': 'علوم الحاسوب'},
  {'id': '00000000-0000-4000-8000-000000000002', 'name': 'آدم الحوراني', 'gender': 'male', 'role': 'student', 'department': 'هندسة البرمجيات'},
  {'id': '00000000-0000-4000-8000-000000000003', 'name': 'نور العزام', 'gender': 'female', 'role': 'graduate', 'department': 'إدارة الأعمال'},
  {'id': '00000000-0000-4000-8000-000000000004', 'name': 'يوسف الشديفات', 'gender': 'male', 'role': 'student', 'department': 'الهندسة المدنية'},
  {'id': '00000000-0000-4000-8000-000000000005', 'name': 'مؤسسة زميل للطلاب', 'gender': null, 'role': 'company', 'department': 'نشاط تجاري'},
  {'id': '00000000-0000-4000-8000-000000000006', 'name': 'رؤى المومني', 'gender': 'female', 'role': 'student', 'department': 'الصيدلة'},
];

final List<Map<String, dynamic>> _demoPosts = [
  {'id': '00000000-0000-4000-8000-000000000101', 'user_id': _demoUsers[0]['id'], 'type': 'text', 'text_ar': 'خلصت اليوم أول مشروع تخرج جماعي! فخورة جدًا بالفريق 💚', 'text_en': 'Finished our first capstone group project today! Proud of the team 💚', 'likes_count': 34, 'comments_count': 5, 'shares_count': 2, 'created_at': '2026-09-05T12:40:00Z', 'users': _demoUsers[0], 'is_demo': true},
  {'id': '00000000-0000-4000-8000-000000000102', 'user_id': _demoUsers[1]['id'], 'type': 'text', 'text_ar': 'هل يوجد زملاء مهتمون بدراسة الخوارزميات بعد المحاضرة؟ 📚', 'text_en': 'Anyone interested in studying algorithms after class? 📚', 'likes_count': 19, 'comments_count': 7, 'shares_count': 1, 'created_at': '2026-09-05T12:05:00Z', 'users': _demoUsers[1], 'is_demo': true},
  {'id': '00000000-0000-4000-8000-000000000103', 'user_id': _demoUsers[2]['id'], 'type': 'text', 'text_ar': 'ذكريات التخرج لا تنتهي… الله يكتب لكل زميل طريقًا جميلًا 🌴', 'text_en': 'Graduation memories never end… wishing every Zameel a beautiful journey 🌴', 'likes_count': 51, 'comments_count': 11, 'shares_count': 4, 'created_at': '2026-09-05T11:25:00Z', 'users': _demoUsers[2], 'is_demo': true},
  {'id': '00000000-0000-4000-8000-000000000104', 'user_id': _demoUsers[3]['id'], 'type': 'text', 'text_ar': 'رفعت ملخص مادة المنشآت، ومن يحتاجه يكتب لي.', 'text_en': 'I uploaded a structures summary. Message me if you need it.', 'likes_count': 27, 'comments_count': 3, 'shares_count': 3, 'created_at': '2026-09-05T10:50:00Z', 'users': _demoUsers[3], 'is_demo': true},
  {'id': '00000000-0000-4000-8000-000000000105', 'user_id': _demoUsers[4]['id'], 'type': 'text', 'text_ar': 'إعلان تجاري: خصم خاص لطلاب الجامعات على طباعة مشاريع التخرج هذا الأسبوع 🖨️', 'text_en': 'Business announcement: special university-student discount on graduation printing this week 🖨️', 'likes_count': 72, 'comments_count': 9, 'shares_count': 12, 'created_at': '2026-09-05T10:10:00Z', 'users': _demoUsers[4], 'is_demo': true},
  {'id': '00000000-0000-4000-8000-000000000106', 'user_id': _demoUsers[5]['id'], 'type': 'text', 'text_ar': 'نصيحة سريعة: خذوا نسخة احتياطية من ملفاتكم قبل أسبوع المشاريع النهائي 💾', 'text_en': 'Quick tip: back up your files before final project week 💾', 'likes_count': 23, 'comments_count': 4, 'shares_count': 2, 'created_at': '2026-09-05T09:35:00Z', 'users': _demoUsers[5], 'is_demo': true},
];

// ============================================================
// Glassmorphism Container Widget
// ============================================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x33FFFFFF),
            Color(0x1AFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0x66FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================
// دالة الترجمة الشاملة
// ============================================================

String translateText(String arabicText, String lang) {
  if (lang == 'en') {
    const englishTranslations = {
      // الجامعات
      'الجامعة الأردنية': 'University of Jordan',
      'جامعة العلوم والتكنولوجيا الأردنية':
          'Jordan University of Science and Technology',
      'جامعة اليرموك': 'Yarmouk University',
      'الجامعة الهاشمية': 'Hashemite University',
      'جامعة مؤتة': 'Mutah University',
      'جامعة آل البيت': 'Al al-Bayt University',
      'جامعة البلقاء التطبيقية': 'Al-Balqa Applied University',
      'جامعة الحسين بن طلال': 'Al-Hussein Bin Talal University',
      'جامعة الطفيلة التقنية': 'Tafila Technical University',
      'الجامعة الألمانية الأردنية': 'German-Jordanian University',
      'جامعة الأميرة سمية للتكنولوجيا':
          'Princess Sumaya University for Technology',
      'جامعة عمان الأهلية': 'Amman Ahliyya University',
      'جامعة الزيتونة الأردنية': 'Al-Zaytoonah University of Jordan',
      'جامعة العلوم التطبيقية الخاصة':
          'Applied Science Private University',
      'جامعة فيلادلفيا': 'Philadelphia University',
      'جامعة الشرق الأوسط': 'Middle East University',
      'جامعة عمان العربية': 'Amman Arab University',
      'جامعة الزرقاء': 'Zarqa University',
      'جامعة جدارا': 'Jadara University',
      'جامعة إربد الأهلية': 'Irbid National University',
      'جامعة جرش': 'Jerash University',
      'جامعة البترا': 'Petra University',
      'جامعة الإسراء': 'Al-Isra University',
      'جامعة العلوم الإسلامية العالمية':
          'World Islamic Sciences and Education University',
      'الجامعة العربية المفتوحة': 'Arab Open University',
      'جامعة عجلون الوطنية': 'Ajloun National University',
      'الجامعة الأمريكية في مادبا': 'American University of Madaba',
      'جامعة العقبة للتكنولوجيا': 'Aqaba University of Technology',

      // الكليات
      'كلية الطب': 'Faculty of Medicine',
      'كلية طب الأسنان': 'Faculty of Dentistry',
      'كلية الصيدلة': 'Faculty of Pharmacy',
      'كلية التمريض': 'Faculty of Nursing',
      'كلية العلوم الطبية المساندة': 'Faculty of Allied Medical Sciences',
      'كلية الطب البيطري': 'Faculty of Veterinary Medicine',
      'كلية الهندسة': 'Faculty of Engineering',
      'كلية الهندسة المدنية': 'Faculty of Civil Engineering',
      'كلية الهندسة المعمارية': 'Faculty of Architecture',
      'كلية الهندسة الكهربائية': 'Faculty of Electrical Engineering',
      'كلية الهندسة الميكانيكية': 'Faculty of Mechanical Engineering',
      'كلية الهندسة الصناعية': 'Faculty of Industrial Engineering',
      'كلية هندسة البرمجيات': 'Faculty of Software Engineering',
      'كلية هندسة الحاسوب': 'Faculty of Computer Engineering',
      'كلية هندسة الطيران': 'Faculty of Aerospace Engineering',
      'كلية هندسة الطاقة المتجددة': 'Faculty of Renewable Energy Engineering',
      'كلية تكنولوجيا المعلومات': 'Faculty of Information Technology',
      'كلية علوم الحاسوب': 'Faculty of Computer Science',
      'كلية الأمن السيبراني': 'Faculty of Cybersecurity',
      'كلية الذكاء الاصطناعي': 'Faculty of Artificial Intelligence',
      'كلية علم البيانات': 'Faculty of Data Science',
      'كلية الأعمال': 'Faculty of Business',
      'كلية إدارة الأعمال': 'Faculty of Business Administration',
      'كلية المحاسبة': 'Faculty of Accounting',
      'كلية التسويق': 'Faculty of Marketing',
      'كلية التمويل': 'Faculty of Finance',
      'كلية نظم المعلومات الإدارية':
          'Faculty of Management Information Systems',
      'كلية إدارة الخدمات اللوجستية':
          'Faculty of Logistics Management',
      'كلية اللغات': 'Faculty of Languages',
      'كلية اللغة العربية وآدابها':
          'Faculty of Arabic Language and Literature',
      'كلية اللغة الإنجليزية': 'Faculty of English Language',
      'كلية اللغات الحديثة': 'Faculty of Modern Languages',
      'كلية التربية': 'Faculty of Education',
      'كلية الإعلام': 'Faculty of Media',
      'كلية الآثار والسياحة': 'Faculty of Archaeology and Tourism',
      'كلية القانون': 'Faculty of Law',
      'كلية الشريعة الإسلامية': 'Faculty of Islamic Sharia',

      // التخصصات
      'الطب العام': 'General Medicine',
      'الجراحة العامة': 'General Surgery',
      'جراحة الفم والأسنان': 'Oral and Dental Surgery',
      'العلوم الصيدلانية': 'Pharmaceutical Sciences',
      'الصيدلة السريرية': 'Clinical Pharmacy',
      'التمريض العام': 'General Nursing',
      'التمريض الصحي': 'Health Nursing',
      'المختبرات الطبية': 'Medical Laboratories',
      'الأشعة': 'Radiology',
      'العلاج الطبيعي': 'Physical Therapy',
      'الطب البيطري': 'Veterinary Medicine',
      'الهندسة المدنية': 'Civil Engineering',
      'هندسة الإنشاءات': 'Structural Engineering',
      'هندسة النقل': 'Transportation Engineering',
      'التصميم الداخلي': 'Interior Design',
      'هندسة القدرة': 'Power Engineering',
      'هندسة الاتصالات': 'Telecommunications Engineering',
      'هندسة الإلكترونيات': 'Electronics Engineering',
      'هندسة التصميم الميكانيكي': 'Mechanical Design Engineering',
      'هندسة الطاقة': 'Energy Engineering',
      'هندسة التصنيع': 'Manufacturing Engineering',
      'هندسة الإنتاج': 'Production Engineering',
      'هندسة الجودة': 'Quality Engineering',
      'تطوير البرمجيات': 'Software Development',
      'تحليل النظم': 'Systems Analysis',
      'هندسة الشبكات': 'Network Engineering',
      'الأنظمة المضمنة': 'Embedded Systems',
      'الطاقة الشمسية': 'Solar Energy',
      'طاقة الرياح': 'Wind Energy',
      'البرمجة': 'Programming',
      'الخوارزميات': 'Algorithms',
      'قواعد البيانات': 'Databases',
      'شبكات الحاسوب': 'Computer Networks',
      'أمن المعلومات': 'Information Security',
      'تعلم الآلة': 'Machine Learning',
      'معالجة اللغة الطبيعية': 'Natural Language Processing',
      'الأمن السيبراني': 'Cybersecurity',
      'أمن الشبكات': 'Network Security',
      'الأمن الرقمي': 'Digital Security',
      'تحليل البيانات': 'Data Analysis',
      'ذكاء الأعمال': 'Business Intelligence',
      'إدارة الموارد البشرية': 'Human Resource Management',
      'التدقيق': 'Auditing',
      'التسويق الرقمي': 'Digital Marketing',
      'إدارة العلامات التجارية': 'Brand Management',
      'الأسواق المالية': 'Financial Markets',
      'المصرفية': 'Banking',
      'نظم دعم القرار': 'Decision Support Systems',
      'سلسلة التوريد': 'Supply Chain',
      'النقد الأدبي': 'Literary Criticism',
      'البلاغة': 'Rhetoric',
      'اللغويات': 'Linguistics',
      'الأدب الإنجليزي': 'English Literature',
      'الترجمة': 'Translation',
      'اللغويات التطبيقية': 'Applied Linguistics',
      'المناهج': 'Curricula',
      'الإدارة التربوية': 'Educational Administration',
      'علم النفس': 'Psychology',
      'الصحافة': 'Journalism',
      'الإذاعة والتلفزيون': 'Radio and Television',
      'العلاقات العامة': 'Public Relations',
      'إدارة المواقع الأثرية': 'Archaeological Site Management',
      'السياحة': 'Tourism',
      'القانون العام': 'Public Law',
      'القانون الخاص': 'Private Law',
      'الفقه الإسلامي': 'Islamic Jurisprudence',
      'أصول الدين': 'Usul al-Din',
    };

    return englishTranslations[arabicText] ?? arabicText;
  }
  return arabicText;
}

// ============================================================
// UNIVERSITY MODELS - جميع الجامعات الأردنية
// ============================================================

class University {
  final String name;
  final String type;
  final String city;
  final List<College> colleges;

  const University({
    required this.name,
    required this.type,
    required this.city,
    required this.colleges,
  });
}

class College {
  final String name;
  final List<String> departments;

  const College({
    required this.name,
    required this.departments,
  });
}

// ============================================================
// ✅ جميع الجامعات الأردنية (حكومية + خاصة)
// ============================================================

const List<University> universities = [
  // ============================================================
  // الجامعات الحكومية
  // ============================================================

  // 1. الجامعة الأردنية
  University(
    name: 'الجامعة الأردنية',
    type: 'حكومية',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
          'الجراحة العامة',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
          'الصيدلة السريرية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
          'التمريض الصحي',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'الهندسة الصناعية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
          'نظم المعلومات الإدارية',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
          'اللغات الحديثة',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
      College(
        name: 'كلية التربية',
        departments: [
          'المناهج',
          'الإدارة التربوية',
          'علم النفس',
        ],
      ),
      College(
        name: 'كلية الإعلام',
        departments: [
          'الصحافة',
          'الإذاعة والتلفزيون',
          'العلاقات العامة',
        ],
      ),
      College(
        name: 'كلية الآثار والسياحة',
        departments: [
          'إدارة المواقع الأثرية',
          'السياحة',
        ],
      ),
    ],
  ),

  // 2. جامعة العلوم والتكنولوجيا الأردنية
  University(
    name: 'جامعة العلوم والتكنولوجيا الأردنية',
    type: 'حكومية',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
          'الجراحة العامة',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
          'الصيدلة السريرية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية العلوم الطبية المساندة',
        departments: [
          'المختبرات الطبية',
          'الأشعة',
          'العلاج الطبيعي',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الحاسوب',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
          'علم البيانات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
    ],
  ),

  // 3. جامعة اليرموك
  University(
    name: 'جامعة اليرموك',
    type: 'حكومية',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'الهندسة الصناعية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
      College(
        name: 'كلية التربية',
        departments: [
          'المناهج',
          'الإدارة التربوية',
          'علم النفس',
        ],
      ),
      College(
        name: 'كلية الإعلام',
        departments: [
          'الصحافة',
          'الإذاعة والتلفزيون',
        ],
      ),
      College(
        name: 'كلية الآثار والسياحة',
        departments: [
          'إدارة المواقع الأثرية',
          'السياحة',
        ],
      ),
    ],
  ),

  // 4. الجامعة الهاشمية
  University(
    name: 'الجامعة الهاشمية',
    type: 'حكومية',
    city: 'الزرقاء',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 5. جامعة مؤتة
  University(
    name: 'جامعة مؤتة',
    type: 'حكومية',
    city: 'الكرك',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
    ],
  ),

  // 6. جامعة آل البيت
  University(
    name: 'جامعة آل البيت',
    type: 'حكومية',
    city: 'المفرق',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 7. جامعة البلقاء التطبيقية
  University(
    name: 'جامعة البلقاء التطبيقية',
    type: 'حكومية',
    city: 'السلط',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 8. جامعة الحسين بن طلال
  University(
    name: 'جامعة الحسين بن طلال',
    type: 'حكومية',
    city: 'معان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
    ],
  ),

  // 9. جامعة الطفيلة التقنية
  University(
    name: 'جامعة الطفيلة التقنية',
    type: 'حكومية',
    city: 'الطفيلة',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
    ],
  ),

  // 10. الجامعة الألمانية الأردنية
  University(
    name: 'الجامعة الألمانية الأردنية',
    type: 'حكومية',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الحاسوب',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة الإنجليزية',
          'اللغات الحديثة',
        ],
      ),
    ],
  ),

  // 11. جامعة الأميرة سمية للتكنولوجيا
  University(
    name: 'جامعة الأميرة سمية للتكنولوجيا',
    type: 'حكومية',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الحاسوب',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
          'علم البيانات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التمويل',
        ],
      ),
    ],
  ),

  // ============================================================
  // الجامعات الخاصة
  // ============================================================

  // 12. جامعة عمان الأهلية
  University(
    name: 'جامعة عمان الأهلية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 13. جامعة الزيتونة الأردنية
  University(
    name: 'جامعة الزيتونة الأردنية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 14. جامعة العلوم التطبيقية الخاصة
  University(
    name: 'جامعة العلوم التطبيقية الخاصة',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 15. جامعة فيلادلفيا
  University(
    name: 'جامعة فيلادلفيا',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 16. جامعة الشرق الأوسط
  University(
    name: 'جامعة الشرق الأوسط',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 17. جامعة عمان العربية
  University(
    name: 'جامعة عمان العربية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 18. جامعة الزرقاء
  University(
    name: 'جامعة الزرقاء',
    type: 'خاصة',
    city: 'الزرقاء',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 19. جامعة جدارا
  University(
    name: 'جامعة جدارا',
    type: 'خاصة',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 20. جامعة إربد الأهلية
  University(
    name: 'جامعة إربد الأهلية',
    type: 'خاصة',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 21. جامعة جرش
  University(
    name: 'جامعة جرش',
    type: 'خاصة',
    city: 'جرش',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 22. جامعة البترا
  University(
    name: 'جامعة البترا',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 23. جامعة الإسراء
  University(
    name: 'جامعة الإسراء',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 24. جامعة العلوم الإسلامية العالمية
  University(
    name: 'جامعة العلوم الإسلامية العالمية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 25. الجامعة العربية المفتوحة
  University(
    name: 'الجامعة العربية المفتوحة',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 26. جامعة عجلون الوطنية
  University(
    name: 'جامعة عجلون الوطنية',
    type: 'خاصة',
    city: 'عجلون',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 27. الجامعة الأمريكية في مادبا
  University(
    name: 'الجامعة الأمريكية في مادبا',
    type: 'خاصة',
    city: 'مادبا',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 28. جامعة العقبة للتكنولوجيا
  University(
    name: 'جامعة العقبة للتكنولوجيا',
    type: 'خاصة',
    city: 'العقبة',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الطاقة المتجددة',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التمويل',
        ],
      ),
    ],
  ),
];

// ============================================================
// UNIVERSITY SCREEN (مع زر رجوع)
// ============================================================

class UniversityScreen extends StatefulWidget {
  const UniversityScreen({super.key});

  @override
  State<UniversityScreen> createState() => _UniversityScreenState();
}

class _UniversityScreenState extends State<UniversityScreen> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    final filtered = universities.where((u) {
      return u.name.contains(search) || u.city.contains(search);
    }).toList();

    final government = filtered
        .where((u) => u.type == 'حكومية')
        .toList();

    final private = filtered
        .where((u) => u.type == 'خاصة')
        .toList();

    return Directionality(
      textDirection: languageProvider.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            Translations.translate(
              'university_title',
              languageProvider.currentLanguage,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: Translations.translate(
                      'university_search',
                      languageProvider.currentLanguage,
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor: const Color(0x33FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              if (government.isNotEmpty) ...[
                Text(
                  Translations.translate(
                    'university_government',
                    languageProvider.currentLanguage,
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...government.map(
                  (u) => _UniversityCard(
                    university: u,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (private.isNotEmpty) ...[
                Text(
                  Translations.translate(
                    'university_private',
                    languageProvider.currentLanguage,
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...private.map(
                  (u) => _UniversityCard(
                    university: u,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UniversityCard extends StatelessWidget {
  final University university;

  const _UniversityCard({
    required this.university,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.white.withAlpha(51),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
          ),
        ),
        title: Text(
          translateText(
            university.name,
            languageProvider.currentLanguage,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          isArabic
              ? '📍 ${university.city} - ${university.type}'
              : '📍 ${university.city} - ${university.type}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.white70,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollegeScreen(
                university: university,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// COLLEGE SCREEN (مع زر رجوع)
// ============================================================

class CollegeScreen extends StatelessWidget {
  final University university;

  const CollegeScreen({
    super.key,
    required this.university,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            Translations.translate(
              'college_title',
              languageProvider.currentLanguage,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                child: Text(
                  translateText(
                    university.name,
                    languageProvider.currentLanguage,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...university.colleges.map(
                (college) => GlassContainer(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withAlpha(51),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      translateText(
                        college.name,
                        languageProvider.currentLanguage,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DepartmentScreen(
                            university: university,
                            college: college,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DEPARTMENT SCREEN (مع زر رجوع)
// ============================================================

class DepartmentScreen extends StatelessWidget {
  final University university;
  final College college;

  const DepartmentScreen({
    super.key,
    required this.university,
    required this.college,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            Translations.translate(
              'department_title',
              languageProvider.currentLanguage,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                child: Text(
                  translateText(
                    college.name,
                    languageProvider.currentLanguage,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...college.departments.map(
                (department) => GlassContainer(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withAlpha(51),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      translateText(
                        department,
                        languageProvider.currentLanguage,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),

                    // حفظ الجامعة والكلية والتخصص ثم الانتقال للرئيسية
                    onTap: () async {
                      final user =
                          Supabase.instance.client.auth.currentUser;

                      if (user == null) {
                        return;
                      }

                      try {
                        await Supabase.instance.client
                            .from('users')
                            .update({
                          'university': university.name,
                          'college': college.name,
                          'department': department,
                        }).eq('id', user.id);

                        if (!context.mounted) return;

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeFeedScreen(
                              university: university,
                              college: college,
                              department: department,
                            ),
                          ),
                        );
                      } catch (e) {
                        debugPrint(
                          'Error saving university/college/department: $e',
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'حدث خطأ أثناء حفظ بيانات الجامعة والتخصص: $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME FEED SCREEN (معدل بالكامل)
// ============================================================

class HomeFeedScreen extends StatefulWidget {
  final University university;
  final College college;
  final String department;

  const HomeFeedScreen({
    super.key,
    required this.university,
    required this.college,
    required this.department,
  });

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  int currentIndex = 0;
  File? profileImage;
  Uint8List? profileImageBytes;
  String? profileImageUrl;
  final ImagePicker picker = ImagePicker();
  bool isAdmin = false;
  List<Map<String, dynamic>> savedPosts = [];
  List<Map<String, dynamic>> posts = [];
  bool _isLoading = true;
  String _postAudience = 'public';
  int _unreadNotifications = 0;

  @override
void initState() {
  super.initState();
  _createUserIfNotExists();
  _loadCurrentProfileImage();
  _loadPosts();
  _loadUnreadNotifications();
}

String _calendarKey() {
  final n = widget.university.name.toLowerCase();
  if (n.contains('يرموك') || n.contains('yarmouk')) return 'yu';
  if (n.contains('علوم') || n.contains('science and technology') || n.contains('just')) return 'just';
  if (n.contains('هاشمية') || n.contains('hashemite')) return 'hu';
  return 'ju';
}

Future<void> _loadUnreadNotifications() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    final rows = await Supabase.instance.client.from('notifications').select('id').eq('user_id', user.id).eq('is_read', false);
    if (mounted) setState(() => _unreadNotifications = rows.length);
  } catch (_) {}
}

Future<void> _loadCurrentProfileImage() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('profile_image')
        .eq('id', user.id)
        .maybeSingle();
    final url = row?['profile_image']?.toString();
    if (!mounted) return;
    setState(() => profileImageUrl = (url == null || url.isEmpty) ? null : url);
  } catch (_) {}
}

  // ============================================================
  // جلب المنشورات من Supabase
  // ============================================================

 Future<void> _loadPosts() async {
  if (mounted) setState(() => _isLoading = true);
  try {
    final db = Supabase.instance.client;
    final response = await db
        .from('posts')
        .select('*, users(name, email, profile_image, gender, role)')
        .order('created_at', ascending: false);

    final loaded = <Map<String, dynamic>>[
      ..._demoPosts.map((p) => Map<String, dynamic>.from(p)),
      ...List<Map<String, dynamic>>.from(response),
    ];
    final user = db.auth.currentUser;

    if (user != null && loaded.isNotEmpty) {
      try {
        final likes = await db
            .from('likes')
            .select('post_id')
            .eq('user_id', user.id);
        final likedIds = likes.map((r) => r['post_id'].toString()).toSet();

        final saved = await db
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', user.id);
        final savedIds = saved.map((r) => r['post_id'].toString()).toSet();

        for (final post in loaded) {
          final id = post['id']?.toString();
          post['liked'] = id != null && likedIds.contains(id);
          post['isSaved'] = id != null && savedIds.contains(id);
          post['shares'] = (post['shares_count'] ?? 0);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      posts = _diversifyFeed(loaded);
      _isLoading = false;
    });
  } catch (e) {
    debugPrint('Error loading posts: $e');
    if (mounted) setState(() => _isLoading = false);
  }
}

List<Map<String, dynamic>> _diversifyFeed(
    List<Map<String, dynamic>> source) {
  final women = <Map<String, dynamic>>[];
  final men = <Map<String, dynamic>>[];
  final business = <Map<String, dynamic>>[];
  final other = <Map<String, dynamic>>[];

  for (final post in source) {
    final owner = post['users'];
    final role = owner is Map
        ? owner['role']?.toString().toLowerCase()
        : null;
    final gender = owner is Map
        ? owner['gender']?.toString().toLowerCase()
        : null;

    final businessRoles = <String>{'business','company','merchant','store','organization','نشاط تجاري','شركة','مؤسسة'};
    final femaleValues = <String>{'female','woman','women','أنثى','انثى'};
    final maleValues = <String>{'male','man','men','ذكر'};
    if (businessRoles.contains(role)) {
      business.add(post);
    } else if (femaleValues.contains(gender)) {
      women.add(post);
    } else if (maleValues.contains(gender)) {
      men.add(post);
    } else {
      other.add(post);
    }
  }

  final result = <Map<String, dynamic>>[];
  var wi = 0;
  var mi = 0;
  var bi = 0;
  var oi = 0;

  void addIfAvailable(List<Map<String, dynamic>> list, int index) {
    if (index < list.length) result.add(list[index]);
  }

  while (result.length < source.length) {
    for (var i = 0; i < 3 && result.length < source.length; i++) {
      if (wi < women.length) {
        addIfAvailable(women, wi++);
      }
    }

    if (result.length < source.length && mi < men.length) {
      addIfAvailable(men, mi++);
    }

    if (result.length < source.length && bi < business.length) {
      addIfAvailable(business, bi++);
    }

    // Unknown/other is used to keep the feed full without inventing
    // gender or business classification.
    if (result.length < source.length && oi < other.length) {
      addIfAvailable(other, oi++);
    }

    if (wi >= women.length &&
        mi >= men.length &&
        bi >= business.length &&
        oi >= other.length) {
      break;
    }

    // If a requested bucket is exhausted, continue from the remaining
    // buckets so no eligible post is silently discarded.
    if (result.length < source.length &&
        wi >= women.length &&
        oi >= other.length) {
      while (mi < men.length) addIfAvailable(men, mi++);
      while (bi < business.length) addIfAvailable(business, bi++);
    }
    if (result.length < source.length &&
        mi >= men.length &&
        oi >= other.length) {
      while (wi < women.length) addIfAvailable(women, wi++);
      while (bi < business.length) addIfAvailable(business, bi++);
    }
    if (result.length < source.length &&
        bi >= business.length &&
        oi >= other.length) {
      while (wi < women.length) addIfAvailable(women, wi++);
      while (mi < men.length) addIfAvailable(men, mi++);
    }
  }

  return result;
}

Future<void> _createUserIfNotExists() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('users')
        .select('*')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      final newUser = {
        'id': user.id,
        'name': user.userMetadata?['name'] ?? 'مستخدم',
        'email': user.email,
        'university': '',
        'college': '',
        'department': '',
        'profile_image': null,
        'account_privacy': 'public',
        'default_post_audience': 'public',
        'allow_messages': true,
        'allow_calls': true,
        'notifications_enabled': true,
        'gender': null,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('users')
          .insert(newUser);

      print('✅ تم إنشاء المستخدم في قاعدة البيانات');
    } else {
      final audience = response['default_post_audience']?.toString();
      if (audience == 'public' || audience == 'friends' || audience == 'private') {
        _postAudience = audience!;
      }
      print('✅ المستخدم موجود بالفعل');
    }
  } catch (e) {
    print('❌ خطأ في إنشاء المستخدم: $e');
  }
}

  // ============================================================
  // إنشاء منشور جديد في Supabase
  // ============================================================

  Future<void> _createPost(String text, {String? audience}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ الرجاء تسجيل الدخول',
            ),
          ),
        );
        return;
      }

      final newPost = {
        'user_id': user.id,
        'type': 'text',
        'text_ar': text,
        'text_en': text,
        'likes_count': 0,
        'comments_count': 0,
        'audience': audience ?? _postAudience,
      };

      final response = await Supabase.instance.client
          .from('posts')
          .insert(newPost)
          .select()
          .single();

      if (response != null) {
        setState(() {
          posts.insert(0, {
            ...response,
            'users': {
              'name': user.userMetadata?['name'] ?? 'مستخدم',
              'email': user.email,
            },
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم نشر المنشور!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل النشر: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // حذف المنشور (مع صلاحيات)
  // ============================================================

  Future<void> _deletePost(Map<String, dynamic> post) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ الرجاء تسجيل الدخول'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // التحقق من الصلاحية: المدير أو صاحب المنشور
      final isOwner = post['user_id'] == user.id;
      final isAdminUser = isAdmin;

      if (!isOwner && !isAdminUser) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ ليس لديك صلاحية لحذف هذا المنشور'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // حذف المنشور من قاعدة البيانات
      await Supabase.instance.client
          .from('posts')
          .delete()
          .eq('id', post['id']);

      // حذف المنشور من القائمة المحلية
      setState(() {
        posts.removeWhere((p) => p['id'] == post['id']);
        savedPosts.removeWhere((p) => p['id'] == post['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ تم حذف المنشور بنجاح'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل الحذف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // نافذة تأكيد الحذف (مع إظهار اسم صاحب المنشور)
  // ============================================================

  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> post,
  ) {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = post['user_id'] == user?.id;
    final isAdminUser = isAdmin;

    // إذا كان المستخدم ليس صاحب المنشور وليس مديرًا، لا يعرض زر الحذف
    if (!isOwner && !isAdminUser) {
      return;
    }

    final String ownerName = post['users']?['name'] ?? 'مستخدم';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              isArabic ? '🗑️ حذف المنشور' : '🗑️ Delete Post',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              isArabic
                  ? 'هل أنت متأكد من رغبتك في حذف هذا المنشور؟\n\n'
                    '👤 صاحب المنشور: $ownerName'
                  : 'Are you sure you want to delete this post?\n\n'
                    '👤 Post owner: $ownerName',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  isArabic ? 'إلغاء' : 'Cancel',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _deletePost(post);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isArabic ? 'تأكيد الحذف' : 'Confirm Delete',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // الإعجاب بمنشور
  // ============================================================

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= posts.length) return;
    final post = posts[index];
    final user = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (user == null || postId == null) return;

    final wasLiked = post['liked'] == true;
    final oldCount = ((post['likes_count'] ?? 0) as num).toInt();

    // Optimistic UI: the button responds immediately.
    setState(() {
      post['liked'] = !wasLiked;
      post['likes_count'] = wasLiked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
    });

    if (post['is_demo'] == true) return;

    try {
      final db = Supabase.instance.client;
      if (wasLiked) {
        await db.from('likes').delete().eq('user_id', user.id).eq('post_id', postId);
      } else {
        await db.from('likes').upsert({'user_id': user.id, 'post_id': postId});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        post['liked'] = wasLiked;
        post['likes_count'] = oldCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الإعجاب: $e')),
      );
    }
  }

  // ============================================================
  // حفظ منشور
  // ============================================================

  Future<void> _toggleSavePost(int index) async {
    final post = posts[index];
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final isSaved = post['isSaved'] ?? false;

      if (isSaved) {
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', post['id']);

        setState(() {
          posts[index]['isSaved'] = false;
          savedPosts.removeWhere(
            (p) => p['id'] == post['id'],
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم إلغاء الحفظ'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        await Supabase.instance.client
            .from('saved_posts')
            .insert({
              'user_id': user.id,
              'post_id': post['id'],
            });

        setState(() {
          posts[index]['isSaved'] = true;
          savedPosts.insert(0, post);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ المنشور'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error toggling save: $e');
    }
  }

  Future<void> pickProfileImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        profileImageBytes = bytes;
        // Keep the File for native platforms; Web uses profileImageBytes.
        profileImage = kIsWeb ? null : File(image.path);
      });
    }
  }

  void toggleLike(int index) {
    _toggleLike(index);
  }

  Future<void> _pickImage() async {
      final audience = await _choosePostAudience();
      if (audience == null) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري رفع الصورة...'),
        ),
      );

      final bytes = await image.readAsBytes();

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final storagePath = '${user.id}/images/$fileName';

      await Supabase.instance.client.storage
          .from('posts')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: false,
            ),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('posts')
          .getPublicUrl(storagePath);

      final response = await Supabase.instance.client
          .from('posts')
          .insert({
            'user_id': user.id,
            'type': 'image',
            'text_ar': '',
            'text_en': '',
            'image_url': imageUrl,
            'video_url': null,
            'likes_count': 0,
            'comments_count': 0,
            'audience': audience,
          })
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        posts.insert(0, {
          ...response,
          'name_ar': user.userMetadata?['name'] ?? 'مستخدم',
          'name_en': user.userMetadata?['name'] ?? 'User',
          'department_ar': widget.department,
          'department_en': widget.department,
          'likes': 0,
          'comments': 0,
          'liked': false,
          'isSaved': false,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الصورة بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('IMAGE UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفع الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
      final audience = await _choosePostAudience();
      if (audience == null) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري رفع الفيديو...'),
        ),
      );

      final bytes = await video.readAsBytes();

      final extension = video.name.contains('.')
          ? video.name.split('.').last.toLowerCase()
          : 'mp4';

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final storagePath = '${user.id}/videos/$fileName';

      String contentType = 'video/mp4';

      if (extension == 'webm') {
        contentType = 'video/webm';
      } else if (extension == 'mov') {
        contentType = 'video/quicktime';
      } else if (extension == 'm4v') {
        contentType = 'video/x-m4v';
      }

      await Supabase.instance.client.storage
          .from('posts')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      final videoUrl = Supabase.instance.client.storage
          .from('posts')
          .getPublicUrl(storagePath);

      final response = await Supabase.instance.client
          .from('posts')
          .insert({
            'user_id': user.id,
            'type': 'video',
            'text_ar': '',
            'text_en': '',
            'image_url': null,
            'video_url': videoUrl,
            'likes_count': 0,
            'comments_count': 0,
            'audience': audience,
          })
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        posts.insert(0, {
          ...response,
          'name_ar': user.userMetadata?['name'] ?? 'مستخدم',
          'name_en': user.userMetadata?['name'] ?? 'User',
          'department_ar': widget.department,
          'department_en': widget.department,
          'likes': 0,
          'comments': 0,
          'liked': false,
          'isSaved': false,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الفيديو بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('VIDEO UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفع الفيديو: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _choosePostAudience() async {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.public_rounded), title: Text(ar ? 'عامة' : 'Public'), subtitle: Text(ar ? 'يراها جميع مستخدمي زميل' : 'Visible to all Zameel users'), onTap: () => Navigator.pop(ctx, 'public')),
        ListTile(leading: const Icon(Icons.groups_rounded), title: Text(ar ? 'للزملاء' : 'Colleagues'), subtitle: Text(ar ? 'للأشخاص الذين تتابعهم' : 'Visible to people you follow'), onTap: () => Navigator.pop(ctx, 'friends')),
        ListTile(leading: const Icon(Icons.lock_rounded), title: Text(ar ? 'لي فقط' : 'Only me'), subtitle: Text(ar ? 'خاص بك فقط' : 'Private to you'), onTap: () => Navigator.pop(ctx, 'private')),
      ])),
    );
  }

  void createPost() {
    final controller = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: languageProvider.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: Colors.white.withAlpha(230),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              Translations.translate(
                'create_post_title',
                languageProvider.currentLanguage,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              StatefulBuilder(builder: (context, setAudience) => DropdownButtonFormField<String>(
                value: _postAudience,
                decoration: InputDecoration(labelText: languageProvider.isArabic ? 'من يمكنه رؤية المنشور؟' : 'Who can see this post?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: [
                  DropdownMenuItem(value: 'public', child: Text(languageProvider.isArabic ? '🌍 عامة' : '🌍 Public')),
                  DropdownMenuItem(value: 'friends', child: Text(languageProvider.isArabic ? '👥 الزملاء' : '👥 Colleagues')),
                  DropdownMenuItem(value: 'private', child: Text(languageProvider.isArabic ? '🔒 لي فقط' : '🔒 Only me')),
                ],
                onChanged: (v) { if (v != null) { _postAudience = v; setAudience(() {}); } },
              )),
              const SizedBox(height: 10),
              TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: Translations.translate(
                  'create_post_hint',
                  languageProvider.currentLanguage,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  Translations.translate(
                    'create_post_cancel',
                    languageProvider.currentLanguage,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;

                  Navigator.pop(dialogContext);
                  await _createPost(
                    controller.text.trim(),
                    audience: _postAudience,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  Translations.translate(
                    'create_post_publish',
                    languageProvider.currentLanguage,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientStart,
              gradientEnd,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Image.asset('assets/branding/zameel_mark.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Zameel • زميل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isArabic ? 'منصة الطلاب الجامعيين' : 'University Platform',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.home_rounded,
              title: isArabic ? 'الرئيسية' : 'Home',
              onTap: () {
                setState(() {
                  currentIndex = 0;
                });
                Navigator.pop(context);
              },
              isSelected: currentIndex == 0,
            ),
            _DrawerItem(
              icon: Icons.menu_book_rounded,
              title: isArabic ? 'الكتب' : 'Books',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BooksScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.chat_bubble_rounded,
              title: isArabic ? 'الدردشة' : 'Chat',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.people_rounded,
              title: isArabic ? 'الأصدقاء' : 'Friends',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FriendsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.map_rounded,
              title: isArabic ? 'الحرم الجامعي' : 'Campus',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CampusScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.video_call_rounded,
              title: isArabic ? 'اجتمع بالزملاء' : 'Meet',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.work_rounded,
              title: isArabic ? 'وظائف' : 'Jobs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JobsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.calendar_month_rounded,
              title: isArabic ? 'تقويم' : 'Calendar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.poll_rounded,
              title: isArabic ? 'استطلاعات' : 'Polls',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PollsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.group_rounded,
              title: isArabic ? 'مجموعات' : 'Groups',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GroupsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.auto_awesome_rounded,
              title: isArabic ? 'زميل AI' : 'Zameel AI',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AIScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.business_center_rounded,
              title: isArabic ? 'شركاء زميل' : 'Zameel Partners',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessScreen()),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.person_rounded,
              title: isArabic ? 'حسابي' : 'Profile',
              onTap: () {
                setState(() {
                  currentIndex = 11;
                });
                Navigator.pop(context);
              },
              isSelected: currentIndex == 11,
            ),
            const Divider(
              color: Colors.white24,
            ),
            _DrawerItem(
              icon: Icons.delete_forever_rounded,
              title: isArabic ? 'حذف الحساب' : 'Delete account',
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => Directionality(
                    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                    child: AlertDialog(
                      title: Text(isArabic ? 'حذف الحساب نهائياً؟' : 'Delete account permanently?'),
                      content: Text(isArabic
                          ? 'سيتم حذف حسابك وبياناتك المرتبطة به. لا يمكن التراجع عن هذا الإجراء.'
                          : 'Your account and associated data will be deleted. This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: Text(isArabic ? 'حذف الحساب' : 'Delete account'),
                        ),
                      ],
                    ),
                  ),
                );
                if (confirm != true || !mounted) return;
                final deleted = await deleteCurrentAccount();
                if (!mounted) return;
                if (deleted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (_) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'تعذر حذف الحساب. حاول مرة أخرى.' : 'Could not delete the account. Please try again.')),
                  );
                }
              },
              iconColor: Colors.red,
            ),
            _DrawerItem(
              icon: Icons.logout_rounded,
              title: isArabic ? '🚪 تسجيل الخروج' : '🚪 Logout',
              onTap: () async {
                Navigator.pop(context);

                final confirm = await showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return Directionality(
                      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                      child: AlertDialog(
                        backgroundColor: Colors.white.withAlpha(230),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          isArabic ? 'تسجيل الخروج' : 'Logout',
                        ),
                        content: Text(
                          isArabic
                              ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟'
                              : 'Are you sure you want to logout?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                            child: Text(
                              isArabic ? 'إلغاء' : 'Cancel',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                true,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              isArabic ? 'تسجيل الخروج' : 'Logout',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (confirm == true) {
                  await Supabase.instance.client.auth.signOut();

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    ),
                  );
                }
              },
              iconColor: Colors.red,
            ),
          ],
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: 72,
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: isArabic ? 'القائمة' : 'Menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          titleSpacing: 4,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/branding/zameel_mark.png', width: 34, height: 34, fit: BoxFit.contain),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  isArabic ? 'زميل' : 'Zameel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: isArabic ? 'البحث' : 'Search',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: isArabic ? 'حسابي' : 'My profile',
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً')));
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)));
              },
              icon: _ProfileAvatar(image: profileImage, imageBytes: profileImageBytes, imageUrl: profileImageUrl, radius: 18),
            ),
            Stack(
              children: [
                IconButton(
                  tooltip: isArabic ? 'الإشعارات' : 'Notifications',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    _loadUnreadNotifications();
                  },
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 5, top: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      child: Text('${_unreadNotifications > 99 ? '99+' : _unreadNotifications}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: _buildDrawer(context),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
          ),
          child: _buildCurrentPage(),
        ),
        floatingActionButton: currentIndex == 0
            ? FloatingActionButton(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                onPressed: createPost,
                child: const Icon(Icons.add_rounded),
              )
            : null,
        bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return _buildFeed();
      case 1:
        return const BooksScreen();
      case 2:
        return const ChatScreen();
      case 3:
        return const FriendsScreen();
      case 4:
        return const CampusScreen();
      case 5:
        return const MeetScreen();
      case 6:
        return const JobsScreen();
      case 7:
        return CalendarScreen();
      case 8:
        return const PollsScreen();
      case 9:
        return const PrivateGroupsScreen();
      case 10:
        return const AIScreen();
      case 11:
        return _buildProfilePage();
      default:
        return _buildFeed();
    }
  }

  Future<void> _sharePostToProfile(Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (user == null || postId == null) return;
    if (post['is_demo'] == true) {
      final text = (post['text_ar'] ?? post['text_en'] ?? '').toString();
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ محتوى المنشور التجريبي ✓')));
      return;
    }
    try {
      await Supabase.instance.client.from('shared_posts').upsert({'post_id': postId, 'shared_by': user.id});
      await _loadPosts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تمت مشاركة المنشور على ملفك الشخصي')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر مشاركة المنشور: $e')));
    }
  }

  Future<void> _showPostLikes(Map<String, dynamic> post) async {
    final postId = post['id'];
    if (postId == null) return;
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    try {
      final rows = await Supabase.instance.client.from('likes').select('user_id, created_at, users(name, profile_image)').eq('post_id', postId).order('created_at', ascending: false);
      if (!mounted) return;
      showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr, child: SizedBox(height: 480, child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: Text(ar ? 'الأشخاص الذين أعجبوا بالمنشور' : 'People who liked this post', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Expanded(child: rows.isEmpty ? Center(child: Text(ar ? 'لا توجد إعجابات بعد' : 'No likes yet')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final u = rows[i]['users']; final name = u is Map ? (u['name']?.toString() ?? 'User') : 'User'; final image = u is Map ? u['profile_image']?.toString() : null; return ListTile(leading: CircleAvatar(backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person) : null), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))); }))]))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الإعجابات: $e')));
    }
  }

  Widget _buildFeed() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    final stories = <Map<String, dynamic>>[
      {
        'name_ar': 'أحمد',
        'name_en': 'Ahmed',
        'time_ar': 'منذ 10 دقائق',
        'time_en': '10 min ago',
        'text_ar': 'اليوم كان يومًا رائعًا في الجامعة! 📚',
        'text_en': 'Today was a great day at university! 📚',
        'viewed': false,
      },
      {
        'name_ar': 'سارة',
        'name_en': 'Sara',
        'time_ar': 'منذ 25 دقيقة',
        'time_en': '25 min ago',
        'text_ar': 'قاعة المفضلة في المكتبة 📖',
        'text_en': 'My favorite spot in the library 📖',
        'viewed': false,
      },
    ];

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryColor, secondaryColor],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _ProfileAvatar(
                image: profileImage,
                imageBytes: profileImageBytes,
                imageUrl: profileImageUrl,
                radius: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isArabic ? 'مرحباً بك في زميل 👋' : 'Welcome to Zameel 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ZameelDailyHub(
        isArabic: isArabic,
        onStories: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoriesWidget(stories: stories)),
        ),
        onChat: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
        onCalendar: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        ),
        onGroups: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GroupsScreen()),
        ),
        onBooks: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BooksScreen()),
        ),
        onCreatePost: createPost,
        onSocial: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ZameelSocialStudio(isArabic: isArabic),
          ),
        ),
        profileImageUrl: profileImageUrl,
      ),
      _buildCreateBox(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                isArabic ? 'آخر ما يشاركه الزملاء' : 'Latest from the Zameel community',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              isArabic ? 'محتوى متنوع' : 'Balanced feed',
              style: const TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: stories
                .map(
                  (story) => Container(
                    width: 108,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDCEBE9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: primaryColor,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const Spacer(),
                        Text(
                          isArabic
                              ? story['name_ar'].toString()
                              : story['name_en'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isArabic
                              ? story['time_ar'].toString()
                              : story['time_en'].toString(),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ];

    if (posts.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Column(
            children: [
              Icon(Icons.post_add_rounded,
                  size: 58, color: primaryColor.withOpacity(.35)),
              const SizedBox(height: 10),
              Text(
                isArabic ? '📭 لا توجد منشورات' : '📭 No posts',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'كن أول من ينشر شيئًا!'
                    : 'Be the first to post something!',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else {
      for (final post in posts) {
        final userData =
            post['users'] is Map ? Map<String, dynamic>.from(post['users']) : {};
        final isLiked = post['liked'] == true;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: GlassContainer(
              child: _PostCard(
                post: {
                  ...post,
                  'name_ar': userData['name'] ?? 'مستخدم',
                  'name_en': userData['name'] ?? 'User',
                  'department_ar': widget.department,
                  'department_en': widget.department,
                  'time_ar': _formatTime(post['created_at']?.toString()),
                  'time_en': _formatTime(post['created_at']?.toString()),
                  'likes': post['likes_count'] ?? 0,
                  'comments': post['comments_count'] ?? 0,
                  'shares': post['shares_count'] ?? 0,
                  'liked': isLiked,
                },
                onLike: () => _toggleLike(posts.indexOf(post)),
                savedPosts: savedPosts,
                isAdmin: isAdmin,
                postOwnerId: post['user_id']?.toString(),
                onDelete: () => _showDeleteConfirmation(context, post),
                onShareToProfile: _sharePostToProfile,
              ),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUnreadNotifications();
        await _loadPosts();
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }


  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'الآن';

    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inSeconds < 60) return 'الآن';
      if (diff.inMinutes < 60) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      if (diff.inHours < 24) {
        return 'منذ ${diff.inHours} ساعة';
      }
      if (diff.inDays < 7) {
        return 'منذ ${diff.inDays} يوم';
      }
      return 'منذ ${diff.inDays ~/ 7} أسبوع';
    } catch (e) {
      return 'الآن';
    }
  }


  Widget _buildCreateBox() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return GlassContainer(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileAvatar(
                image: profileImage,
                imageBytes: profileImageBytes,
                imageUrl: profileImageUrl,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: createPost,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      Translations.translate(
                        'feed_share',
                        languageProvider.currentLanguage,
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(
            color: Colors.white24,
            height: 28,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CreateAction(
                icon: Icons.videocam_outlined,
                text: Translations.translate(
                  'feed_video',
                  languageProvider.currentLanguage,
                ),
                onTap: _pickVideo,
              ),
              _CreateAction(
                icon: Icons.image_outlined,
                text: Translations.translate(
                  'feed_image',
                  languageProvider.currentLanguage,
                ),
                onTap: _pickImage,
              ),
              _CreateAction(
                icon: Icons.menu_book_outlined,
                text: Translations.translate(
                  'feed_book',
                  languageProvider.currentLanguage,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BooksScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return ListView(
      padding: const EdgeInsets.only(
        top: 80,
        bottom: 20,
      ),
      children: [
        GlassContainer(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              GestureDetector(
                onTap: pickProfileImage,
                child: Stack(
                  children: [
                    _ProfileAvatar(
                      image: profileImage,
                      imageBytes: profileImageBytes,
                      radius: 55,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                Translations.translate(
                  'profile_student',
                  languageProvider.currentLanguage,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                translateText(
                  widget.university.name,
                  languageProvider.currentLanguage,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${translateText(widget.college.name, languageProvider.currentLanguage)} • ${translateText(widget.department, languageProvider.currentLanguage)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileOption(
          icon: Icons.bar_chart_rounded,
          title: isArabic ? '📊 الإحصاءات الشخصية' : '📊 Activity Stats',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StatsScreen(
                  postsCount: posts.length,
                  likesCount: posts.fold(
                    0,
                    (sum, post) => sum + ((post['likes_count'] ?? 0) as int),
                  ),
                  commentsCount: posts.fold(
                    0,
                    (sum, post) => sum + ((post['comments_count'] ?? 0) as int),
                  ),
                  friendsCount: 12,
                  savedBooksCount: 3,
                  activeDays: 45,
                ),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.timeline_rounded,
          title: isArabic ? '⏰ النشاط' : '⏰ Activity',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏰ عرض النشاط'),
                backgroundColor: primaryColor,
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.emoji_events_rounded,
          title: isArabic ? '🏆 الإنجازات' : '🏆 Achievements',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🏆 عرض الإنجازات'),
                backgroundColor: Color(0xFF18D4C6),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.camera_alt_outlined,
          title: Translations.translate(
            'profile_change_image',
            languageProvider.currentLanguage,
          ),
          onTap: pickProfileImage,
        ),
        _ProfileOption(
          icon: Icons.edit_outlined,
          title: Translations.translate(
            'profile_edit_info',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: null),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.menu_book_outlined,
          title: Translations.translate(
            'profile_my_books',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BooksScreen(),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.school_rounded,
          title: Translations.translate(
            'graduation_book',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GraduationBookScreen(
                  studentName: 'طالب زميل',
                  university: widget.university.name,
                  major: widget.department,
                  graduationYear: '2024',
                ),
              ),
            );
          },
        ),

        _ProfileOption(
          icon: Icons.bookmark_border_rounded,
          title: Translations.translate(
            'profile_saved',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SavedPostsScreen(
                  savedPosts: savedPosts,
                ),
              ),
            );
          },
        ),
        const Divider(
          color: Colors.white24,
          height: 30,
        ),
        _ProfileOption(
          icon: Icons.logout_rounded,
          title: isArabic ? '🚪 تسجيل الخروج' : '🚪 Logout',
          iconColor: Colors.red,
          onTap: () async {
            final confirm = await showDialog(
              context: context,
              builder: (dialogContext) {
                return Directionality(
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: AlertDialog(
                    backgroundColor: Colors.white.withAlpha(230),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      isArabic ? 'تسجيل الخروج' : 'Logout',
                    ),
                    content: Text(
                      isArabic
                          ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟'
                          : 'Are you sure you want to logout?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          isArabic ? 'إلغاء' : 'Cancel',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          isArabic ? 'تسجيل الخروج' : 'Logout',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );

            if (confirm == true) {
              await Supabase.instance.client.auth.signOut();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const WelcomeScreen(),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

// ============================================================
// DRAWER ITEM
// ============================================================

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (isSelected ? Colors.white : Colors.white70),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
      tileColor: isSelected ? Colors.white.withAlpha(25) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ============================================================
// PROFILE AVATAR
// ============================================================

class _ProfileAvatar extends StatelessWidget {
  final File? image;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final double radius;
  final bool showEdit;

  const _ProfileAvatar({
    this.image,
    this.imageBytes,
    this.imageUrl,
    required this.radius,
    this.showEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasBytes = imageBytes != null && imageBytes!.isNotEmpty;
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white.withAlpha(51),
          backgroundImage: hasBytes
              ? null
              : (image != null && !kIsWeb
                  ? FileImage(image!)
                  : (imageUrl != null && imageUrl!.isNotEmpty
                      ? NetworkImage(imageUrl!)
                      : null)),
          child: hasBytes
              ? ClipOval(
                  child: Image.memory(
                    imageBytes!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      size: radius * 1.05,
                      color: Colors.white70,
                    ),
                  ),
                )
              : (image == null && (imageUrl == null || imageUrl!.isEmpty))
                  ? ClipOval(
                      child: Image.asset(
                        'assets/branding/zameel_mark.png',
                        width: radius * 1.7,
                        height: radius * 1.7,
                        fit: BoxFit.contain,
                      ),
                    )
                  : null,
        ),
        if (showEdit)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 23,
              height: 23,
              decoration: const BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// CREATE ACTION
// ============================================================

class _CreateAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _CreateAction({
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE OPTION
// ============================================================

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.white.withAlpha(51),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: iconColor ?? Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ============================================================
// USER PROFILE NAVIGATION
// ============================================================

void _openUserProfile(BuildContext context, String? userId) {
  final id = userId?.trim();
  if (id == null || id.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الملف الشخصي لهذا المستخدم')),
    );
    return;
  }

  final demoIndex = _demoUsers.indexWhere((u) => u['id']?.toString() == id);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => demoIndex >= 0
          ? DemoProfileScreen(user: _demoUsers[demoIndex])
          : ProfileScreen(userId: id),
    ),
  );
}

class DemoProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const DemoProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final name = user['name']?.toString() ?? (ar ? 'مستخدم تجريبي' : 'Demo user');
    final role = user['role']?.toString() ?? 'student';
    final department = user['department']?.toString() ?? '';
    final myPosts = _demoPosts.where((p) => p['user_id'] == user['id']).toList();
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const SizedBox.shrink()),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(children: [
                CircleAvatar(radius: 42, backgroundColor: Colors.white.withValues(alpha: .92), child: Text(name.isNotEmpty ? name.substring(0, 1) : 'ز', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryDark))),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(department, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)), child: Text(role == 'company' ? 'نشاط تجاري تجريبي' : 'حساب تجريبي', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: Text(ar ? 'منشورات المستخدم' : 'User posts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ...myPosts.map((post) => Card(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Padding(padding: const EdgeInsets.all(16), child: Text(ar ? post['text_ar'].toString() : post['text_en'].toString(), style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600))))) ,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// POST CARD
// ============================================================

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  Widget build(BuildContext context) {
    final String type = post['type'] ?? 'text';

    if (type == 'video') {
      return _VideoPost(
        post: post,
        onLike: onLike,
        savedPosts: savedPosts,
        isAdmin: isAdmin,
        postOwnerId: postOwnerId,
        onDelete: onDelete,
        onShareToProfile: onShareToProfile,
      );
    }

    if (type == 'image') {
      return _ImagePost(
        post: post,
        onLike: onLike,
        savedPosts: savedPosts,
        isAdmin: isAdmin,
        postOwnerId: postOwnerId,
        onDelete: onDelete,
        onShareToProfile: onShareToProfile,
      );
    }

    return _TextPost(
      post: post,
      onLike: onLike,
      savedPosts: savedPosts,
      isAdmin: isAdmin,
      postOwnerId: postOwnerId,
      onDelete: onDelete,
      onShareToProfile: onShareToProfile,
    );
  }
}

// ============================================================
// IMAGE POST
// ============================================================

class _ImagePost extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _ImagePost({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  State<_ImagePost> createState() => _ImagePostState();
}

class _ImagePostState extends State<_ImagePost> {
  late bool _isOwner;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _isOwner = widget.post['user_id'] == user?.id;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    final bool liked = widget.post['liked'] ?? false;
    final bool isSaved = widget.post['isSaved'] ?? false;
    final String imageUrl = widget.post['image_url']?.toString() ?? '';
    final bool canDelete = widget.isAdmin || _isOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------
        // HEADER
        // ------------------------------------------------------
        Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(
                context,
                widget.post['user_id']?.toString(),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.person,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUserProfile(
                  context,
                  widget.post['user_id']?.toString(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? (widget.post['name_ar'] ?? 'مستخدم').toString()
                          : (widget.post['name_en'] ?? 'User').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${isArabic ? (widget.post['department_ar'] ?? '') : (widget.post['department_en'] ?? '')} • '
                      '${isArabic ? (widget.post['time_ar'] ?? '') : (widget.post['time_en'] ?? '')}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --------------------------------------------------
            // MORE / DELETE
            // --------------------------------------------------
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white60,
              ),
              tooltip: isArabic ? 'المزيد' : 'More',
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                final bool isOwner =
                    widget.post['user_id']?.toString() == user?.id;
                final bool canDelete = widget.isAdmin || isOwner;

                if (!canDelete) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'ليس لديك صلاحية لهذا المنشور'
                            : 'You do not have permission for this post',
                      ),
                    ),
                  );
                  return;
                }

                widget.onDelete();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ------------------------------------------------------
        // TEXT
        // ------------------------------------------------------
        if (((isArabic ? widget.post['text_ar'] : widget.post['text_en']) ?? '')
            .toString()
            .trim()
            .isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              (isArabic ? widget.post['text_ar'] : widget.post['text_en'])
                  .toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        // ------------------------------------------------------
        // IMAGE
        // ------------------------------------------------------
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZameelMediaViewer(
                      post: widget.post,
                      isVideo: false,
                      onLikeChanged: () => setState(() {}),
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: 230,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    alignment: Alignment.center,
                    color: Colors.white10,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 50,
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        // ------------------------------------------------------
        // COUNTERS
        // ------------------------------------------------------
        Row(
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 17,
              color: liked ? accentColor : Colors.white60,
            ),
            const SizedBox(width: 5),
            InkWell(
              onTap: () => _showPostLikesDialog(context, widget.post, isArabic),
              child: Text('${widget.post['likes'] ?? 0}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.repeat_rounded, size: 16, color: Colors.white60),
            const SizedBox(width: 4),
            Text('${widget.post['shares'] ?? 0}', style: const TextStyle(color: Colors.white60)),
            const Spacer(),
            Text(
              '${widget.post['comments'] ?? 0} '
              '${Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              )}',
              style: const TextStyle(
                color: Colors.white60,
              ),
            ),
          ],
        ),
        const Divider(
          color: Colors.white24,
          height: 25,
        ),
        // ------------------------------------------------------
        // ACTIONS
        // ------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // LIKE
            _PostAction(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              active: liked,
              onTap: widget.onLike,
              color: Colors.white70,
            ),
            // COMMENTS
            _PostAction(
              icon: Icons.comment_outlined,
              text: Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      post: widget.post,
                    ),
                  ),
                );
              },
              color: Colors.white70,
            ),
            // SAVE
            _PostAction(
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              text: isArabic ? 'حفظ' : 'Save',
              active: isSaved,
              color: isSaved ? accentColor : Colors.white70,
              onTap: () {
                setState(() {
                  widget.post['isSaved'] = !isSaved;
                  if (widget.post['isSaved'] == true) {
                    widget.savedPosts.insert(
                      0,
                      widget.post,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? 'تم حفظ المنشور' : 'Post saved',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } else {
                    widget.savedPosts.removeWhere(
                      (p) => p['id'] == widget.post['id'] || p['text'] == widget.post['text'],
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? 'تم إلغاء حفظ المنشور' : 'Post removed from saved',
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                });
              },
            ),
            // SHARE
            _PostAction(
              icon: Icons.share_outlined,
              text: isArabic ? 'مشاركة' : 'Share',
              color: Colors.white70,
              onTap: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
                final text = isArabic
                    ? (widget.post['text_ar'] ?? widget.post['text_en'] ?? '')
                    : (widget.post['text_en'] ?? widget.post['text_ar'] ?? '');
                await Clipboard.setData(ClipboardData(text: '$text'));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// VIDEO POST
// ============================================================

class _VideoPost extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _VideoPost({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  State<_VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<_VideoPost> {
  @override
  Widget build(BuildContext context) {
    final bool liked = widget.post['liked'] ?? false;
    final String videoUrl = widget.post['video_url'] ??
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
  children: [
    GestureDetector(
      onTap: () => _openUserProfile(
        context,
        widget.post['user_id']?.toString(),
      ),
      child: const CircleAvatar(
        backgroundColor: Colors.white24,
        child: Icon(
          Icons.person,
          color: Colors.white70,
        ),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openUserProfile(
          context,
          widget.post['user_id']?.toString(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? widget.post['name_ar'] : widget.post['name_en'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${isArabic ? widget.post['department_ar'] : widget.post['department_en']} • '
              '${isArabic ? widget.post['time_ar'] : widget.post['time_en']}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
    if (widget.isAdmin ||
        widget.post['user_id'] ==
            Supabase.instance.client.auth.currentUser?.id)
      PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_horiz,
          color: Colors.white60,
        ),
        onSelected: (value) {
          if (value == 'delete') {
            widget.onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'حذف' : 'Delete',
                ),
              ],
            ),
          ),
        ],
      )
    else
      const Icon(
        Icons.more_horiz,
        color: Colors.white60,
      ),
  ],
),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ZameelMediaViewer(
                  post: widget.post,
                  isVideo: true,
                  onLikeChanged: () => setState(() {}),
                ),
              ),
            ),
            child: SizedBox(
              height: 230,
              width: double.infinity,
              child: VideoPlayerWidget(videoUrl: videoUrl),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isArabic ? widget.post['text_ar'] : widget.post['text_en'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          InkWell(onTap: () => _showPostLikesDialog(context, widget.post, isArabic), child: Row(children: [const Icon(Icons.favorite_rounded, size: 16, color: Colors.white60), const SizedBox(width: 4), Text('${widget.post['likes'] ?? 0}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 14),
          const Icon(Icons.repeat_rounded, size: 16, color: Colors.white60), const SizedBox(width: 4),
          Text('${widget.post['shares'] ?? 0}', style: const TextStyle(color: Colors.white60)),
          const Spacer(), Text('${widget.post['comments'] ?? 0} ${Translations.translate('comments_title', languageProvider.currentLanguage)}', style: const TextStyle(color: Colors.white60)),
        ]),
        const Divider(color: Colors.white24, height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PostAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              text: '${widget.post['likes'] ?? 0}',
              active: liked,
              onTap: widget.onLike,
              color: Colors.white70,
            ),
            _PostAction(
              icon: Icons.comment_rounded,
              text: '${widget.post['comments']}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      post: widget.post,
                    ),
                  ),
                );
              },
              color: Colors.white70,
            ),
            _PostAction(
              icon: widget.post['isSaved'] == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              text: isArabic ? 'حفظ' : 'Save',
              color: widget.post['isSaved'] == true ? accentColor : Colors.white70,
              onTap: () {
                setState(() {
                  widget.post['isSaved'] = !(widget.post['isSaved'] == true);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.post['isSaved'] == true
                          ? (isArabic ? '✅ تم حفظ الفيديو' : '✅ Video saved')
                          : (isArabic ? '🗑️ تم إلغاء حفظ الفيديو' : '🗑️ Video removed from saved'),
                    ),
                    backgroundColor: const Color(0xFF18D4C6),
                  ),
                );
              },
            ),
            _PostAction(
              icon: Icons.share_rounded,
              text: isArabic ? 'مشاركة' : 'Share',
              color: Colors.white70,
              onTap: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
                final videoUrl = '${widget.post['video_url'] ?? widget.post['videoUrl'] ?? ''}';
                await Clipboard.setData(ClipboardData(text: videoUrl.isNotEmpty ? videoUrl : '${widget.post['text_ar'] ?? widget.post['text_en'] ?? ''}'));
              },
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _showPostLikesDialog(BuildContext context, Map<String, dynamic> post, bool isArabic) async {
  final postId = post['id'];
  if (postId == null) return;
  try {
    final rows = await Supabase.instance.client.from('likes').select('user_id, users(name, profile_image)').eq('post_id', postId).order('created_at', ascending: false);
    if (!context.mounted) return;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Directionality(textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr, child: SizedBox(height: 480, child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: Text(isArabic ? 'الأشخاص الذين أعجبوا بالمنشور' : 'People who liked this post', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Expanded(child: rows.isEmpty ? Center(child: Text(isArabic ? 'لا توجد إعجابات بعد' : 'No likes yet')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final u = rows[i]['users']; final name = u is Map ? (u['name']?.toString() ?? 'User') : 'User'; final image = u is Map ? u['profile_image']?.toString() : null; return ListTile(leading: CircleAvatar(backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person) : null), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))); }))]))));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل قائمة الإعجابات: $e')));
  }
}


// ============================================================
// MEDIA VIEWER
// ============================================================

class ZameelMediaViewer extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isVideo;
  final VoidCallback? onLikeChanged;

  const ZameelMediaViewer({
    super.key,
    required this.post,
    required this.isVideo,
    this.onLikeChanged,
  });

  @override
  State<ZameelMediaViewer> createState() => _ZameelMediaViewerState();
}

class _ZameelMediaViewerState extends State<ZameelMediaViewer> {
  bool _busy = false;

  String get _url => (widget.isVideo
          ? widget.post['video_url']
          : widget.post['image_url'])
      ?.toString() ??
      '';

  Future<void> _toggleLike() async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    if (user == null || postId == null || _busy) return;
    setState(() => _busy = true);
    final liked = widget.post['liked'] == true;
    try {
      if (liked) {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
      } else {
        await Supabase.instance.client
            .from('likes')
            .upsert({'user_id': user.id, 'post_id': postId});
      }
      if (!mounted) return;
      final oldCount =
          ((widget.post['likes_count'] ?? widget.post['likes'] ?? 0) as num)
              .toInt();
      setState(() {
        widget.post['liked'] = !liked;
        widget.post['likes_count'] =
            liked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
        widget.post['likes'] = widget.post['likes_count'];
      });
      widget.onLikeChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الإعجاب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSave() async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    if (user == null || postId == null || _busy) return;
    setState(() => _busy = true);
    final saved = widget.post['isSaved'] == true;
    try {
      if (saved) {
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
      } else {
        await Supabase.instance.client
            .from('saved_posts')
            .upsert({'user_id': user.id, 'post_id': postId});
      }
      if (mounted) setState(() => widget.post['isSaved'] = !saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    if (user != null && postId != null) {
      try {
        await Supabase.instance.client.from('shared_posts').upsert({
          'post_id': postId,
          'shared_by': user.id,
        }, onConflict: 'post_id,shared_by');
      } catch (_) {}
    }
    await SharePlus.instance.share(
      ShareParams(
        text: '${widget.post['text_ar'] ?? widget.post['text_en'] ?? ''}\n$_url',
        subject: 'Zameel',
      ),
    );
  }

  Future<void> _copyLink() async {
    if (_url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _url));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نسخ الرابط ✓')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liked = widget.post['liked'] == true;
    final saved = widget.post['isSaved'] == true;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.isVideo ? 'الفيديو' : 'الصورة'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: widget.isVideo
                    ? VideoPlayerWidget(videoUrl: _url)
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: Image.network(
                          _url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
              ),
            ),
            Container(
              color: Colors.black.withOpacity(.94),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: liked ? accentColor : Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleSave,
                    icon: Icon(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: saved ? accentColor : Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _share,
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.link_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// POST ACTION
// ============================================================

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback? onTap;
  final Color color;

  const _PostAction({
    required this.icon,
    required this.text,
    this.active = false,
    this.onTap,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: active ? accentColor : color,
            size: 22,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: active ? accentColor : color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TEXT POST
// ============================================================

class _TextPost extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _TextPost({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  State<_TextPost> createState() => _TextPostState();
}

class _TextPostState extends State<_TextPost> {
  late bool _isOwner;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _isOwner = widget.post['user_id'] == user?.id;
  }

  @override
  Widget build(BuildContext context) {
    final bool liked = widget.post['liked'] ?? false;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final bool isSaved = widget.post['isSaved'] ?? false;
    final bool canDelete = widget.isAdmin || _isOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(
                context,
                widget.post['user_id']?.toString(),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.person,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUserProfile(
                  context,
                  widget.post['user_id']?.toString(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? widget.post['name_ar'] : widget.post['name_en'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${isArabic ? widget.post['department_ar'] : widget.post['department_en']} • '
                      '${isArabic ? widget.post['time_ar'] : widget.post['time_en']}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // زر "..." مع قائمة منبثقة
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white60,
              ),
              tooltip: isArabic ? 'المزيد' : 'More',
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                final bool isOwner =
                    widget.post['user_id']?.toString() == user?.id;
                final bool canDelete = widget.isAdmin || isOwner;

                if (!canDelete) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'ليس لديك صلاحية لهذا المنشور'
                            : 'You do not have permission for this post',
                      ),
                    ),
                  );
                  return;
                }

                widget.onDelete();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          isArabic ? widget.post['text_ar'] : widget.post['text_en'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 17,
              color: liked ? accentColor : Colors.white60,
            ),
            const SizedBox(width: 5),
            InkWell(
              onTap: () => _showPostLikesDialog(context, widget.post, isArabic),
              child: Text('${widget.post['likes'] ?? 0}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 20),
            const Icon(Icons.repeat_rounded, size: 16, color: Colors.white60),
            const SizedBox(width: 4),
            Text('${widget.post['shares'] ?? 0}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(width: 20),
            Text(
              '${widget.post['comments'] ?? 0} ${Translations.translate('comments_title', languageProvider.currentLanguage)}',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
        const Divider(
          color: Colors.white24,
          height: 25,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PostAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              active: liked,
              onTap: widget.onLike,
              color: Colors.white70,
            ),
            _PostAction(
              icon: Icons.comment_outlined,
              text: Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      post: widget.post,
                    ),
                  ),
                );
              },
              color: Colors.white70,
            ),
            _PostAction(
              icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              text: isArabic ? 'حفظ' : 'Save',
              active: isSaved,
              color: isSaved ? accentColor : Colors.white70,
              onTap: () {
                setState(() {
                  widget.post['isSaved'] = !isSaved;
                  if (widget.post['isSaved']) {
                    widget.savedPosts.insert(
                      0,
                      widget.post,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? '✅ تم حفظ المنشور' : 'Post saved',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } else {
                    widget.savedPosts.removeWhere(
                      (p) => p['text'] == widget.post['text'],
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? '🗑️ تم إلغاء الحفظ' : 'Post removed from saved',
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                });
              },
            ),
            _PostAction(
              icon: Icons.share_outlined,
              text: isArabic ? 'مشاركة' : 'Share',
              color: Colors.white70,
              onTap: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
                final text = isArabic
                    ? (widget.post['text_ar'] ?? widget.post['text_en'] ?? '')
                    : (widget.post['text_en'] ?? widget.post['text_ar'] ?? '');
                await Clipboard.setData(ClipboardData(text: '$text'));
              },
            ),
          ],
        ),
      ],
    );
  }
}
