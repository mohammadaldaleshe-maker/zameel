part of '../main.dart';

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
      if (data.session != null) {
        PushNotificationService.instance.registerForCurrentUser();
      }
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

const Color primaryColor = AppTheme.primary;
const Color primaryLight = AppTheme.primaryLight;
const Color secondaryColor = AppTheme.secondary;
const Color accentColor = AppTheme.tertiary;
const Color redColor = AppTheme.error;

const Color glassColor = AppTheme.glassFill;
const Color glassBorder = AppTheme.glassBorder;

const Color gradientStart = AppTheme.primary;
const Color gradientEnd = AppTheme.secondary;


// Demo content remains visible alongside real Supabase content. These entries
// are local-only and are never written into the user's real database.
const List<Map<String, dynamic>> _demoUsers = [
  {'id': '00000000-0000-4000-8000-000000000001', 'name': 'ليان الخطيب', 'gender': 'female', 'role': 'student', 'department': 'علوم الحاسوب'},
  {'id': '00000000-0000-4000-8000-000000000002', 'name': 'آدم الحوراني', 'gender': 'male', 'role': 'student', 'department': 'هندسة البرمجيات'},
  {'id': '00000000-0000-4000-8000-000000000003', 'name': 'نور العزام', 'gender': 'female', 'role': 'graduate', 'department': 'إدارة الأعمال'},
  {'id': '00000000-0000-4000-8000-000000000004', 'name': 'يوسف الشديفات', 'gender': 'male', 'role': 'student', 'department': 'الهندسة المدنية'},
  {'id': '00000000-0000-4000-8000-000000000005', 'name': 'مؤسسة Zameel للطلاب', 'gender': null, 'role': 'company', 'department': 'نشاط تجاري'},
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
            AppTheme.glassFill,
            AppTheme.glassSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.glassBorder,
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

