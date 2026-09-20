import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models_zameel_library.dart';
import '../../providers/language_provider.dart';
import '../../services/zameel_library_service.dart';
import '../../theme/app_theme.dart';

class ZameelLibraryScreen extends StatefulWidget {
  const ZameelLibraryScreen({super.key});

  @override
  State<ZameelLibraryScreen> createState() => _ZameelLibraryScreenState();
}

class _ZameelLibraryScreenState extends State<ZameelLibraryScreen> {
  final _search = TextEditingController();
  List<ZameelLibrarySpecialtyGroup> _groups = const [];
  Map<String, dynamic> _manifest = const {};
  final Set<int> _expandedGroups = <int>{};
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        ZameelLibraryService.loadSpecialtyGroups(),
        ZameelLibraryService.loadManifest(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = values[0] as List<ZameelLibrarySpecialtyGroup>;
        _manifest = Map<String, dynamic>.from(values[1] as Map);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح مكتبة زميل: $error')),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _manifestInt(String key) => (_manifest[key] as num?)?.toInt() ?? 0;

  Map<String, int> _countForSpecialty(ZameelLibrarySpecialty specialty) {
    final categories = _manifest['categories'];
    var books = 0;
    var summaries = 0;
    if (categories is Map) {
      final seen = <String>{};
      for (final name in specialty.searchableNames) {
        if (!seen.add(name)) continue;
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

  int _groupTotal(ZameelLibrarySpecialtyGroup group) {
    var total = 0;
    for (final specialty in group.specialties) {
      total += _countForSpecialty(specialty)['total'] ?? 0;
    }
    return total;
  }

  Widget _specialtyTile(
    BuildContext context,
    bool ar,
    ZameelLibrarySpecialty specialty,
  ) {
    final counts = _countForSpecialty(specialty);
    final books = counts['books'] ?? 0;
    final summaries = counts['summaries'] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryLight,
            child: Icon(
              _categoryIcon(specialty.name),
              color: AppTheme.primaryDark,
            ),
          ),
          title: Text(
            specialty.labelFor(ar),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            ar
                ? '$books كتب مفهرسة • $summaries ملخصات'
                : '$books indexed books • $summaries summaries',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ZameelLibraryCategoryScreen(
                specialty: specialty,
                categoryLabel: specialty.labelFor(ar),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final allSpecialties = ZameelLibraryService.allSpecialties(_groups);
    final rankedSpecialties =
        ZameelLibraryService.rankSpecialties(allSpecialties, _query);
    final direct = ZameelLibraryService.hasDirectSpecialtyMatch(
      allSpecialties,
      _query,
    );
    final searchedSpecialties = rankedSpecialties.take(30).toList();
    final bundledBooks = _manifestInt('books_published');
    final summaries = _manifestInt('summaries_total');
    final targetBooks = _manifestInt('open_textbook_target');

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_library_rounded, color: AppTheme.primary),
              const SizedBox(width: 9),
              Text(ar ? 'مكتبة زميل' : 'Zameel Library'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.signatureGradientRtl,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .17),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.local_library_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ar
                                      ? 'المعرفة الجامعية في مكان واحد'
                                      : 'University knowledge in one place',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  ar
                                      ? '$bundledBooks كتاباً مفهرساً • $summaries ملخصاً • ${allSpecialties.length} تخصصاً'
                                      : '$bundledBooks indexed books • $summaries summaries • ${allSpecialties.length} subjects',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ar
                                  ? 'تفتح المكتبة الآن من الفهرس الخفيف فقط. يتم تحميل محتوى التخصص وملفات PDF عند الطلب، والكتب المفتوحة الإضافية حتى $targetBooks كتاب تُجلب على دفعات صغيرة دون تجميد الصفحة.'
                                  : 'The library now opens from a lightweight index. Subject content and PDFs load only when requested, while additional open books up to $targetBooks are fetched in small background batches.',
                              style: const TextStyle(
                                fontSize: 12.2,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: ar
                            ? 'ابحث عن تخصص: قانون، طب، هندسة، سياسة...'
                            : 'Search subjects: law, medicine, engineering...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    if (_query.trim().isNotEmpty && !direct) ...[
                      const SizedBox(height: 10),
                      _SuggestionBanner(
                        text: ar
                            ? 'لم نجد اسماً مطابقاً؛ هذه أقرب التخصصات إلى بحثك.'
                            : 'No exact subject match; these are the closest subjects.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      ar ? 'فهرس التخصصات' : 'Subjects index',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_query.trim().isNotEmpty)
                      if (searchedSpecialties.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50),
                          child: Center(
                            child: Text(
                              ar
                                  ? 'لا توجد تخصصات قريبة من البحث'
                                  : 'No close subjects found',
                            ),
                          ),
                        )
                      else
                        ...searchedSpecialties.map(
                          (specialty) => _specialtyTile(context, ar, specialty),
                        )
                    else
                      ...List.generate(_groups.length, (index) {
                        final group = _groups[index];
                        final expanded = _expandedGroups.contains(index);
                        final totalItems = _groupTotal(group);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ExpansionTile(
                              key: PageStorageKey('zameel-library-group-$index'),
                              initiallyExpanded: expanded,
                              onExpansionChanged: (value) {
                                setState(() {
                                  if (value) {
                                    _expandedGroups.add(index);
                                  } else {
                                    _expandedGroups.remove(index);
                                  }
                                });
                              },
                              leading: const Icon(
                                Icons.folder_copy_rounded,
                                color: AppTheme.primary,
                              ),
                              title: Text(
                                group.labelFor(ar),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                ar
                                    ? '${group.specialties.length} تخصصاً • $totalItems مادة مفهرسة'
                                    : '${group.specialties.length} subjects • $totalItems indexed items',
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              children: expanded
                                  ? group.specialties
                                      .map(
                                        (specialty) =>
                                            _specialtyTile(context, ar, specialty),
                                      )
                                      .toList()
                                  : const [SizedBox.shrink()],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class ZameelLibraryCategoryScreen extends StatefulWidget {
  final ZameelLibrarySpecialty specialty;
  final String categoryLabel;

  const ZameelLibraryCategoryScreen({
    super.key,
    required this.specialty,
    required this.categoryLabel,
  });

  @override
  State<ZameelLibraryCategoryScreen> createState() =>
      _ZameelLibraryCategoryScreenState();
}

class _ZameelLibraryCategoryScreenState
    extends State<ZameelLibraryCategoryScreen> {
  final _search = TextEditingController();
  List<ZameelLibraryItem> _items = const [];
  Map<String, int> _downloadCounts = const {};
  bool _loading = true;
  bool _loadingRemote = false;
  String _query = '';
  String _type = 'all';
  int _visibleLimit = 40;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    if (mounted) setState(() => _loading = true);
    try {
      final local = await ZameelLibraryService.loadBundledItemsForSpecialty(
        widget.specialty,
      );
      if (!mounted) return;
      setState(() {
        _items = local;
        _loading = false;
        _visibleLimit = 40;
      });
      await _loadCounts(local.take(80));
      _loadRemote();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل محتوى التخصص: $error')),
      );
    }
  }

  Future<void> _loadRemote() async {
    if (_loadingRemote) return;
    if (mounted) setState(() => _loadingRemote = true);
    try {
      final values = await Future.wait([
        ZameelLibraryService.loadRemoteItemsForSpecialty(widget.specialty),
        ZameelLibraryService.loadOpenBooksForSpecialty(
          widget.specialty,
          limit: 24,
        ),
      ]);
      final merged = <String, ZameelLibraryItem>{
        for (final item in _items) item.downloadKey: item,
      };
      for (final list in values) {
        for (final item in list) {
          merged[item.downloadKey] = item;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = merged.values.toList();
        _loadingRemote = false;
      });
      await _loadCounts(_items.take(120));
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingRemote = false);
      debugPrint('Zameel Library background load skipped: $error');
    }
  }

  Future<void> _refresh() async {
    await _loadLocal();
  }

  Future<void> _loadCounts(Iterable<ZameelLibraryItem> items) async {
    final counts = await ZameelLibraryService.loadDownloadCounts(items);
    if (!mounted || counts.isEmpty) return;
    setState(() {
      _downloadCounts = {..._downloadCounts, ...counts};
    });
  }

  Future<void> _download(ZameelLibraryItem item, bool ar) async {
    try {
      final saved = await ZameelLibraryService.saveItemToDevice(
        item,
        arabic: ar,
      );
      if (!mounted) return;
      if (saved) {
        await _loadCounts([item]);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? (ar ? '✅ تم تنزيل PDF' : '✅ PDF downloaded')
                : (ar
                    ? 'تعذر إنشاء PDF مباشر. افتح التفاصيل للوصول إلى المصدر.'
                    : 'A direct PDF was not available. Open details to access the source.'),
          ),
          backgroundColor: saved ? AppTheme.success : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ar ? 'تعذر تنزيل PDF' : 'Could not download PDF'}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final typed = _items.where((item) {
      if (_type == 'book') return item.isBook;
      if (_type == 'summary') return item.isSummary;
      return true;
    }).toList();
    final ranked = ZameelLibraryService.rankItems(typed, _query);
    final direct = ZameelLibraryService.hasDirectItemMatch(typed, _query);
    final maxVisible = _query.trim().isEmpty
        ? math.min(_visibleLimit, ranked.length)
        : math.min(80, ranked.length);
    final visible = ranked.take(maxVisible).toList();

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.categoryLabel)),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _visibleLimit = 40;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: ar
                        ? 'ابحث عن كتاب، ملخص أو أقرب موضوع...'
                        : 'Search for a book, summary or closest topic...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _query = '';
                                _visibleLimit = 40;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'all',
                        icon: const Icon(Icons.auto_stories_rounded),
                        label: Text(ar ? 'الكل' : 'All'),
                      ),
                      ButtonSegment(
                        value: 'book',
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(ar ? 'كتب PDF' : 'PDF books'),
                      ),
                      ButtonSegment(
                        value: 'summary',
                        icon: const Icon(Icons.description_rounded),
                        label: Text(ar ? 'ملخصات PDF' : 'PDF summaries'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (value) {
                      setState(() {
                        _type = value.first;
                        _visibleLimit = 40;
                      });
                    },
                  ),
                ),
              ),
              if (_loadingRemote)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ar
                              ? 'يتم إضافة دفعة صغيرة من كتب PDF المفتوحة في الخلفية...'
                              : 'Adding a small batch of open PDF books in the background...',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_query.trim().isNotEmpty && !direct)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
                  child: _SuggestionBanner(
                    text: ar
                        ? 'لم نجد نفس الاسم؛ رتّبنا لك أقرب النتائج إلى موضوع بحثك.'
                        : 'No exact title found; results are ranked by topic similarity.',
                  ),
                ),
              const SizedBox(height: 7),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * .25,
                              ),
                              Center(
                                child: Text(
                                  ar
                                      ? 'لا يوجد محتوى في هذا القسم بعد'
                                      : 'No content here yet',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: visible.length +
                                ((_query.trim().isEmpty &&
                                        maxVisible < ranked.length)
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (index >= visible.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() => _visibleLimit += 40);
                                      _loadCounts(
                                        ranked.take(_visibleLimit),
                                      );
                                    },
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: Text(
                                      ar ? 'تحميل المزيد' : 'Load more',
                                    ),
                                  ),
                                );
                              }
                              final item = visible[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: _LibraryItemCard(
                                  item: item,
                                  ar: ar,
                                  downloadCount:
                                      _downloadCounts[item.downloadKey] ?? 0,
                                  onDownload: () => _download(item, ar),
                                  onOpen: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ZameelLibraryDetailsScreen(
                                          item: item,
                                        ),
                                      ),
                                    );
                                    await _loadCounts([item]);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ZameelLibraryDetailsScreen extends StatefulWidget {
  final ZameelLibraryItem item;

  const ZameelLibraryDetailsScreen({super.key, required this.item});

  @override
  State<ZameelLibraryDetailsScreen> createState() =>
      _ZameelLibraryDetailsScreenState();
}

class _ZameelLibraryDetailsScreenState
    extends State<ZameelLibraryDetailsScreen> {
  String? _content;
  bool _loadingContent = false;
  bool _downloading = false;
  int _downloadCount = 0;

  ZameelLibraryItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final counts = await ZameelLibraryService.loadDownloadCounts([item]);
    if (mounted) {
      setState(() => _downloadCount = counts[item.downloadKey] ?? 0);
    }
    if (item.isSummary || item.hasDirectContent) {
      if (mounted) setState(() => _loadingContent = true);
      final content = await ZameelLibraryService.loadContentFor(
        item,
        arabic: ar,
      );
      if (mounted) {
        setState(() {
          _content = content;
          _loadingContent = false;
        });
      }
    }
  }

  Future<void> _downloadPdf(BuildContext context, bool ar) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final saved = await ZameelLibraryService.saveItemToDevice(
        item,
        arabic: ar,
      );
      if (!mounted) return;
      if (saved) {
        final counts = await ZameelLibraryService.loadDownloadCounts([item]);
        if (mounted) {
          setState(() => _downloadCount =
              counts[item.downloadKey] ?? (_downloadCount + 1));
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ar ? '✅ تم تنزيل PDF' : '✅ PDF downloaded'),
            backgroundColor: AppTheme.success,
          ),
        );
        return;
      }

      final opened = await ZameelLibraryService.openSource(item);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? (ar
                    ? 'لم تتوفر نسخة PDF مباشرة؛ تم فتح المصدر الأصلي.'
                    : 'A direct PDF was unavailable; the original source was opened.')
                : (ar
                    ? 'تعذر تنزيل PDF أو فتح المصدر.'
                    : 'Could not download a PDF or open the source.'),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ar ? 'تعذر تنزيل PDF' : 'PDF download failed'}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final readable = (_content ?? '').trim().isEmpty
        ? ''
        : ZameelLibraryService.cleanContentForReading(_content!);

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            item.isBook
                ? (ar ? 'تفاصيل الكتاب' : 'Book details')
                : (ar ? 'تفاصيل الملخص' : 'Summary details'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Center(
              child: CircleAvatar(
                radius: 35,
                backgroundColor:
                    item.isBook ? AppTheme.primaryLight : AppTheme.accentSoft,
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 34,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.titleFor(ar),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                Chip(label: Text(item.category)),
                Chip(
                  avatar: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                  label: Text(
                    item.isBook
                        ? (ar ? 'كتاب PDF' : 'PDF book')
                        : (ar ? 'ملخص PDF' : 'PDF summary'),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.download_rounded, size: 17),
                  label: Text(
                    ar
                        ? '$_downloadCount تحميل'
                        : '$_downloadCount downloads',
                  ),
                ),
                if (item.curated)
                  Chip(label: Text(ar ? 'مختار من زميل' : 'Zameel curated')),
              ],
            ),
            if (item.author.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${ar ? 'المؤلف/الجهة' : 'Author/source'}: ${item.author}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 18),
            _SectionCard(
              title: ar ? 'نبذة' : 'About',
              child: Text(
                item.descriptionFor(ar).trim().isEmpty
                    ? (ar ? 'لا توجد نبذة إضافية.' : 'No additional description.')
                    : item.descriptionFor(ar),
                style: const TextStyle(height: 1.55),
              ),
            ),
            if (item.keywords.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionCard(
                title: ar ? 'موضوعات مرتبطة' : 'Related topics',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.keywords
                      .where((entry) => entry.trim().isNotEmpty)
                      .take(8)
                      .map((entry) => Chip(label: Text(entry)))
                      .toList(),
                ),
              ),
            ],
            if (_loadingContent) ...[
              const SizedBox(height: 10),
              const Center(child: CircularProgressIndicator()),
            ] else if (readable.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionCard(
                title: ar ? 'معاينة المحتوى' : 'Content preview',
                child: SelectableText(
                  readable,
                  style: const TextStyle(height: 1.7),
                ),
              ),
            ],
            if (item.isBook) ...[
              const SizedBox(height: 10),
              _SectionCard(
                title: ar ? 'المصدر والترخيص' : 'Source & license',
                child: Text(
                  item.rightsStatus.trim().isEmpty
                      ? (ar
                          ? 'يتم تنزيل الكتب من المصدر المفتوح بصيغة PDF عند توفرها. ملفات المصدر الخارجي تبقى كما نشرها المصدر، بينما ملفات زميل المولدة تحمل علامة زميل المائية.'
                          : 'Books are downloaded from the open source as PDF when available. External-source PDFs remain as published by their source, while Zameel-generated PDFs carry the Zameel watermark.')
                      : item.rightsStatus,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _downloading ? null : () => _downloadPdf(context, ar),
              icon: _downloading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _downloading
                    ? (ar ? 'جاري تجهيز PDF...' : 'Preparing PDF...')
                    : (ar ? 'تحميل PDF' : 'Download PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  final ZameelLibraryItem item;
  final bool ar;
  final int downloadCount;
  final VoidCallback onOpen;
  final Future<void> Function() onDownload;

  const _LibraryItemCard({
    required this.item,
    required this.ar,
    required this.downloadCount,
    required this.onOpen,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    item.isBook ? AppTheme.primaryLight : AppTheme.accentSoft,
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.titleFor(ar),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (item.curated)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 5),
                            child: Icon(
                              Icons.verified_rounded,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    if (item.author.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.descriptionFor(ar).trim().isEmpty
                          ? (ar
                              ? 'محتوى جامعي من مكتبة زميل'
                              : 'University content from Zameel Library')
                          : item.descriptionFor(ar),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.isBook
                                ? AppTheme.primaryLight
                                : AppTheme.accentSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            item.isBook
                                ? (ar ? 'كتاب PDF' : 'PDF book')
                                : (ar ? 'ملخص PDF' : 'PDF summary'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.download_rounded, size: 15),
                          label: Text(
                            ar
                                ? '$downloadCount تحميل'
                                : '$downloadCount downloads',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onDownload,
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 18,
                          ),
                          label: Text(ar ? 'تحميل PDF' : 'Download PDF'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionBanner extends StatelessWidget {
  final String text;
  const _SuggestionBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  if (category.contains('قانون')) return Icons.gavel_rounded;
  if (category.contains('سياس') ||
      category.contains('علاقات') ||
      category.contains('دبلوما')) {
    return Icons.public_rounded;
  }
  if (category.contains('أمن') || category.contains('السلام')) {
    return Icons.shield_rounded;
  }
  if (category.contains('حاسوب') ||
      category.contains('برمج') ||
      category.contains('ذكاء') ||
      category.contains('معلومات')) {
    return Icons.computer_rounded;
  }
  if (category.contains('هندسة') || category.contains('عمارة')) {
    return Icons.engineering_rounded;
  }
  if (category.contains('طب') ||
      category.contains('تمريض') ||
      category.contains('صيدلة') ||
      category.contains('صحة') ||
      category.contains('تغذية')) {
    return Icons.medical_services_rounded;
  }
  if (category.contains('اقتصاد') ||
      category.contains('أعمال') ||
      category.contains('محاسبة') ||
      category.contains('تمويل') ||
      category.contains('تسويق')) {
    return Icons.business_center_rounded;
  }
  if (category.contains('رياضيات') || category.contains('إحصاء')) {
    return Icons.calculate_rounded;
  }
  if (category.contains('فيزياء') ||
      category.contains('كيمياء') ||
      category.contains('أحياء') ||
      category.contains('جيولوج')) {
    return Icons.science_rounded;
  }
  if (category.contains('لغة') || category.contains('أدب')) {
    return Icons.translate_rounded;
  }
  if (category.contains('تاريخ') || category.contains('جغراف')) {
    return Icons.travel_explore_rounded;
  }
  if (category.contains('نفس') || category.contains('اجتماع')) {
    return Icons.groups_rounded;
  }
  return Icons.local_library_rounded;
}
