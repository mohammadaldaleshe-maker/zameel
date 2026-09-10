import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:page_flip/page_flip.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';

class GraduationBookScreen extends StatefulWidget {
  final String? ownerId;
  final String? bookId;
  final String? inviteToken;
  final String studentName;
  final String university;
  final String major;
  final String graduationYear;

  const GraduationBookScreen({
    super.key,
    this.ownerId,
    this.bookId,
    this.inviteToken,
    this.studentName = 'طالب زميل',
    this.university = '',
    this.major = '',
    this.graduationYear = '',
  });

  @override
  State<GraduationBookScreen> createState() => _GraduationBookScreenState();
}

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.value,
        'width': width,
      };

  factory _Stroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List?) ?? const [];
    return _Stroke(
      points: rawPoints.whereType<Map>().map((point) {
        final p = Map<String, dynamic>.from(point);
        return Offset(
          (p['x'] as num?)?.toDouble() ?? 0,
          (p['y'] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
      color: (json['color'] is num)
          ? Color((json['color'] as num).toInt())
          : AppTheme.primary,
      width: (json['width'] as num?)?.toDouble() ?? 4,
    );
  }
}

class _BookImage {
  String url;
  double x;
  double y;
  double scale;
  double rotation;
  double width;
  double height;

  _BookImage({
    required this.url,
    this.x = .5,
    this.y = .5,
    this.scale = 1,
    this.rotation = 0,
    this.width = 180,
    this.height = 180,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'width': width,
        'height': height,
      };

  factory _BookImage.fromJson(Map<String, dynamic> json) => _BookImage(
        url: json['url']?.toString() ?? '',
        x: (json['x'] as num?)?.toDouble() ?? .5,
        y: (json['y'] as num?)?.toDouble() ?? .5,
        scale: (json['scale'] as num?)?.toDouble() ?? 1,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 180,
        height: (json['height'] as num?)?.toDouble() ?? 180,
      );
}

class _BookElement {
  String id;
  String type;
  String value;
  double x;
  double y;
  double scale;
  double rotation;
  int color;
  double fontSize;

  _BookElement({
    required this.id,
    required this.type,
    required this.value,
    this.x = .5,
    this.y = .5,
    this.scale = 1,
    this.rotation = 0,
    int? color,
    this.fontSize = 24,
  }) : color = color ?? AppTheme.primary.value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'color': color,
        'fontSize': fontSize,
      };

  factory _BookElement.fromJson(Map<String, dynamic> json) => _BookElement(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: json['type']?.toString() ?? 'text',
        value: json['value']?.toString() ?? '',
        x: (json['x'] as num?)?.toDouble() ?? .5,
        y: (json['y'] as num?)?.toDouble() ?? .5,
        scale: (json['scale'] as num?)?.toDouble() ?? 1,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        color: (json['color'] as num?)?.toInt() ?? AppTheme.primary.value,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24,
      );
}

class _BookPage {
  int number;
  String? title;
  String? authorId;
  List<_Stroke> strokes;
  List<_BookImage> images;
  List<_BookElement> elements;

  _BookPage({
    required this.number,
    this.title,
    this.authorId,
    List<_Stroke>? strokes,
    List<_BookImage>? images,
    List<_BookElement>? elements,
  })  : strokes = strokes ?? [],
        images = images ?? [],
        elements = elements ?? [];

  bool get isImagePage => number.isOdd;
  bool get isWritingPage => number.isEven;

  factory _BookPage.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString();
    final cleanTitle = switch (rawTitle) {
      'صفحتي الشخصية' ||
      'صفحتي الشخصية - الصور والذكريات' ||
      'صفحتي الشخصية - الرسالة' ||
      'صفحتي - الصور والذكريات' ||
      'صفحتي - الكلمات والكتابة' ||
      _ => rawTitle,
    };
    return _BookPage(
        number: (json['page_number'] as num?)?.toInt() ?? 1,
        title: cleanTitle,
        authorId: json['author_id']?.toString(),
        strokes: ((json['strokes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => _Stroke.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        images: ((json['images'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => _BookImage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        elements: ((json['elements'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => _BookElement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  }
}

class _GraduationBookScreenState extends State<GraduationBookScreen> {
  final _flipKey = GlobalKey<PageFlipWidgetState>();
  final _picker = ImagePicker();

  String? _uid;
  String? _bookId;
  String? _ownerId;
  String? _inviteToken;
  bool _loading = true;
  bool _public = true;
  bool _allowWrites = true;
  bool _owner = false;
  bool _joined = false;
  String? _error;
  List<_BookPage> _pages = [];

  double _penWidth = 4;
  final Color _penColor = AppTheme.primary;
  bool _eraser = false;
  bool _penMode = false;
  final List<List<_Stroke>> _undoStack = [];
  final List<List<_Stroke>> _redoStack = [];

  bool get _canWrite => _owner || (_joined && _allowWrites);

  @override
  void initState() {
    super.initState();
    _uid = Supabase.instance.client.auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final db = Supabase.instance.client;
      Map<String, dynamic>? book;

      if (widget.bookId != null) {
        book = await db
            .from('graduation_books')
            .select('id,owner_id,title,student_name,university,major,graduation_year,is_public,allow_writes,created_at,updated_at')
            .eq('id', widget.bookId!)
            .maybeSingle();
      } else {
        final ownerId = widget.ownerId ?? uid;
        book = await db
            .from('graduation_books')
            .select('id,owner_id,title,student_name,university,major,graduation_year,is_public,allow_writes,created_at,updated_at')
            .eq('owner_id', ownerId)
            .maybeSingle();
      }

      if (book == null && widget.bookId == null && (widget.ownerId == null || widget.ownerId == uid)) {
        _bookId = await db.rpc(
          'ensure_graduation_book',
          params: {
            'p_student_name': widget.studentName,
            'p_university': widget.university,
            'p_major': widget.major,
            'p_graduation_year': widget.graduationYear,
          },
        );
        book = await db.from('graduation_books').select('id,owner_id,title,student_name,university,major,graduation_year,is_public,allow_writes,created_at,updated_at').eq('id', _bookId!).single();
      }

      if (book == null) throw Exception('لا يوجد دفتر خريجين لهذا المستخدم');

      _bookId = book['id']?.toString();
      _ownerId = book['owner_id']?.toString();
      _inviteToken = null;
      if (_owner && _bookId != null) {
        try {
          _inviteToken = (await db.rpc('get_graduation_book_invite_token', params: {'p_book_id': _bookId})).toString();
        } catch (_) {}
      }
      _owner = _ownerId == uid;
      _public = book['is_public'] == true;
      _allowWrites = book['allow_writes'] != false;

      if (_owner && _bookId != null) {
        await db.rpc('ensure_graduation_book_150_pages', params: {'p_book_id': _bookId});
      }

      if (!_owner) {
        if (!_public) throw Exception('هذا الدفتر مخفي حاليًا');
        if (widget.inviteToken != null && _bookId != null) {
          _joined = await db.rpc(
                'join_graduation_book',
                params: {'p_book_id': _bookId, 'p_token': widget.inviteToken},
              ) ==
              true;
        }
        if (!_joined && _bookId != null) {
          final member = await db
              .from('graduation_book_members')
              .select('user_id')
              .eq('book_id', _bookId!)
              .eq('user_id', uid)
              .maybeSingle();
          _joined = member != null;
        }
        if (!_joined) throw Exception('استخدم رابط الدعوة للانضمام إلى الدفتر');
        if (_bookId != null && _allowWrites) {
          await db.rpc('ensure_graduation_book_member_pages', params: {'p_book_id': _bookId});
        }
      }

      final rows = await db
          .from('graduation_book_pages')
          .select('id,book_id,page_number,author_id,title,strokes,images,elements,created_at,updated_at')
          .eq('book_id', _bookId!)
          .order('page_number');
      final allPages = List<Map<String, dynamic>>.from(rows).map(_BookPage.fromJson).toList();

      if (_owner) {
        _pages = allPages;
      } else {
        _pages = allPages.where((page) => page.authorId == uid).take(2).toList();
      }

      if (!_owner && _pages.length < 2) {
        throw Exception('تعذر إنشاء صفحتيك في دفتر الخريجين. أعد المحاولة.');
      }

      _pages.sort((a, b) => a.number.compareTo(b.number));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        final message = e.toString();
        if (message.contains('PGRST205') || message.contains('graduation_books')) {
          _error = 'ميزة دفتر الخريجين تحتاج تفعيل إعداد الصفحات في Supabase.\n\nشغّل ملف: supabase/manual/017_graduation_book_150_pages_apply.sql\nثم أعد فتح الدفتر.';
        } else {
          _error = 'تعذر فتح دفتر الخريجين.\n$message';
        }
      });
    }
  }

  Future<void> _persistPage(_BookPage page) async {
    final bookId = _bookId;
    if (bookId == null) return;
    await Supabase.instance.client.from('graduation_book_pages').upsert(
      {
        'book_id': bookId,
        'page_number': page.number,
        'author_id': page.authorId,
        'title': page.title,
        'strokes': page.strokes.map((e) => e.toJson()).toList(),
        'images': page.images.map((e) => e.toJson()).toList(),
        'elements': page.elements.map((e) => e.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'book_id,page_number',
    );
  }

  Future<void> _saveBookSettings() async {
    if (!_owner || _bookId == null) return;
    await Supabase.instance.client
        .from('graduation_books')
        .update({
          'is_public': _public,
          'allow_writes': _allowWrites,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', _bookId!);
  }

  String get _inviteLink =>
      'zameel://graduation/${_bookId ?? ''}${_inviteToken == null ? '' : '?token=${Uri.encodeComponent(_inviteToken!)}'}';

  Future<void> _shareLink() async {
    await SharePlus.instance.share(ShareParams(text: 'دفتر الخريجين في زميل\n$_inviteLink'));
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ رابط الدعوة ✓')),
      );
    }
  }

  Future<void> _addImage(_BookPage page, {VoidCallback? onChanged}) async {
    if (!_canEditPage(page) || _bookId == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('الصورة التي اخترتها فارغة أو تعذر قراءتها.');
      }

      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      const allowed = {'jpg', 'jpeg', 'png', 'webp'};
      final safeExt = allowed.contains(ext) ? ext : 'jpg';
      final contentType = switch (safeExt) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path =
          '${_bookId!}/${page.number}/${DateTime.now().microsecondsSinceEpoch}.$safeExt';
      final storage = Supabase.instance.client.storage.from('graduation_book');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: false,
        ),
      );

      final url = storage.getPublicUrl(path);
      page.images.add(_BookImage(url: url));
      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }

      if (mounted && onChanged == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الصورة وإضافتها إلى الصفحة ✓')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final needsStorageSetup =
          message.contains('Bucket not found') ||
          message.contains('row-level security') ||
          message.contains('new row violates') ||
          message.contains('Unauthorized') ||
          message.contains('403');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            needsStorageSetup
                ? 'تعذر رفع الصورة. يجب تشغيل ملف Supabase: \nsupabase/manual/015_graduation_book_storage.sql'
                : 'تعذر رفع الصورة: $message',
          ),
        ),
      );
    }
  }

  Future<void> _addText(_BookPage page, {VoidCallback? onChanged}) async {
    if (!_canEditPage(page) || !page.isWritingPage) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة نص إلى صفحتي'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'اكتب رسالتك هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;

    page.elements.add(
      _BookElement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: 'text',
        value: value,
        x: .5,
        y: .48,
      ),
    );
    onChanged?.call();
    if (onChanged == null && mounted) setState(() {});
  }

  void _addSticker(_BookPage page, {VoidCallback? onChanged}) {
    if (!_canEditPage(page) || !page.isWritingPage) return;
    const stickers = ['❤️', '🎓', '✨', '🌿', '⭐', '📸', '🤍', '🎉'];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 18,
            runSpacing: 18,
            children: stickers
                .map(
                  (sticker) => InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      page.elements.add(
                        _BookElement(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          type: 'sticker',
                          value: sticker,
                          x: .5,
                          y: .5,
                          fontSize: 34,
                        ),
                      );
                      onChanged?.call();
                      if (onChanged == null && mounted) setState(() {});
                    },
                    child: Text(sticker, style: const TextStyle(fontSize: 38)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  double _jitter(String seed, int index, double amplitude) {
    final hash = _stableHash('$seed:$index');
    final normalized = (hash % 10000) / 10000.0;
    return (normalized - .5) * 2 * amplitude;
  }

  void _autoArrangePage(_BookPage page) {
    final count = page.images.length;

    if (page.isImagePage) {
      // Empty page: images become a stable, scrapbook-style collage that uses
      // the whole sheet while keeping generous margins around every photo.
      const anchors = <Offset>[
        Offset(.27, .28),
        Offset(.73, .30),
        Offset(.50, .48),
        Offset(.26, .68),
        Offset(.74, .70),
        Offset(.50, .82),
      ];
      const scales = <double>[.46, .44, .43, .40, .40, .34];
      const rotations = <double>[-.055, .042, -.018, .038, -.045, .018];
      for (var i = 0; i < count; i++) {
        final image = page.images[i];
        final a = anchors[i % anchors.length];
        final scale = scales[i % scales.length];
        image
          ..x = (a.dx + _jitter(image.url, i, .012)).clamp(.17, .83).toDouble()
          ..y = (a.dy + _jitter(image.url, i + 90, .010)).clamp(.17, .86).toDouble()
          ..scale = count <= 4 ? (scale + .07).clamp(.34, .56).toDouble() : scale
          ..rotation = rotations[i % rotations.length];
      }
      return;
    }

    // Writing page: text is a flowing stack in the upper portion; images occupy
    // a dedicated lower strip so the two content types never overlap.
    final textElements = page.elements.where((e) => e.type == 'text').toList();
    final stickerElements = page.elements.where((e) => e.type != 'text').toList();

    var y = .18;
    for (var i = 0; i < textElements.length; i++) {
      final e = textElements[i];
      final lineCount = (e.value.trim().length / 34).ceil().clamp(1, 5);
      final blockHeight = (.055 + (lineCount - 1) * .032) * e.scale.clamp(.75, 1.0);
      e
        ..x = .50
        ..y = y.clamp(.14, .58).toDouble()
        ..rotation = 0
        ..scale = e.scale.clamp(.78, 1.0).toDouble();
      y += blockHeight + .035;
    }

    for (var i = 0; i < stickerElements.length; i++) {
      final e = stickerElements[i];
      final leftSide = i.isEven;
      e
        ..x = (leftSide ? .15 : .85)
        ..y = (.18 + (i ~/ 2) * .085).clamp(.16, .58).toDouble()
        ..rotation = const [-.05, .04, -.025][i % 3];
    }

    if (count > 0) {
      const anchors = <Offset>[
        Offset(.22, .79),
        Offset(.50, .82),
        Offset(.78, .79),
        Offset(.34, .88),
        Offset(.66, .88),
      ];
      const scales = <double>[.30, .29, .30, .25, .25];
      const rotations = <double>[-.035, .0, .03, -.02, .022];
      for (var i = 0; i < count; i++) {
        final image = page.images[i];
        final a = anchors[i % anchors.length];
        image
          ..x = (a.dx + _jitter(image.url, i, .008)).clamp(.14, .86).toDouble()
          ..y = (a.dy + _jitter(image.url, i + 180, .006)).clamp(.72, .91).toDouble()
          ..scale = count <= 3 ? (scales[i % scales.length] + .06).clamp(.27, .38).toDouble() : scales[i % scales.length]
          ..rotation = rotations[i % rotations.length];
      }
    }
  }

  Future<bool> _savePage(_BookPage page) async {
    _autoArrangePage(page);
    try {
      await _persistPage(page);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الصفحة: $e')));
      }
      return false;
    }
  }

  Future<void> _exportPdf() async {
    if (!_owner) return;
    final doc = pw.Document();
    final pages = List<_BookPage>.from(_pages)..sort((a, b) => a.number.compareTo(b.number));
    for (final page in pages) {
      final png = await _renderPage(page);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
        ),
      );
    }
    final bytes = await doc.save();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'application/pdf',
            name: 'zameel_graduation_book.pdf',
          ),
        ],
        text: 'دفتر الخريجين جاهز للطباعة',
      ),
    );
  }

  Future<Uint8List> _renderPage(_BookPage page) async {
    const width = 1200.0;
    const height = 1697.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = AppTheme.bookPaper);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = AppTheme.bookAccentLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 18, width - 36, height - 36), const Radius.circular(24)),
      borderPaint,
    );

    for (final stroke in page.strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < stroke.points.length; i++) {
        canvas.drawLine(stroke.points[i - 1], stroke.points[i], paint);
      }
    }

    for (final image in page.images) {
      try {
        final response = await http.get(Uri.parse(image.url));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        final rawW = image.width * image.scale;
        final rawH = image.height * image.scale;
        final widthCap = image.width * .36;
        final heightCap = image.height * .22;
        final factor = [1.0, widthCap / rawW, heightCap / rawH].reduce((a, b) => a < b ? a : b);
        final w = rawW * factor;
        final h = rawH * factor;
        canvas.save();
        canvas.translate(image.x * width, image.y * height);
        canvas.rotate(image.rotation);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(-w / 2, -h / 2, w, h),
          Paint(),
        );
        canvas.restore();
      } catch (_) {}
    }

    for (final element in page.elements) {
      final painter = TextPainter(
        text: TextSpan(
          text: element.value,
          style: TextStyle(
            fontSize: element.fontSize * element.scale,
            fontWeight: element.type == 'text' ? FontWeight.w600 : FontWeight.normal,
            color: Color(element.color),
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 1000);
      canvas.save();
      canvas.translate(element.x * width, element.y * height);
      canvas.rotate(element.rotation);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    final pageNumber = TextPainter(
      text: TextSpan(
        text: '${page.number}',
        style: const TextStyle(fontSize: 28, color: AppTheme.bookText, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pageNumber.paint(canvas, Offset(46, height - 52));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  List<_Stroke> _cloneStrokes(List<_Stroke> strokes) => strokes
      .map((s) => _Stroke(points: List<Offset>.from(s.points), color: s.color, width: s.width))
      .toList();

  void _beginHistory(_BookPage page) {
    _undoStack.add(_cloneStrokes(page.strokes));
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo(_BookPage page) {
    if (!_canEditPage(page) || _undoStack.isEmpty) return;
    _redoStack.add(_cloneStrokes(page.strokes));
    page.strokes = _undoStack.removeLast();
    setState(() {});
  }

  void _redo(_BookPage page) {
    if (!_canEditPage(page) || _redoStack.isEmpty) return;
    _undoStack.add(_cloneStrokes(page.strokes));
    page.strokes = _redoStack.removeLast();
    setState(() {});
  }

  void _eraseLast(_BookPage page) {
    if (!_canEditPage(page) || page.strokes.isEmpty) return;
    _beginHistory(page);
    page.strokes.removeLast();
    setState(() {});
  }

  void _drawStart(_BookPage page, Offset point, {bool? eraserOverride}) {
    if (!_canEditPage(page) || !page.isWritingPage) return;
    if (eraserOverride ?? _eraser) {
      _eraseLast(page);
      return;
    }
    _beginHistory(page);
    page.strokes.add(_Stroke(points: [point], color: _penColor, width: _penWidth));
    setState(() {});
  }

  void _drawMove(_BookPage page, Offset point) {
    if (!_canEditPage(page) || !page.isWritingPage || page.strokes.isEmpty) return;
    page.strokes.last.points.add(point);
    setState(() {});
  }

  bool _canEditPage(_BookPage page) => _owner || (_canWrite && page.authorId == _uid);

  Widget _paperPage({required Widget child, bool leftPage = false, bool rightPage = false}) {
    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: rightPage ? 0 : 4,
        right: leftPage ? 0 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bookPaperSoft,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(leftPage ? 14 : 7),
          bottomLeft: Radius.circular(leftPage ? 14 : 7),
          topRight: Radius.circular(rightPage ? 14 : 7),
          bottomRight: Radius.circular(rightPage ? 14 : 7),
        ),
        border: Border.all(color: AppTheme.bookBorder, width: .8),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: -4,
            color: AppTheme.bookShadow,
            offset: Offset(leftPage ? -5 : 5, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(leftPage ? 14 : 7),
          bottomLeft: Radius.circular(leftPage ? 14 : 7),
          topRight: Radius.circular(rightPage ? 14 : 7),
          bottomRight: Radius.circular(rightPage ? 14 : 7),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.bookPaperAlt, AppTheme.bookPaperDeep],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _pageView(
    _BookPage page, {
    bool editing = false,
    VoidCallback? onChanged,
    int paintRevision = 0,
    bool? penModeOverride,
    bool? eraserOverride,
    bool leftPage = false,
    bool rightPage = false,
  }) {
    final editable = editing && _canEditPage(page);
    final penMode = penModeOverride ?? _penMode;
    final eraser = eraserOverride ?? _eraser;
    return LayoutBuilder(
      builder: (context, constraints) {
        return _paperPage(
          leftPage: leftPage,
          rightPage: rightPage,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _PagePainter(page, paintRevision)),
                ),
              ),
              if (editing && page.isWritingPage && page.elements.isEmpty && page.strokes.isEmpty && page.images.isEmpty)
                const SizedBox.shrink(),
              if (editable && page.isWritingPage && penMode)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      _drawStart(page, details.localPosition, eraserOverride: eraser);
                      onChanged?.call();
                    },
                    onPanUpdate: (details) {
                      _drawMove(page, details.localPosition);
                      onChanged?.call();
                    },
                  ),
                ),
              ...page.images.map((image) {
                if (editable) {
                  return _BookImageEditor(
                    key: ValueKey(image.url),
                    image: image,
                    size: constraints.biggest,
                    onChanged: () {
                      onChanged?.call();
                      if (onChanged == null && mounted) setState(() {});
                    },
                    onDelete: () {
                      page.images.remove(image);
                      onChanged?.call();
                      if (onChanged == null && mounted) setState(() {});
                    },
                  );
                }
                return _ReadOnlyImage(image: image, size: constraints.biggest);
              }),
              ...page.elements.map(
                (element) => _BookElementEditor(
                  key: ValueKey(element.id),
                  element: element,
                  size: constraints.biggest,
                  editable: editable,
                  onChanged: () {
                    onChanged?.call();
                    if (onChanged == null && mounted) setState(() {});
                  },
                  onDelete: () {
                    page.elements.remove(element);
                    onChanged?.call();
                    if (onChanged == null && mounted) setState(() {});
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                right: page.isImagePage ? 10 : null,
                left: page.isImagePage ? null : 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.bookPaperOverlay,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.bookEarth),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'صفحة ${page.number}',
                      style: const TextStyle(color: AppTheme.bookTextSoft, fontSize: 9.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bookGutter() {
    return SizedBox(
      width: 24,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppTheme.bookOliveOverlayStrong, AppTheme.bookWhiteOverlay, AppTheme.bookOliveOverlayStrong],
          ),
        ),
        child: Center(
          child: Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(color: AppTheme.bookOliveOverlay),
          ),
        ),
      ),
    );
  }

  Widget _spreadView(List<_BookPage> spread) {
    final left = spread.firstWhere((p) => p.number.isOdd, orElse: () => spread.first);
    final right = spread.firstWhere((p) => p.number.isEven, orElse: () => spread.last);
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 30, spreadRadius: -6, color: AppTheme.bookPhotoShadow, offset: Offset(0, 12)),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.bookPaperSoft, AppTheme.bookBorderSoft],
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: GestureDetector(
                  onTap: _canEditPage(left) ? () => _openPageEditor(left) : null,
                  child: _pageView(left, leftPage: true),
                ),
              ),
            ),
            _bookGutter(),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: GestureDetector(
                  onTap: _canEditPage(right) ? () => _openPageEditor(right) : null,
                  child: _pageView(right, rightPage: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearPage(_BookPage page) async {
    if (!_owner || _bookId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تفريغ الصفحة؟'),
        content: const Text('سيتم حذف الصور والكتابة والعناصر من هذه الصفحة، مع إبقاء الصفحة نفسها للمشارك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تفريغ الصفحة'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('graduation_book_pages')
          .update({
            'strokes': [],
            'images': [],
            'elements': [],
            'title': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('book_id', _bookId!)
          .eq('page_number', page.number);
      page.strokes.clear();
      page.images.clear();
      page.elements.clear();
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفريغ الصفحة بنجاح ✓')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تفريغ الصفحة: $e')));
    }
  }

  Future<void> _openPageEditor(_BookPage page) async {
    if (!_canEditPage(page)) return;
    _penMode = false;
    _eraser = false;
    _undoStack.clear();
    _redoStack.clear();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GraduationPageEditor(
          title: 'تحرير الصفحة ${page.number}',
          pageBuilder: (context, revision, onChanged, penMode, eraserMode) => _pageView(
            page,
            editing: true,
            onChanged: onChanged,
            paintRevision: revision,
            penModeOverride: penMode,
            eraserOverride: eraserMode,
            leftPage: page.isImagePage,
            rightPage: page.isWritingPage,
          ),
          onAddImage: (onChanged) => _addImage(page, onChanged: onChanged),
          onAddText: page.isWritingPage ? (onChanged) => _addText(page, onChanged: onChanged) : null,
          onAddSticker: page.isWritingPage ? (onChanged) => _addSticker(page, onChanged: onChanged) : null,
          onSave: () => _savePage(page),
          onClearPage: _owner ? () => _clearPage(page) : null,
          canUsePen: page.isWritingPage,
          canAddText: page.isWritingPage,
          canAddSticker: page.isWritingPage,
          onUndo: page.isWritingPage ? (notify) { _undo(page); notify(); } : null,
          onRedo: page.isWritingPage ? (notify) { _redo(page); notify(); } : null,
          onTogglePen: (enabled, notify) {
            _penMode = enabled;
            _eraser = false;
            notify();
          },
          onToggleEraser: (enabled, notify) {
            _eraser = enabled;
            _penMode = true;
            notify();
          },
          canUndo: () => _undoStack.isNotEmpty,
          canRedo: () => _redoStack.isNotEmpty,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() {});
      if (page.isImagePage) {
        final candidates = _pages.where((p) => p.number == page.number + 1 && p.authorId == page.authorId);
        final next = candidates.isEmpty ? null : candidates.first;
        if (next != null && _canEditPage(next)) {
          await _openPageEditor(next);
        }
      }
    }
  }

  List<List<_BookPage>> _spreads() {
    final sorted = List<_BookPage>.from(_pages)..sort((a, b) => a.number.compareTo(b.number));
    final result = <List<_BookPage>>[];
    for (var i = 0; i < sorted.length; i += 2) {
      if (i + 1 < sorted.length) result.add([sorted[i], sorted[i + 1]]);
    }
    return result;
  }

  Future<void> _manageParticipants() async {
    if (!_owner || _bookId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('graduation_book_members')
          .select('user_id')
          .eq('book_id', _bookId!);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('إدارة المشاركين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('كل مشارك يملك صفحتين فقط. يمكنك إزالة مشارك ومسح صفحتيه.'),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لا يوجد مشاركون بعد.', textAlign: TextAlign.center),
                  )
                else
                  ...rows.map((row) {
                    final userId = row['user_id']?.toString() ?? '';
                    final page = _pages.where((p) => p.authorId == userId).toList();
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                      title: Text(userId.length > 8 ? 'مشارك ${userId.substring(0, 8)}' : 'مشارك'),
                      subtitle: Text('صفحات ${page.isEmpty ? 'غير محمّلة' : page.map((p) => p.number).join(' و ')}'),
                      trailing: IconButton(
                        tooltip: 'إزالة المشارك',
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('إزالة المشارك؟'),
                              content: const Text('سيتم حذف صفحتي المشارك من دفتر الخريجين، ولن يتم حذف أي صفحة لمشارك آخر.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('إزالة'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          try {
                            await Supabase.instance.client.rpc(
                              'remove_graduation_book_member',
                              params: {'p_book_id': _bookId, 'p_user_id': userId},
                            );
                            if (!mounted) return;
                            setState(() {
                              _pages.removeWhere((p) => p.authorId == userId);
                              _pages.sort((a, b) => a.number.compareTo(b.number));
                            });
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إزالة المشارك: $e')));
                          }
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل المشاركين: $e')));
    }
  }

  Future<void> _openSettings() async {
    if (!_owner) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('⚙️ إعدادات دفتر الخريجين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _public,
                onChanged: (value) async {
                  setState(() => _public = value);
                  await _saveBookSettings();
                },
                title: const Text('إظهار الدفتر للزوار'),
                subtitle: const Text('الإخفاء لا يحذف أي صفحة أو محتوى'),
              ),
              SwitchListTile(
                value: _allowWrites,
                onChanged: (value) async {
                  setState(() => _allowWrites = value);
                  await _saveBookSettings();
                },
                title: const Text('السماح للأصدقاء بالكتابة'),
                subtitle: const Text('كل صديق يملك صفحتين فقط'),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('نسخ رابط الدعوة'),
                onTap: _copyLink,
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('مشاركة رابط الدعوة'),
                onTap: _shareLink,
              ),
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('إدارة المشاركين'),
                subtitle: const Text('عرض أو إزالة المشاركين وصفحتيهم'),
                onTap: _manageParticipants,
              ),
              ListTile(
                leading: const Icon(Icons.print_rounded),
                title: const Text('تصدير PDF للطباعة'),
                onTap: _exportPdf,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('دفتر الخريجين')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, size: 64, color: AppTheme.primary),
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _load();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spreads = _spreads();

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: AppBar(
          title: Text('📖 دفتر الخريجين - ${widget.studentName}'),
          actions: [
            if (_owner)
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'إعدادات الدفتر',
              ),
            IconButton(
              onPressed: _shareLink,
              icon: const Icon(Icons.share_rounded),
              tooltip: 'مشاركة الدعوة',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'دفتر الخريجين',
                      style: TextStyle(color: AppTheme.primaryDark, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    _owner ? '150 صفحة • 75 فتحة' : 'صفحتاك',
                    style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: spreads.isEmpty
                  ? const Center(child: Text('لا توجد صفحات بعد'))
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 820),
                          child: AspectRatio(
                            aspectRatio: 1.00,
                            child: _owner
                                ? PageFlipWidget(
                                    key: _flipKey,
                                    backgroundColor: AppTheme.bookBorder,
                                    lastPage: Container(
                                      margin: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentSoft,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'نهاية دفتر الخريجين',
                                        style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
                                      ),
                                    ),
                                    children: spreads.map(_spreadView).toList(),
                                  )
                                : _spreadView(spreads.first),
                          ),
                        ),
                      ),
                    ),
            ),
            if (!_owner || _canWrite)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.bookAccentLight),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'اضغط على صفحتك لفتحها بحجم كبير والتحرير براحة، ثم احفظ وانتقل للصفحة التالية.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_owner)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('PDF للطباعة'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareLink,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('دعوة أصدقاء'),
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

class _GraduationPageEditor extends StatefulWidget {
  final String title;
  final Widget Function(BuildContext context, int revision, VoidCallback onChanged, bool penMode, bool eraserMode) pageBuilder;
  final Future<void> Function(VoidCallback onChanged) onAddImage;
  final Future<void> Function(VoidCallback onChanged)? onAddText;
  final void Function(VoidCallback onChanged)? onAddSticker;
  final Future<bool> Function() onSave;
  final Future<void> Function()? onClearPage;
  final void Function(bool enabled, VoidCallback notify)? onTogglePen;
  final void Function(bool enabled, VoidCallback notify)? onToggleEraser;
  final void Function(VoidCallback notify)? onUndo;
  final void Function(VoidCallback notify)? onRedo;
  final bool Function()? canUndo;
  final bool Function()? canRedo;
  final bool canUsePen;
  final bool canAddText;
  final bool canAddSticker;

  const _GraduationPageEditor({
    required this.title,
    required this.pageBuilder,
    required this.onAddImage,
    required this.onSave,
    this.onAddText,
    this.onAddSticker,
    this.onClearPage,
    this.onTogglePen,
    this.onToggleEraser,
    this.onUndo,
    this.onRedo,
    this.canUndo,
    this.canRedo,
    this.canUsePen = false,
    this.canAddText = false,
    this.canAddSticker = false,
  });

  @override
  State<_GraduationPageEditor> createState() => _GraduationPageEditorState();
}

class _GraduationPageEditorState extends State<_GraduationPageEditor> {
  int _revision = 0;
  bool _dirty = false;
  bool _saving = false;
  bool _penMode = false;
  bool _eraserMode = false;

  void _changed() {
    if (!mounted) return;
    setState(() {
      _revision++;
      _dirty = true;
    });
  }

  void _notifyCanvas() {
    if (!mounted) return;
    setState(() => _revision++);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصفحة ✓')));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (!_dirty || _saving) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الخروج دون حفظ؟'),
        content: const Text('لديك تعديلات لم تُحفظ بعد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('البقاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('خروج')), 
        ],
      ),
    );
    if (result == true && mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _close),
        actions: [
          if (_dirty)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('غير محفوظ'))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: widget.pageBuilder(context, _revision, _changed, _penMode, _eraserMode),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Material(
                elevation: 5,
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: _saving ? null : () async => widget.onAddImage(_changed),
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          tooltip: 'إضافة صورة',
                        ),
                        if (widget.canUsePen)
                          IconButton.filledTonal(
                            onPressed: _saving ? null : () {
                              final next = !_penMode;
                              setState(() {
                                _penMode = next;
                                if (next) _eraserMode = false;
                                _dirty = true;
                              });
                              widget.onTogglePen?.call(next, _notifyCanvas);
                            },
                            icon: Icon(_penMode && !_eraserMode ? Icons.gesture_rounded : Icons.edit_rounded),
                            tooltip: _penMode && !_eraserMode ? 'إيقاف القلم' : 'القلم',
                          ),
                        if (widget.canUsePen)
                          IconButton.filledTonal(
                            onPressed: _saving ? null : () {
                              final next = !_eraserMode;
                              setState(() {
                                _eraserMode = next;
                                if (next) _penMode = true;
                                _dirty = true;
                              });
                              widget.onToggleEraser?.call(next, _notifyCanvas);
                            },
                            icon: Icon(_eraserMode ? Icons.cleaning_services_rounded : Icons.auto_fix_high_rounded),
                            tooltip: 'الممحاة',
                          ),
                        if (widget.canAddText)
                          IconButton.filledTonal(
                            onPressed: _saving ? null : () async => widget.onAddText!(_changed),
                            icon: const Icon(Icons.text_fields_rounded),
                            tooltip: 'إضافة نص',
                          ),
                        if (widget.canAddSticker)
                          IconButton.filledTonal(
                            onPressed: _saving ? null : () => widget.onAddSticker!(_changed),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            tooltip: 'ملصق',
                          ),
                        IconButton.filledTonal(
                          onPressed: (_saving || !(widget.canUndo?.call() ?? false)) ? null : () => widget.onUndo?.call(_notifyCanvas),
                          icon: const Icon(Icons.undo_rounded),
                          tooltip: 'تراجع',
                        ),
                        IconButton.filledTonal(
                          onPressed: (_saving || !(widget.canRedo?.call() ?? false)) ? null : () => widget.onRedo?.call(_notifyCanvas),
                          icon: const Icon(Icons.redo_rounded),
                          tooltip: 'إعادة',
                        ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: const Text('حفظ'),
                        ),
                        if (widget.onClearPage != null) ...[
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            onPressed: _saving ? null : () async {
                              await widget.onClearPage!();
                              if (mounted) {
                                setState(() {
                                  _dirty = false;
                                  _revision++;
                                });
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                            tooltip: 'تفريغ الصفحة (لصاحب الدفتر)',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactProfileChip extends StatelessWidget {
  final String studentName;
  final String university;
  final String major;
  final String year;

  const _CompactProfileChip({
    required this.studentName,
    required this.university,
    required this.major,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      university,
      major,
      year.isEmpty ? '' : 'دفعة $year',
    ].where((e) => e.trim().isNotEmpty).join('  •  ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.bookAccent),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: AppTheme.bookTealShadowLight, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            studentName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              details,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.bookTextDeep, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfilePageHeader extends StatelessWidget {
  final String studentName;
  final String university;
  final String major;
  final String year;

  const _ProfilePageHeader({
    required this.studentName,
    required this.university,
    required this.major,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(studentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryDark)),
          if (university.isNotEmpty) Text(university, style: const TextStyle(color: AppTheme.textSecondary)),
          if (major.isNotEmpty) Text(major, style: const TextStyle(color: AppTheme.textSecondary)),
          if (year.isNotEmpty) Text('دفعة $year', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  final _BookPage page;
  final int revision;
  const _PagePainter(this.page, [this.revision = 0]);

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..color = AppTheme.accentSoft;
    canvas.drawCircle(Offset(size.width * .18, size.height * .76), size.shortestSide * .28, wash);
    canvas.drawCircle(Offset(size.width * .84, size.height * .22), size.shortestSide * .22, Paint()..color = AppTheme.surface);

    for (final stroke in page.strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 1; i < stroke.points.length; i++) {
        canvas.drawLine(stroke.points[i - 1], stroke.points[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PagePainter oldDelegate) => oldDelegate.page != page || oldDelegate.revision != revision;
}

class _ReadOnlyImage extends StatelessWidget {
  final _BookImage image;
  final Size size;

  const _ReadOnlyImage({required this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    final rawW = image.width * image.scale;
    final rawH = image.height * image.scale;
    final widthCap = size.width * .50;
    final heightCap = size.height * .31;
    final factor = [1.0, widthCap / rawW, heightCap / rawH].reduce((a, b) => a < b ? a : b);
    final w = rawW * factor;
    final h = rawH * factor;
    final frameW = w + 14;
    final frameH = h + 20;
    return Positioned(
      left: image.x * size.width - frameW / 2,
      top: image.y * size.height - frameH / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -4,
            left: frameW * .30,
            child: Transform.rotate(
              angle: -.04,
              child: Container(
                width: frameW * .40,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.bookGoldShadow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: image.rotation,
            child: Container(
          width: frameW,
          height: frameH,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            boxShadow: const [
              BoxShadow(blurRadius: 8, color: AppTheme.bookShadowSoft, offset: Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.network(image.url, width: w, height: h, fit: BoxFit.cover),
          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookImageEditor extends StatefulWidget {
  final _BookImage image;
  final Size size;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _BookImageEditor({
    super.key,
    required this.image,
    required this.size,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_BookImageEditor> createState() => _BookImageEditorState();
}

class _BookImageEditorState extends State<_BookImageEditor> {
  double _baseScale = 1;
  double _baseRotation = 0;

  @override
  Widget build(BuildContext context) {
    final rawW = widget.image.width * widget.image.scale;
    final rawH = widget.image.height * widget.image.scale;
    final widthCap = widget.size.width * .50;
    final heightCap = widget.size.height * .31;
    final factor = [1.0, widthCap / rawW, heightCap / rawH].reduce((a, b) => a < b ? a : b);
    final w = rawW * factor;
    final h = rawH * factor;
    final frameW = w + 14;
    final frameH = h + 20;
    return Positioned(
      left: widget.image.x * widget.size.width - frameW / 2,
      top: widget.image.y * widget.size.height - frameH / 2,
      child: GestureDetector(
        onLongPress: () {},
        onScaleStart: (_) {
          _baseScale = widget.image.scale;
          _baseRotation = widget.image.rotation;
        },
        onScaleUpdate: (details) {
          widget.image.scale = (_baseScale * details.scale).clamp(.25, 4).toDouble();
          widget.image.rotation = _baseRotation + details.rotation;
          widget.image.x = ((widget.image.x * widget.size.width + details.focalPointDelta.dx) / widget.size.width).clamp(.06, .94).toDouble();
          widget.image.y = ((widget.image.y * widget.size.height + details.focalPointDelta.dy) / widget.size.height).clamp(.12, .90).toDouble();
          widget.onChanged();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -4,
              left: frameW * .30,
              child: Transform.rotate(
                angle: -.04,
                child: Container(
                  width: frameW * .40,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.bookGoldShadow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: widget.image.rotation,
              child: Container(
                width: frameW,
                height: frameH,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.accent, width: 2),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: const [
                    BoxShadow(blurRadius: 10, color: AppTheme.bookTealShadow, offset: Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(widget.image.url, fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned(
              top: -10,
              right: -10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                  tooltip: 'حذف الصورة',
                  onPressed: widget.onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookElementEditor extends StatefulWidget {
  final _BookElement element;
  final Size size;
  final bool editable;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _BookElementEditor({
    super.key,
    required this.element,
    required this.size,
    required this.editable,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_BookElementEditor> createState() => _BookElementEditorState();
}

class _BookElementEditorState extends State<_BookElementEditor> {
  double _baseScale = 1;
  double _baseRotation = 0;

  @override
  Widget build(BuildContext context) {
    final font = widget.element.fontSize * widget.element.scale;
    final textStyle = TextStyle(
      fontSize: font,
      color: Color(widget.element.color),
      fontWeight: widget.element.type == 'text' ? FontWeight.w600 : FontWeight.normal,
    );
    return Positioned(
      left: widget.element.x * widget.size.width - (widget.element.type == 'sticker' ? font : widget.size.width * .30),
      top: widget.element.y * widget.size.height - font,
      child: GestureDetector(
        onLongPress: widget.editable ? () {} : null,
        onScaleStart: widget.editable
            ? (_) {
                _baseScale = widget.element.scale;
                _baseRotation = widget.element.rotation;
              }
            : null,
        onScaleUpdate: widget.editable
            ? (details) {
                widget.element.scale = (_baseScale * details.scale).clamp(.5, 4).toDouble();
                widget.element.rotation = _baseRotation + details.rotation;
                widget.element.x = ((widget.element.x * widget.size.width + details.focalPointDelta.dx) / widget.size.width).clamp(.06, .94).toDouble();
                widget.element.y = ((widget.element.y * widget.size.height + details.focalPointDelta.dy) / widget.size.height).clamp(.15, .90).toDouble();
                widget.onChanged();
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: BoxConstraints(maxWidth: widget.size.width * .58),
              decoration: widget.editable
                  ? BoxDecoration(
                      color: Colors.white.withAlpha(220),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accent, width: 1.5),
                    )
                  : null,
              child: Transform.rotate(
                angle: widget.element.rotation,
                child: Text(
                  widget.element.value,
                  style: textStyle,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
            if (widget.editable)
              Positioned(
                top: -10,
                right: -10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                    tooltip: 'حذف العنصر',
                    onPressed: widget.onDelete,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
