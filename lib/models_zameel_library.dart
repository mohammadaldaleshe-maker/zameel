class ZameelLibraryItem {
  final String id;
  final String type;
  final String title;
  final String category;
  final String author;
  final String description;
  final List<String> keywords;
  final String? sourceUrl;
  final String? fileUrl;
  final String? content;
  final String rightsStatus;
  final String circulationStatus;
  final bool published;
  final bool bundled;
  final bool curated;
  final String? titleAr;
  final String? titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? contentAr;
  final String? contentEn;
  final String language;
  final String sourceLanguage;
  final String? contentShard;
  final bool hasBundledContent;

  const ZameelLibraryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.author,
    required this.description,
    required this.keywords,
    required this.sourceUrl,
    required this.fileUrl,
    required this.content,
    required this.rightsStatus,
    required this.circulationStatus,
    required this.published,
    required this.bundled,
    this.curated = false,
    this.titleAr,
    this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.contentAr,
    this.contentEn,
    this.language = '',
    this.sourceLanguage = '',
    this.contentShard,
    this.hasBundledContent = false,
  });

  bool get isBook => type == 'book';
  bool get isSummary => type == 'summary';
  bool get hasDirectContent =>
      hasBundledContent ||
      content?.trim().isNotEmpty == true ||
      contentAr?.trim().isNotEmpty == true ||
      contentEn?.trim().isNotEmpty == true;
  String get downloadKey => '$type:$id';
  bool get hasFileUrl => fileUrl?.trim().isNotEmpty == true;
  bool get hasSourceUrl => sourceUrl?.trim().isNotEmpty == true;

  String titleFor(bool arabic) {
    final preferred = arabic ? titleAr : titleEn;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return title;
  }

  String descriptionFor(bool arabic) {
    final preferred = arabic ? descriptionAr : descriptionEn;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return description;
  }

  String? contentFor(bool arabic) {
    final preferred = arabic ? contentAr : contentEn;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return content?.trim().isNotEmpty == true ? content!.trim() : null;
  }

  factory ZameelLibraryItem.fromSeed(Map<String, dynamic> json) {
    return ZameelLibraryItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'summary',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      keywords: _stringList(json['keywords']),
      sourceUrl: _nullableString(json['source_url']),
      fileUrl: _nullableString(json['file_url']),
      content: _nullableString(json['content']),
      rightsStatus: json['rights_status']?.toString() ?? '',
      circulationStatus: json['circulation_status']?.toString() ?? '',
      published: json['published'] == true,
      bundled: json['bundled'] != false,
      curated: json['curated'] == true,
      titleAr: _nullableString(json['title_ar']),
      titleEn: _nullableString(json['title_en']),
      descriptionAr: _nullableString(json['description_ar']),
      descriptionEn: _nullableString(json['description_en']),
      contentAr: _nullableString(json['content_ar']),
      contentEn: _nullableString(json['content_en']),
      language: json['language']?.toString() ?? '',
      sourceLanguage: json['source_language']?.toString() ?? '',
      contentShard: _nullableString(json['content_shard']),
      hasBundledContent: json['has_bundled_content'] == true,
    );
  }

  factory ZameelLibraryItem.fromRemote(Map<String, dynamic> json) {
    return ZameelLibraryItem(
      id: json['id']?.toString() ?? '',
      type: json['item_type']?.toString() ?? 'summary',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      keywords: _stringList(json['keywords']),
      sourceUrl: _nullableString(json['source_url']),
      fileUrl: _nullableString(json['file_url']),
      content: _nullableString(json['content_text']),
      rightsStatus: json['rights_status']?.toString() ?? '',
      circulationStatus: json['circulation_status']?.toString() ?? '',
      published: json['is_published'] == true,
      bundled: false,
      curated: json['is_featured'] == true,
      titleAr: _nullableString(json['title_ar']),
      titleEn: _nullableString(json['title_en']),
      descriptionAr: _nullableString(json['description_ar']),
      descriptionEn: _nullableString(json['description_en']),
      contentAr: _nullableString(json['content_ar']),
      contentEn: _nullableString(json['content_en']),
      language: json['language']?.toString() ?? '',
      sourceLanguage: json['source_language']?.toString() ?? '',
      contentShard: _nullableString(json['content_shard']),
      hasBundledContent: json['has_bundled_content'] == true,
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'[,،\n]'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
}

class ZameelLibrarySpecialty {
  final String name;
  final String nameEn;
  final List<String> aliases;

  const ZameelLibrarySpecialty({
    required this.name,
    this.nameEn = '',
    this.aliases = const [],
  });

  factory ZameelLibrarySpecialty.fromJson(Map<String, dynamic> json) {
    return ZameelLibrarySpecialty(
      name: json['name']?.toString().trim() ?? '',
      nameEn: json['name_en']?.toString().trim() ?? '',
      aliases: ZameelLibraryItem._stringList(json['aliases']),
    );
  }

  String labelFor(bool arabic) {
    if (!arabic && nameEn.isNotEmpty) return nameEn;
    return name;
  }

  Iterable<String> get searchableNames sync* {
    yield name;
    if (nameEn.isNotEmpty) yield nameEn;
    yield* aliases;
  }
}

class ZameelLibrarySpecialtyGroup {
  final String name;
  final String nameEn;
  final List<ZameelLibrarySpecialty> specialties;

  const ZameelLibrarySpecialtyGroup({
    required this.name,
    this.nameEn = '',
    required this.specialties,
  });

  factory ZameelLibrarySpecialtyGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['specialties'];
    return ZameelLibrarySpecialtyGroup(
      name: json['name']?.toString().trim() ?? '',
      nameEn: json['name_en']?.toString().trim() ?? '',
      specialties: raw is List
          ? raw
              .whereType<Map>()
              .map((entry) => ZameelLibrarySpecialty.fromJson(
                    Map<String, dynamic>.from(entry),
                  ))
              .where((entry) => entry.name.isNotEmpty)
              .toList()
          : const [],
    );
  }

  String labelFor(bool arabic) {
    if (!arabic && nameEn.isNotEmpty) return nameEn;
    return name;
  }
}
