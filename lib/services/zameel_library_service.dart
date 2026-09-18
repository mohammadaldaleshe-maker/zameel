import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models_zameel_library.dart';

class ZameelLibraryService {
  static const _seedAsset = 'assets/zameel_library/zameel_library_index.json';
  static const _manifestAsset = 'assets/zameel_library/zameel_library_manifest.json';
  static const _taxonomyAsset =
      'assets/zameel_library/zameel_specialties.json';
  static const _openTextbookTarget = 1000;
  static const _arabicBookTarget = 500;
  static const _englishBookTarget = 500;

  static List<ZameelLibraryItem>? _seedCache;
  static Map<String, dynamic>? _manifestCache;
  static final Map<String, Map<String, dynamic>> _contentShardCache = {};
  static List<ZameelLibrarySpecialtyGroup>? _taxonomyCache;
  static List<ZameelLibraryItem>? _openTextbookCache;
  static List<ZameelLibraryItem>? _arabicBookCache;


  static Future<Map<String, dynamic>> loadManifest() async {
    if (_manifestCache != null) return _manifestCache!;
    final raw = await rootBundle.loadString(_manifestAsset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const <String, dynamic>{};
    _manifestCache = Map<String, dynamic>.from(decoded);
    return _manifestCache!;
  }

  static Future<Map<String, int>> specialtyCount(
    ZameelLibrarySpecialty specialty,
  ) async {
    final manifest = await loadManifest();
    final categories = manifest['categories'];
    var books = 0;
    var summaries = 0;
    if (categories is Map) {
      for (final name in specialty.searchableNames) {
        final value = categories[name];
        if (value is Map) {
          books += (value['books'] as num?)?.toInt() ?? 0;
          summaries += (value['summaries'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return {
      'books': books,
      'summaries': summaries,
      'total': books + summaries,
    };
  }

  static Future<List<ZameelLibraryItem>> loadBundledItemsForSpecialty(
    ZameelLibrarySpecialty specialty,
  ) async {
    final seed = await _loadSeed();
    return itemsForSpecialty(
      seed.where((item) => item.published).toList(),
      specialty,
    );
  }

  static Future<List<ZameelLibraryItem>> loadRemoteItemsForSpecialty(
    ZameelLibrarySpecialty specialty,
  ) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return const [];
    try {
      final names = specialty.searchableNames
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .toList();
      if (names.isEmpty) return const [];
      final rows = await client
          .from('zameel_library_items')
          .select(
            'id,item_type,title,title_ar,title_en,category,author,description,description_ar,description_en,keywords,source_url,file_url,content_text,content_ar,content_en,language,source_language,rights_status,circulation_status,is_published,is_featured',
          )
          .eq('is_published', true)
          .inFilter('category', names)
          .order('is_featured', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 8));
      return rows
          .whereType<Map>()
          .map(
            (entry) => ZameelLibraryItem.fromRemote(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((item) => item.published)
          .toList();
    } catch (error) {
      debugPrint('Zameel Library category remote load skipped: $error');
      return const [];
    }
  }

  static Future<List<ZameelLibraryItem>> loadOpenBooksForSpecialty(
    ZameelLibrarySpecialty specialty, {
    int limit = 24,
  }) async {
    if (limit <= 0) return const [];
    final arQuery = specialty.name;
    final enQuery = specialty.nameEn.trim().isEmpty
        ? specialty.name
        : specialty.nameEn;
    final half = math.max(1, (limit / 2).ceil());
    final results = await Future.wait([
      _loadArabicCollections(limit: half, query: arQuery),
      _loadOpenTextbooks(limit: limit - half, query: enQuery),
    ]);
    final accepted = specialty.searchableNames.map(normalize).toSet();
    final merged = <String, ZameelLibraryItem>{};
    for (final item in [...results[0], ...results[1]]) {
      final category = normalize(item.category);
      if (!accepted.contains(category) &&
          itemSearchScore(item, normalize('${specialty.name} ${specialty.nameEn}')) <
              140) {
        continue;
      }
      merged[item.downloadKey] = item;
    }
    return merged.values.take(limit).toList();
  }

  static Future<List<ZameelLibraryItem>> loadPublishedItems() async {
    final seed = await _loadSeed();
    final publishedSeed = seed.where((item) => item.published).toList();
    final remote = await _loadRemotePublished();

    final merged = <String, ZameelLibraryItem>{};
    for (final item in publishedSeed) {
      merged['seed:${item.id}'] = item;
    }
    for (final item in remote) {
      merged['remote:${item.id}'] = item;
    }

    final result = merged.values.toList();
    result.sort((a, b) {
      if (a.curated != b.curated) return a.curated ? -1 : 1;
      final category = a.category.compareTo(b.category);
      if (category != 0) return category;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  static Future<List<ZameelLibraryItem>> loadOpenTextbookItems({
    int limit = _openTextbookTarget,
  }) async {
    final arabicLimit = math.min(_arabicBookTarget, (limit / 2).ceil());
    final englishLimit = math.min(_englishBookTarget, limit - arabicLimit);
    final results = await Future.wait([
      _loadArabicCollections(limit: arabicLimit),
      _loadOpenTextbooks(limit: englishLimit),
    ]);
    final merged = <String, ZameelLibraryItem>{};
    for (final item in [...results[0], ...results[1]]) {
      final key = (item.sourceUrl?.trim().isNotEmpty == true)
          ? item.sourceUrl!.trim()
          : '${item.id}|${item.title}';
      merged[key] = item;
    }
    return merged.values.take(limit).toList();
  }

  static Future<Map<String, int>> loadSeedStats() async {
    final manifest = await loadManifest();
    int read(String key, int fallback) =>
        (manifest[key] as num?)?.toInt() ?? fallback;
    return {
      'books_total': read('books_total', 0),
      'books_published': read('books_published', 0),
      'summaries_total': read('summaries_total', 0),
      'open_textbook_target': read('open_textbook_target', _openTextbookTarget),
      'arabic_books_target': read('arabic_books_target', _arabicBookTarget),
      'english_books_target': read('english_books_target', _englishBookTarget),
    };
  }

  static Future<List<ZameelLibrarySpecialtyGroup>>
      loadSpecialtyGroups() async {
    if (_taxonomyCache != null) return _taxonomyCache!;
    final raw = await rootBundle.loadString(_taxonomyAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final groups = (decoded['groups'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (entry) => ZameelLibrarySpecialtyGroup.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .where((group) => group.name.isNotEmpty && group.specialties.isNotEmpty)
        .toList();
    _taxonomyCache = groups;
    return groups;
  }

  static List<ZameelLibrarySpecialty> allSpecialties(
    List<ZameelLibrarySpecialtyGroup> groups,
  ) {
    return groups.expand((group) => group.specialties).toList();
  }

  static List<ZameelLibrarySpecialty> rankSpecialties(
    List<ZameelLibrarySpecialty> specialties,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) return [...specialties];
    final ranked = specialties
        .map(
          (specialty) => MapEntry(
            specialty,
            specialty.searchableNames
                .map((name) => _textScore(name, q))
                .fold<double>(0, (best, score) => math.max(best, score).toDouble()),
          ),
        )
        .toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        return byScore != 0
            ? byScore
            : a.key.name.compareTo(b.key.name);
      });
    return ranked.map((entry) => entry.key).toList();
  }

  static bool hasDirectSpecialtyMatch(
    List<ZameelLibrarySpecialty> specialties,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    return specialties.any(
      (specialty) => specialty.searchableNames.any((name) {
        final value = normalize(name);
        return value == q || value.contains(q) || q.contains(value);
      }),
    );
  }

  static List<ZameelLibraryItem> itemsForSpecialty(
    List<ZameelLibraryItem> items,
    ZameelLibrarySpecialty specialty,
  ) {
    final accepted = specialty.searchableNames.map(normalize).toSet();
    return items.where((item) {
      final category = normalize(item.category);
      return accepted.contains(category);
    }).toList();
  }

  static Future<List<ZameelLibraryItem>> _loadSeed() async {
    if (_seedCache != null) return _seedCache!;
    final raw = await rootBundle.loadString(_seedAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = (decoded['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (entry) => ZameelLibraryItem.fromSeed(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
    _seedCache = items;
    return items;
  }

  static Future<List<ZameelLibraryItem>> _loadRemotePublished() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return const [];
    try {
      final rows = await client
          .from('zameel_library_items')
          .select(
            'id,item_type,title,title_ar,title_en,category,author,description,description_ar,description_en,keywords,source_url,file_url,content_text,content_ar,content_en,language,source_language,rights_status,circulation_status,is_published,is_featured',
          )
          .eq('is_published', true)
          .order('is_featured', ascending: false)
          .order('created_at');
      return rows
          .whereType<Map>()
          .map(
            (entry) => ZameelLibraryItem.fromRemote(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((item) => item.published)
          .toList();
    } catch (error) {
      debugPrint('Zameel Library remote load skipped: $error');
      return const [];
    }
  }

  static Future<List<ZameelLibraryItem>> _loadArabicCollections({
    required int limit,
    String? query,
  }) async {
    if (limit <= 0) return const [];
    final normalizedQuery = query?.trim() ?? '';
    if (normalizedQuery.isEmpty &&
        _arabicBookCache != null &&
        _arabicBookCache!.length >= limit) {
      return _arabicBookCache!.take(limit).toList();
    }
    final client = http.Client();
    final collected = <ZameelLibraryItem>[];
    var start = 0;
    try {
      while (collected.length < limit && start < 5000) {
        final rows = math.min(100, limit - collected.length);
        final queryPart = normalizedQuery.isEmpty
            ? ''
            : '&q=${Uri.encodeQueryComponent(normalizedQuery)}';
        final uri = Uri.parse(
          'https://sites.dlib.nyu.edu/viewer/api/v1/objects'
          '?collection=aco&type=dlts_book&rows=$rows&start=$start$queryPart',
        );
        final response =
            await client.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) break;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) break;
        final responseMap = decoded['response'];
        if (responseMap is! Map) break;
        final docs = responseMap['docs'];
        if (docs is! List || docs.isEmpty) break;
        for (final raw in docs.whereType<Map>()) {
          final item = _acoBookItem(Map<String, dynamic>.from(raw));
          if (item != null) collected.add(item);
          if (collected.length >= limit) break;
        }
        start += docs.length;
        if (docs.length < rows) break;
      }
    } catch (error) {
      debugPrint(
        'Zameel Library Arabic Collections Online load skipped after '
        '${collected.length} books: $error',
      );
    } finally {
      client.close();
    }
    if (normalizedQuery.isEmpty) {
      _arabicBookCache = collected;
    }
    return collected.take(limit).toList();
  }

  static ZameelLibraryItem? _acoBookItem(Map<String, dynamic> json) {
    final identifier = json['identifier']?.toString().trim() ?? '';
    final rawId = json['nid']?.toString().trim() ?? identifier;
    final title = json['title']?.toString().trim() ?? '';
    if (identifier.isEmpty || title.isEmpty) return null;
    final category = _mapOpenTextbookCategory(const [], title, title);
    final source =
        'https://sites.dlib.nyu.edu/viewer/api/embed/$identifier';
    return ZameelLibraryItem(
      id: 'aco-$rawId',
      type: 'book',
      title: title,
      titleAr: title,
      titleEn: title,
      category: category,
      author: '',
      description:
          'كتاب عربي من Arabic Collections Online، يفتح من المصدر الأصلي مع معلومات الحقوق الخاصة بالمصدر.',
      descriptionAr:
          'كتاب عربي من المجموعات العربية على الإنترنت (ACO). تذكر ACO أنها تعتقد أن المواد المعروضة لديها ضمن الملك العام؛ يفتح زميل المصدر الأصلي بدل إعادة استضافة الملف.',
      descriptionEn:
          'Arabic-language book from Arabic Collections Online (ACO). ACO states that it believes the materials displayed on its site are in the public domain; Zameel opens the original source instead of re-hosting the file.',
      keywords: [category, 'Arabic Collections Online', 'ACO', 'كتاب عربي'],
      sourceUrl: source,
      fileUrl: null,
      content: null,
      rightsStatus: 'Arabic Collections Online • source rights notice applies',
      circulationStatus: '',
      published: true,
      bundled: false,
      curated: false,
      language: 'ar',
      sourceLanguage: 'ar',
    );
  }

  static Future<List<ZameelLibraryItem>> _loadOpenTextbooks({
    required int limit,
    String? query,
  }) async {
    final normalizedQuery = query?.trim() ?? '';
    if (normalizedQuery.isEmpty &&
        _openTextbookCache != null &&
        _openTextbookCache!.length >= math.min(limit, _openTextbookTarget)) {
      return _openTextbookCache!.take(limit).toList();
    }

    final client = http.Client();
    final collected = <ZameelLibraryItem>[];
    final params = <String, String>{
      'per_page': '100',
      'format': 'PDF',
      if (normalizedQuery.isNotEmpty) 'q': normalizedQuery,
    };
    Uri? next = Uri.https(
      'open.umn.edu',
      '/opentextbooks/textbooks.json',
      params,
    );
    var pageCount = 0;

    try {
      while (next != null && collected.length < limit && pageCount < 80) {
        pageCount++;
        final response =
            await client.get(next).timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) break;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map) break;
        final map = Map<String, dynamic>.from(decoded);
        final data = map['data'];
        if (data is! List || data.isEmpty) break;

        for (final raw in data.whereType<Map>()) {
          final item = _openTextbookItem(Map<String, dynamic>.from(raw));
          if (item != null) {
            collected.add(item);
            if (collected.length >= limit) break;
          }
        }

        final links = map['links'];
        final nextRaw = links is Map ? links['next']?.toString().trim() : null;
        if (nextRaw == null || nextRaw.isEmpty) {
          next = null;
        } else {
          final parsed = Uri.tryParse(nextRaw);
          next = parsed == null
              ? null
              : (parsed.hasScheme
                  ? parsed
                  : Uri.parse('https://open.umn.edu').resolveUri(parsed));
        }
      }
    } catch (error) {
      debugPrint(
        'Zameel Library Open Textbook Library load skipped after '
        '${collected.length} books: $error',
      );
    } finally {
      client.close();
    }

    if (normalizedQuery.isEmpty) {
      _openTextbookCache = collected;
    }
    return collected.take(limit).toList();
  }

  static ZameelLibraryItem? _openTextbookItem(
    Map<String, dynamic> json,
  ) {
    final rawId = json['id']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    if (rawId.isEmpty || title.isEmpty) return null;

    final contributors = json['contributors'];
    final authorNames = <String>[];
    if (contributors is List) {
      for (final raw in contributors.whereType<Map>()) {
        final contributor = Map<String, dynamic>.from(raw);
        final isAuthor = contributor['primary'] == true ||
            contributor['contribution']?.toString() == 'Author';
        if (!isAuthor) continue;
        final name = [
          contributor['first_name'],
          contributor['middle_name'],
          contributor['last_name'],
        ]
            .map((part) => part?.toString().trim() ?? '')
            .where((part) => part.isNotEmpty)
            .join(' ');
        if (name.isNotEmpty) authorNames.add(name);
      }
    }

    final subjectNames = <String>[];
    final subjects = json['subjects'];
    if (subjects is List) {
      for (final raw in subjects.whereType<Map>()) {
        final value = raw['name']?.toString().trim() ?? '';
        if (value.isNotEmpty) subjectNames.add(value);
      }
    }

    final description = _stripHtml(
      json['description']?.toString() ?? '',
    );
    final license = json['license']?.toString().trim() ?? 'Open license';
    final category = _mapOpenTextbookCategory(
      subjectNames,
      title,
      description,
    );

    return ZameelLibraryItem(
      id: 'otl-$rawId',
      type: 'book',
      title: title,
      titleEn: title,
      category: category,
      author: authorNames.take(4).join(', '),
      description: description.isEmpty
          ? 'Open university textbook from Open Textbook Library.'
          : description,
      descriptionAr: 'كتاب جامعي مفتوح باللغة الإنجليزية من Open Textbook Library. افتح المصدر لعرض النسخة والترخيص المتاح.',
      descriptionEn: description.isEmpty
          ? 'Open university textbook from Open Textbook Library.'
          : description,
      keywords: [
        ...subjectNames,
        category,
        'Open Textbook Library',
        license,
      ],
      sourceUrl:
          'https://open.umn.edu/opentextbooks/textbooks/$rawId',
      fileUrl: _findPdfUrl(json),
      content: null,
      rightsStatus: 'Open Textbook Library • $license',
      circulationStatus: '',
      published: true,
      bundled: false,
      curated: false,
      language: 'en',
      sourceLanguage: 'en',
    );
  }

  static String _mapOpenTextbookCategory(
    List<String> subjects,
    String title,
    String description,
  ) {
    final text = '${subjects.join(' ')} $title $description'.toLowerCase();

    bool has(String value) => text.contains(value);

    // Arabic Collections Online exposes many Arabic titles through the same
    // mapper. These Arabic keywords keep those records out of one generic
    // bucket and place obvious academic subjects in the matching specialty.
    if (has('تمريض')) return 'التمريض';
    if (has('صيدل') || has('دواء') || has('ادوية') || has('أدوية')) return 'الصيدلة';
    if (has('طب الاسنان') || has('طب الأسنان')) return 'طب الأسنان';
    if (has('علم النفس') || has('نفسي')) return 'علم النفس';
    if (has('علم الاجتماع') || has('اجتماعي')) return 'علم الاجتماع والدراسات الثقافية';
    if (has('علوم سياسي') || has('سياسه') || has('سياسة') || has('سياسي')) return 'العلوم السياسية والمدنية';
    if (has('علاقات دوليه') || has('علاقات دولية') || has('دبلوماس')) return 'العلاقات الدولية';
    if (has('قانون') || has('تشريع') || has('حقوق')) return 'القانون';
    if (has('اقتصاد')) return 'الاقتصاد';
    if (has('محاسب')) return 'المحاسبة';
    if (has('ماليه') || has('مالية') || has('مصرف') || has('بنوك')) return 'المالية والمصرفية والتأمين';
    if (has('تسويق')) return 'التسويق والإعلان';
    if (has('اداره') || has('إدارة')) return 'الإدارة والأعمال';
    if (has('ذكاء اصطناعي')) return 'الذكاء الاصطناعي';
    if (has('امن سيبراني') || has('أمن سيبراني')) return 'الأمن السيبراني';
    if (has('حاسوب') || has('كمبيوتر') || has('برمجه') || has('برمجة')) return 'علم الحاسوب';
    if (has('هندسه مدنيه') || has('هندسة مدنية')) return 'الهندسة المدنية';
    if (has('هندسه كهربائي') || has('هندسة كهربائي')) return 'الهندسة الكهربائية';
    if (has('هندسه ميكاني') || has('هندسة ميكاني')) return 'الهندسة الميكانيكية';
    if (has('هندسه') || has('هندسة')) return 'هندسة الأنظمة الذكية';
    if (has('احصاء') || has('إحصاء') || has('احتمالات')) return 'الإحصاء';
    if (has('رياضيات') || has('جبر') || has('تفاضل') || has('هندسه اقليد') || has('هندسة إقليد')) return 'الرياضيات';
    if (has('فيزياء')) return 'الفيزياء';
    if (has('كيمياء')) return 'الكيمياء';
    if (has('احياء') || has('أحياء') || has('بيولوج')) return 'الأحياء';
    if (has('جيولوج') || has('علوم الارض') || has('علوم الأرض')) return 'علوم الأرض';
    if (has('بيئ')) return 'العلوم البيئية';
    if (has('زراع')) return 'الزراعة';
    if (has('تربيه') || has('تربية') || has('تعليم')) return 'القيادة التربوية';
    if (has('تاريخ') || has('اثار') || has('آثار')) return 'التاريخ والآثار';
    if (has('فلسف')) return 'الفلسفة والأخلاق';
    if (has('جغراف')) return 'الجغرافيا';
    if (has('دين') || has('اسلام') || has('إسلام') || has('لاهوت')) return 'الدراسات الدينية';
    if (has('صحاف') || has('اعلام') || has('إعلام')) return 'الصحافة والتقارير';
    if (has('ادب') || has('أدب') || has('لغه') || has('لغة') || has('لغوي')) return 'الأدب واللغويات';

    if (has('nursing')) return 'التمريض';
    if (has('nutrition')) return 'تغذية الإنسان والحميات';
    if (has('pharmac')) return 'الصيدلة';
    if (has('medicine') || has('healthcare') || has('health care')) {
      return 'دكتور في الطب';
    }
    if (has('psychology')) return 'علم النفس';
    if (has('sociology')) return 'علم الاجتماع والدراسات الثقافية';
    if (has('anthropology')) return 'علم الإنسان';
    if (has('social work')) return 'الخدمة الاجتماعية';
    if (has('criminal justice')) return 'العدالة الجنائية';
    if (has('public administration') || has('public policy')) {
      return 'إدارة وسياسة عامة';
    }
    if (has('political science') || has('politics')) {
      return 'العلوم السياسية والمدنية';
    }
    if (has('international relations')) return 'العلاقات الدولية';
    if (has('law')) return 'القانون';
    if (has('economics')) return 'الاقتصاد';
    if (has('accounting')) return 'المحاسبة';
    if (has('finance')) return 'المالية والمصرفية والتأمين';
    if (has('marketing')) return 'التسويق والإعلان';
    if (has('human resources')) return 'إدارة الموارد البشرية';
    if (has('management') || has('business')) return 'الإدارة والأعمال';
    if (has('cybersecurity') || has('information security')) {
      return 'الأمن السيبراني';
    }
    if (has('artificial intelligence') || has('machine learning')) {
      return 'الذكاء الاصطناعي';
    }
    if (has('data science')) return 'علم البيانات والإحصاء';
    if (has('statistics') || has('statistical')) return 'الإحصاء';
    if (has('programming') || has('computer science')) {
      return 'علم الحاسوب';
    }
    if (has('information systems') || has('database')) {
      return 'نظم المعلومات';
    }
    if (has('civil engineering')) return 'الهندسة المدنية';
    if (has('electrical engineering')) return 'الهندسة الكهربائية';
    if (has('mechanical engineering')) return 'الهندسة الميكانيكية';
    if (has('engineering')) return 'هندسة الأنظمة الذكية';
    if (has('mathematics') || has('calculus') || has('algebra')) {
      return 'الرياضيات';
    }
    if (has('physics')) return 'الفيزياء';
    if (has('chemistry')) return 'الكيمياء';
    if (has('biology')) return 'الأحياء';
    if (has('earth science') || has('geology')) return 'علوم الأرض';
    if (has('environment')) return 'العلوم البيئية';
    if (has('marine science') || has('oceanography')) return 'علوم البحار';
    if (has('fisheries')) return 'الثروة السمكية';
    if (has('forestry') || has('forest')) return 'الغابات والمراعي';
    if (has('agriculture') || has('farming')) return 'الزراعة';
    if (has('early childhood')) return 'تعليم الطفولة المبكرة';
    if (has('education')) return 'القيادة التربوية';
    if (has('history')) return 'التاريخ والآثار';
    if (has('philosophy')) return 'الفلسفة والأخلاق';
    if (has('geography')) return 'الجغرافيا';
    if (has('religion') || has('theology')) return 'الدراسات الدينية';
    if (has('hospitality') || has('tourism')) {
      return 'إدارة الضيافة والسياحة المستدامة';
    }
    if (has('exercise science') || has('sport')) {
      return 'علوم الحركة والرياضة التطبيقية';
    }
    if (has('journalism') || has('media') || has('communication')) {
      return 'الصحافة والتقارير';
    }
    if (has('linguistics') || has('literature') || has('language')) {
      return 'الأدب واللغويات';
    }
    if (has('music')) return 'الموسيقى والفنون الأدائية';
    if (has('art') || has('design')) return 'الفنون الجميلة';
    if (has('library science') || has('museum')) {
      return 'المكتبات والمعلومات والأرشيف';
    }
    return 'التعليم المساند';
  }

  static String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> categoriesOf(List<ZameelLibraryItem> items) {
    final categories = items
        .map((item) => item.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  static List<String> rankCategories(List<String> categories, String query) {
    final q = normalize(query);
    if (q.isEmpty) return [...categories]..sort();
    final ranked = categories
        .map((category) => MapEntry(category, _textScore(category, q)))
        .toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    return ranked.map((entry) => entry.key).toList();
  }

  static List<ZameelLibraryItem> rankItems(
    List<ZameelLibraryItem> items,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) {
      final copy = [...items];
      copy.sort((a, b) {
        if (a.curated != b.curated) return a.curated ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      return copy;
    }

    final ranked = items
        .map((item) => MapEntry(item, itemSearchScore(item, q)))
        .toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        if (a.key.curated != b.key.curated) return a.key.curated ? -1 : 1;
        return a.key.title.toLowerCase().compareTo(b.key.title.toLowerCase());
      });
    return ranked.map((entry) => entry.key).toList();
  }

  static bool hasDirectItemMatch(
    List<ZameelLibraryItem> items,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    return items.any((item) {
      final title = normalize([item.title, item.titleAr ?? '', item.titleEn ?? ''].join(' '));
      final keywords = normalize(item.keywords.join(' '));
      return title == q || title.contains(q) || keywords.contains(q);
    });
  }

  static bool hasDirectCategoryMatch(List<String> categories, String query) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    return categories.any((category) {
      final value = normalize(category);
      return value == q || value.contains(q) || q.contains(value);
    });
  }

  static double itemSearchScore(
    ZameelLibraryItem item,
    String normalizedQuery,
  ) {
    final q = normalize(normalizedQuery);
    if (q.isEmpty) return 0;
    final title = normalize([item.title, item.titleAr ?? '', item.titleEn ?? ''].join(' '));
    final category = normalize(item.category);
    final author = normalize(item.author);
    final keywords = normalize(item.keywords.join(' '));
    final description = normalize([item.description, item.descriptionAr ?? '', item.descriptionEn ?? ''].join(' '));
    final haystack = '$title $category $author $keywords $description';

    var score = 0.0;
    if (title == q) score += 2200;
    if (title.startsWith(q)) score += 1450;
    if (title.contains(q)) score += 1250;
    if (q.contains(title) && title.length > 3) score += 850;
    if (category == q) score += 800;
    if (category.contains(q)) score += 650;
    if (keywords.contains(q)) score += 600;
    if (author.contains(q)) score += 260;
    if (description.contains(q)) score += 420;
    if (haystack.contains(q)) score += 250;

    final queryTokens =
        q.split(' ').where((token) => token.length > 1).toSet();
    final docTokens =
        haystack.split(' ').where((token) => token.length > 1).toSet();
    for (final token in queryTokens) {
      if (docTokens.contains(token)) {
        score += 110;
        continue;
      }
      if (docTokens.any(
        (candidate) =>
            candidate.contains(token) || token.contains(candidate),
      )) {
        score += 55;
        continue;
      }
      final closest = docTokens.isEmpty
          ? 99
          : docTokens
              .map((candidate) => _editDistance(token, candidate))
              .reduce((a, b) => a < b ? a : b);
      if (closest == 1) score += 30;
      if (closest == 2 && token.length >= 5) score += 15;
    }

    final distance = _editDistance(q, title);
    final maxLength = math.max(q.length, title.length);
    if (maxLength > 0) {
      final similarity = 1 - (distance / maxLength);
      if (similarity > 0) score += similarity * 260;
    }
    if (item.curated) score += 20;
    return score;
  }


  static Future<String?> loadContentFor(
    ZameelLibraryItem item, {
    required bool arabic,
  }) async {
    final direct = item.contentFor(arabic);
    if (direct?.trim().isNotEmpty == true) return direct!.trim();

    final shard = item.contentShard?.trim() ?? '';
    if (shard.isEmpty) return null;

    var decoded = _contentShardCache[shard];
    if (decoded == null) {
      final raw = await rootBundle.loadString(
        'assets/zameel_library/zameel_library_content_$shard.json',
      );
      final root = jsonDecode(raw);
      if (root is! Map || root['items'] is! Map) return null;
      decoded = Map<String, dynamic>.from(root['items'] as Map);
      _contentShardCache[shard] = decoded;
    }

    final entry = decoded[item.id];
    if (entry is! Map) return null;
    final map = Map<String, dynamic>.from(entry);
    final preferred = arabic ? map['content_ar'] : map['content_en'];
    final fallback = map['content'];
    final text = preferred?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
    final fallbackText = fallback?.toString().trim();
    return fallbackText == null || fallbackText.isEmpty ? null : fallbackText;
  }

  static Future<Map<String, int>> loadDownloadCounts(
    Iterable<ZameelLibraryItem> items,
  ) async {
    final keys = items.map((item) => item.downloadKey).toSet().toList();
    if (keys.isEmpty || Supabase.instance.client.auth.currentUser == null) {
      return const {};
    }
    try {
      final rows = await Supabase.instance.client
          .from('zameel_library_download_counts')
          .select('item_key,download_count')
          .inFilter('item_key', keys)
          .timeout(const Duration(seconds: 6));
      final result = <String, int>{};
      for (final raw in rows.whereType<Map>()) {
        final key = raw['item_key']?.toString() ?? '';
        if (key.isEmpty) continue;
        result[key] = (raw['download_count'] as num?)?.toInt() ?? 0;
      }
      return result;
    } catch (error) {
      debugPrint('Zameel Library download counters unavailable: $error');
      return const {};
    }
  }

  static Future<int?> _recordDownload(ZameelLibraryItem item) async {
    if (Supabase.instance.client.auth.currentUser == null) return null;
    try {
      final value = await Supabase.instance.client
          .rpc(
            'record_zameel_library_download',
            params: {
              'target_item_key': item.downloadKey,
              'target_item_type': item.type,
            },
          )
          .timeout(const Duration(seconds: 6));
      return (value as num?)?.toInt();
    } catch (error) {
      debugPrint('Zameel Library download counter update skipped: $error');
      return null;
    }
  }

  static Future<bool> saveItemToDevice(
    ZameelLibraryItem item, {
    bool arabic = true,
  }) async {
    Uint8List? bytes;

    if (item.isSummary || item.hasDirectContent) {
      final content = await loadContentFor(item, arabic: arabic);
      if (content?.trim().isNotEmpty == true) {
        bytes = await _buildZameelPdf(
          item: item,
          text: cleanContentForReading(content!),
          arabic: arabic,
        );
      }
    }

    final gutenbergId = item.isBook ? _gutenbergId(item) : null;
    if (bytes == null && gutenbergId != null) {
      // Gutenberg text is fetched directly by the student's device and the
      // source/license text remains part of the generated personal PDF copy.
      final text = await _loadGutenbergText(gutenbergId);
      if (text != null && text.trim().isNotEmpty) {
        bytes = await _buildZameelPdf(
          item: item,
          text: text,
          arabic: _containsArabic(text),
        );
      }
    }

    if (bytes == null) {
      final pdfUrl = await resolveExternalPdfUrl(item);
      if (pdfUrl != null) {
        final response = await http
            .get(pdfUrl)
            .timeout(const Duration(seconds: 35));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!_looksLikePdf(response.bodyBytes)) {
            throw Exception('source_did_not_return_pdf');
          }
          bytes = response.bodyBytes;
        } else {
          throw Exception('download_failed_${response.statusCode}');
        }
      }
    }

    if (bytes == null || bytes.isEmpty) return false;

    final path = await FilePicker.saveFile(
      dialogTitle: 'Zameel Library PDF',
      fileName: '${_safeFileName(item.titleFor(arabic))}.pdf',
      bytes: bytes,
    );
    if (path == null) return false;
    await _recordDownload(item);
    return true;
  }

  static Future<Uri?> resolveExternalPdfUrl(
    ZameelLibraryItem item,
  ) async {
    final direct = item.fileUrl?.trim() ?? '';
    if (direct.isNotEmpty) {
      final uri = Uri.tryParse(direct);
      if (uri != null) return uri;
    }

    final source = item.sourceUrl?.trim() ?? '';
    if (source.isEmpty) return null;

    if (source.contains('open.umn.edu/opentextbooks/textbooks/')) {
      final parsedSource = Uri.tryParse(source);
      final segments = parsedSource?.pathSegments
              .where((segment) => segment.trim().isNotEmpty)
              .toList() ??
          const <String>[];
      final id = segments.isEmpty ? '' : segments.last;
      if (id.isNotEmpty) {
        try {
          final uri = Uri.parse(
            'https://open.umn.edu/opentextbooks/textbooks/$id.json',
          );
          final response =
              await http.get(uri).timeout(const Duration(seconds: 12));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final decoded = jsonDecode(response.body);
            final found = _findPdfUrl(decoded);
            if (found != null) return Uri.tryParse(found);
          }
        } catch (error) {
          debugPrint('OTL PDF lookup skipped: $error');
        }
      }
    }

    if (source.contains('sites.dlib.nyu.edu/viewer/api/embed/')) {
      try {
        final response = await http
            .get(Uri.parse(source))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final absoluteMatches = RegExp(
            r'https?://[^" <]+[.]pdf[^" <]*',
            caseSensitive: false,
          ).allMatches(response.body);
          final relativeMatches = RegExp(
            r'href="([^"]+[.]pdf[^"]*)"',
            caseSensitive: false,
          ).allMatches(response.body);
          final candidates = <String>[
            ...absoluteMatches.map((match) => match.group(0)).whereType<String>(),
            ...relativeMatches.map((match) => match.group(1)).whereType<String>(),
          ];
          if (candidates.isNotEmpty) {
            final preferred = candidates.firstWhere(
              (url) => url.toLowerCase().contains('low'),
              orElse: () => candidates.first,
            );
            final parsed = Uri.tryParse(preferred);
            if (parsed != null) {
              return parsed.hasScheme
                  ? parsed
                  : Uri.parse(source).resolveUri(parsed);
            }
          }
        }
      } catch (error) {
        debugPrint('ACO PDF lookup skipped: $error');
      }
    }

    return null;
  }

  static bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  static String? _findPdfUrl(dynamic node) {
    if (node is String) {
      final value = node.trim();
      if (value.startsWith('http') &&
          (value.toLowerCase().contains('.pdf') ||
              value.toLowerCase().contains('format=pdf'))) {
        return value;
      }
      return null;
    }
    if (node is List) {
      for (final entry in node) {
        final found = _findPdfUrl(entry);
        if (found != null) return found;
      }
      return null;
    }
    if (node is Map) {
      final format = node['format']?.toString().toLowerCase() ?? '';
      if (format == 'pdf') {
        for (final key in const ['url', 'uri', 'href', 'download_url']) {
          final value = node[key]?.toString().trim() ?? '';
          if (value.startsWith('http')) return value;
        }
      }
      for (final entry in node.values) {
        final found = _findPdfUrl(entry);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _gutenbergId(ZameelLibraryItem item) {
    final source = item.sourceUrl?.trim() ?? '';
    final match =
        RegExp(r'gutenberg[.]org/ebooks/(\d+)', caseSensitive: false)
            .firstMatch(source);
    return match?.group(1);
  }

  static Future<String?> _loadGutenbergText(String id) async {
    final candidates = <Uri>[
      Uri.parse('https://www.gutenberg.org/cache/epub/$id/pg$id.txt'),
      Uri.parse('https://www.gutenberg.org/files/$id/$id-8.txt'),
      Uri.parse('https://www.gutenberg.org/files/$id/$id.txt'),
    ];
    for (final uri in candidates) {
      try {
        final response =
            await http.get(uri).timeout(const Duration(seconds: 20));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final text = utf8.decode(response.bodyBytes, allowMalformed: true);
          if (text.trim().length > 200) return text.trim();
        }
      } catch (_) {
        // Try the next source endpoint.
      }
    }
    return null;
  }

  static bool _containsArabic(String text) =>
      RegExp(r'[\u0600-\u06ff]').hasMatch(text);

  static Future<Uint8List> _buildZameelPdf({
    required ZameelLibraryItem item,
    required String text,
    required bool arabic,
  }) async {
    if (arabic || _containsArabic(text)) {
      return _buildRasterizedPdf(
        title: item.titleFor(arabic),
        text: text,
        rtl: true,
      );
    }
    return _buildTextPdf(
      title: item.titleFor(false),
      author: item.author,
      text: text,
    );
  }

  static Future<Uint8List> _buildTextPdf({
    required String title,
    required String author,
    required String text,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? watermark;
    try {
      final logo = await rootBundle.load('assets/branding/zameel_mark.png');
      watermark = pw.MemoryImage(logo.buffer.asUint8List());
    } catch (_) {
      watermark = null;
    }

    final safeText = _latinPdfSafe(text);
    final chunks = <String>[];
    const chunkSize = 2800;
    for (var start = 0; start < safeText.length; start += chunkSize) {
      chunks.add(
        safeText.substring(
          start,
          math.min(start + chunkSize, safeText.length),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(42, 48, 42, 48),
          buildBackground: watermark == null
              ? null
              : (context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Center(
                      child: pw.Opacity(
                        opacity: 0.055,
                        child: pw.Image(watermark!, width: 210),
                      ),
                    ),
                  ),
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (author.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(author, style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 14),
          ...chunks.map(
            (chunk) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                chunk,
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3),
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static String _latinPdfSafe(String value) {
    return value
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .replaceAll('•', '-');
  }

  static Future<Uint8List> _buildRasterizedPdf({
    required String title,
    required String text,
    required bool rtl,
  }) async {
    const width = 1240.0;
    const height = 1754.0;
    const margin = 92.0;
    const bodyTopFirst = 230.0;
    const bodyTopLater = 120.0;
    const bottom = 100.0;
    final direction = rtl ? TextDirection.rtl : TextDirection.ltr;
    final bodyStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 27,
      height: 1.55,
    );
    final titleStyle = const TextStyle(
      color: Colors.black,
      fontSize: 39,
      fontWeight: FontWeight.w800,
      height: 1.35,
    );

    ui.Image? logo;
    try {
      final data = await rootBundle.load('assets/branding/zameel_mark.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      logo = frame.image;
      codec.dispose();
    } catch (_) {
      logo = null;
    }

    final chunks = <String>[];
    var remaining = text.trim();
    var first = true;
    while (remaining.isNotEmpty) {
      final availableHeight =
          height - (first ? bodyTopFirst : bodyTopLater) - bottom;
      final cut = _fitTextLength(
        remaining,
        maxWidth: width - margin * 2,
        maxHeight: availableHeight,
        style: bodyStyle,
        direction: direction,
      );
      var end = math.max(1, cut);
      if (end < remaining.length) {
        final searchStart = math.max(0, (end * .72).floor());
        final before = remaining.substring(0, end);
        final match = RegExp(r'\s+\S*$').firstMatch(before);
        final candidate = match?.start ?? -1;
        if (candidate >= searchStart) end = candidate + 1;
      }
      chunks.add(remaining.substring(0, end).trim());
      remaining = remaining.substring(end).trimLeft();
      first = false;
      if (chunks.length > 800) break;
    }

    final doc = pw.Document();
    for (var index = 0; index < chunks.length; index++) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()..color = Colors.white,
      );

      if (logo != null) {
        const logoSize = 360.0;
        final rect = ui.Rect.fromLTWH(
          (width - logoSize) / 2,
          (height - logoSize) / 2,
          logoSize,
          logoSize,
        );
        canvas.drawImageRect(
          logo,
          ui.Rect.fromLTWH(
            0,
            0,
            logo.width.toDouble(),
            logo.height.toDouble(),
          ),
          rect,
          ui.Paint()..color = const Color(0x16000000),
        );
      }

      final brandPainter = TextPainter(
        text: const TextSpan(
          text: 'Zameel',
          style: TextStyle(
            color: Color(0x553B8D86),
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      brandPainter.paint(canvas, const Offset(margin, 46));

      if (index == 0) {
        final titlePainter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: direction,
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: width - margin * 2);
        titlePainter.paint(
          canvas,
          Offset(
            rtl ? width - margin - titlePainter.width : margin,
            105,
          ),
        );
      }

      final bodyPainter = TextPainter(
        text: TextSpan(text: chunks[index], style: bodyStyle),
        textDirection: direction,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
      )..layout(maxWidth: width - margin * 2);
      final top = index == 0 ? bodyTopFirst : bodyTopLater;
      bodyPainter.paint(
        canvas,
        Offset(
          rtl ? width - margin - bodyPainter.width : margin,
          top,
        ),
      );

      final pagePainter = TextPainter(
        text: TextSpan(
          text: '${index + 1}/${chunks.length}',
          style: const TextStyle(color: Colors.black45, fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pagePainter.paint(
        canvas,
        Offset((width - pagePainter.width) / 2, height - 58),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) continue;
      final png = data.buffer.asUint8List();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(
              pw.MemoryImage(png),
              fit: pw.BoxFit.fill,
            ),
          ),
        ),
      );
    }
    return doc.save();
  }

  static int _fitTextLength(
    String text, {
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    required TextDirection direction,
  }) {
    if (text.isEmpty) return 0;
    var low = 1;
    var high = math.min(text.length, 9000);
    var best = 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final painter = TextPainter(
        text: TextSpan(text: text.substring(0, mid), style: style),
        textDirection: direction,
      )..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  static Future<bool> openSource(ZameelLibraryItem item) async {
    final raw = item.sourceUrl?.trim() ?? '';
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String cleanContentForReading(String value) {
    return value
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
        .trim();
  }

  static String normalize(String value) {
    var text = value.toLowerCase().trim();
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    text = text
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');
    text = text.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static double _textScore(String value, String normalizedQuery) {
    final text = normalize(value);
    final q = normalize(normalizedQuery);
    if (text == q) return 2000;
    var score = 0.0;
    if (text.startsWith(q)) score += 1200;
    if (text.contains(q)) score += 1000;
    if (q.contains(text) && text.length > 2) score += 650;
    for (final token in q.split(' ').where((token) => token.length > 1)) {
      if (text.split(' ').contains(token)) score += 130;
      if (text.contains(token)) score += 75;
    }
    final distance = _editDistance(q, text);
    final maxLength = math.max(q.length, text.length);
    if (maxLength > 0) score += math.max(0.0, 1 - distance / maxLength).toDouble() * 300;
    return score;
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }

  static String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'Zameel_Library_Item' : 'Zameel_$cleaned';
  }

}
