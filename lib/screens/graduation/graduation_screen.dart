import 'dart:typed_data';
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
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF0E7D75),
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
    this.color = 0xFF0E7D75,
    this.fontSize = 24,
  });

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
        color: (json['color'] as num?)?.toInt() ?? 0xFF0E7D75,
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

  factory _BookPage.fromJson(Map<String, dynamic> json) => _BookPage(
        number: (json['page_number'] as num?)?.toInt() ?? 1,
        title: json['title']?.toString(),
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
  final Color _penColor = const Color(0xFF0E7D75);
  bool _eraser = false;
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
            .select('*')
            .eq('id', widget.bookId!)
            .maybeSingle();
      } else {
        final ownerId = widget.ownerId ?? uid;
        book = await db
            .from('graduation_books')
            .select('*')
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
        book = await db.from('graduation_books').select('*').eq('id', _bookId!).single();
      }

      if (book == null) throw Exception('لا يوجد دفتر خريجين لهذا المستخدم');

      _bookId = book['id']?.toString();
      _ownerId = book['owner_id']?.toString();
      _inviteToken = book['invite_token']?.toString();
      _owner = _ownerId == uid;
      _public = book['is_public'] == true;
      _allowWrites = book['allow_writes'] != false;

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
          .select('*')
          .eq('book_id', _bookId!)
          .order('page_number');
      final allPages = List<Map<String, dynamic>>.from(rows).map(_BookPage.fromJson).toList();

      if (_owner) {
        _pages = allPages;
      } else {
        _pages = allPages.where((page) => page.authorId == uid).take(2).toList();
      }

      if (_owner && !_pages.any((p) => p.number == 1 && p.authorId == uid)) {
        final first = _BookPage(number: 1, title: 'صفحتي - الصور والذكريات', authorId: uid);
        _pages.insert(0, first);
        await _persistPage(first);
      }
      if (_owner && !_pages.any((p) => p.number == 2 && p.authorId == uid)) {
        final second = _BookPage(number: 2, title: 'صفحتي - الكلمات والكتابة', authorId: uid);
        _pages.add(second);
        await _persistPage(second);
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
          _error = 'ميزة دفتر الخريجين تحتاج تفعيل جداولها في Supabase.\n\nشغّل ملف: supabase/manual/013_graduation_book_spreads_apply.sql\nثم أعد فتح الدفتر.';
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

  Future<void> _addImage(_BookPage page) async {
    if (!_canEditPage(page) || !page.isImagePage || _bookId == null) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final path = '${_bookId!}/${page.number}/${DateTime.now().microsecondsSinceEpoch}.$ext';

    await Supabase.instance.client.storage.from('graduation_book').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final url = Supabase.instance.client.storage.from('graduation_book').getPublicUrl(path);
    page.images.add(_BookImage(url: url));
    if (mounted) setState(() {});
    await _persistPage(page);
  }

  Future<void> _addText(_BookPage page) async {
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
    if (mounted) setState(() {});
    await _persistPage(page);
  }

  void _addSticker(_BookPage page) {
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
                      setState(() {});
                      _persistPage(page);
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

  Future<void> _savePage(_BookPage page) async {
    try {
      await _persistPage(page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الصفحة: $e')));
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
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFFEFDF8));

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = const Color(0xFFBDE9E4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 18, width - 36, height - 36), const Radius.circular(24)),
      borderPaint,
    );

    final title = TextPainter(
      text: TextSpan(
        text: page.title ?? '',
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF0E5E59)),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: width - 80);
    title.paint(canvas, Offset(width - title.width - 40, 48));

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
        final w = image.width * image.scale;
        final h = image.height * image.scale;
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
        style: const TextStyle(fontSize: 28, color: Color(0xFF5F7C78), fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pageNumber.paint(canvas, Offset(width - pageNumber.width - 46, height - 55));

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
    _savePage(page);
  }

  void _redo(_BookPage page) {
    if (!_canEditPage(page) || _redoStack.isEmpty) return;
    _undoStack.add(_cloneStrokes(page.strokes));
    page.strokes = _redoStack.removeLast();
    setState(() {});
    _savePage(page);
  }

  void _eraseLast(_BookPage page) {
    if (!_canEditPage(page) || page.strokes.isEmpty) return;
    _beginHistory(page);
    page.strokes.removeLast();
    setState(() {});
    _savePage(page);
  }

  void _drawStart(_BookPage page, Offset point) {
    if (!_canEditPage(page) || !page.isWritingPage) return;
    if (_eraser) {
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

  Widget _paperPage({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBDE9E4), width: 1.4),
        boxShadow: const [BoxShadow(blurRadius: 14, color: Color(0x140B6F68), offset: Offset(0, 4))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: child),
    );
  }

  Widget _pageView(_BookPage page) {
    final editable = _canEditPage(page);
    return LayoutBuilder(
      builder: (context, constraints) {
        return _paperPage(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PagePainter(page)),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F8F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      page.isImagePage ? 'الصور والذكريات' : 'كلمات من القلب',
                      style: const TextStyle(color: Color(0xFF0E5E59), fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              if (page.isImagePage && page.number == 1)
                Positioned(
                  top: 82,
                  left: 18,
                  right: 18,
                  child: _ProfilePageHeader(
                    studentName: widget.studentName,
                    university: widget.university,
                    major: widget.major,
                    year: widget.graduationYear,
                  ),
                ),
              if (page.isImagePage && page.number != 1)
                Positioned(
                  top: 74,
                  left: 18,
                  right: 18,
                  child: const Text(
                    'مساحة الصور واللحظات الخاصة بهذه الصفحة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF54706B)),
                  ),
                ),
              if (page.isWritingPage && page.elements.isEmpty && page.strokes.isEmpty)
                const Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'اكتب بخط يدك أو أضف نصًا وحرّكه داخل الصفحة',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF7D9793), fontSize: 18),
                      ),
                    ),
                  ),
                ),
              if (editable && page.isWritingPage)
                Positioned.fill(
                  top: 74,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) => _drawStart(page, details.localPosition),
                    onPanUpdate: (details) => _drawMove(page, details.localPosition),
                    onPanEnd: (_) => _savePage(page),
                  ),
                ),
              if (editable && page.isImagePage)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 82,
                  child: OutlinedButton.icon(
                    onPressed: () => _addImage(page),
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('إضافة صورة أو ذكرى'),
                  ),
                ),
              ...page.images.map((image) {
                if (editable) {
                  return _BookImageEditor(
                    image: image,
                    size: constraints.biggest,
                    onChanged: () {
                      setState(() {});
                      _savePage(page);
                    },
                    onDelete: () {
                      page.images.remove(image);
                      setState(() {});
                      _savePage(page);
                    },
                  );
                }
                return _ReadOnlyImage(image: image, size: constraints.biggest);
              }),
              ...page.elements.map(
                (element) => _BookElementEditor(
                  element: element,
                  size: constraints.biggest,
                  editable: editable,
                  onChanged: () {
                    setState(() {});
                    _savePage(page);
                  },
                  onDelete: () {
                    page.elements.remove(element);
                    setState(() {});
                    _savePage(page);
                  },
                ),
              ),
              if (editable)
                Positioned(
                  top: 54,
                  left: 10,
                  child: page.isWritingPage
                      ? Row(
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFFE7F8F5)),
                              onPressed: () => setState(() => _eraser = false),
                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF0E7D75)),
                              tooltip: 'قلم',
                            ),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFFE7F8F5)),
                              onPressed: () => setState(() => _eraser = true),
                              icon: Icon(_eraser ? Icons.cleaning_services_rounded : Icons.auto_fix_high_rounded, color: const Color(0xFF0E7D75)),
                              tooltip: 'ممحاة',
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              if (editable)
                Positioned(
                  top: 54,
                  right: 10,
                  child: page.isWritingPage
                      ? Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => _addText(page),
                              icon: const Icon(Icons.text_fields_rounded),
                              tooltip: 'نص',
                            ),
                            IconButton.filledTonal(
                              onPressed: () => _addSticker(page),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              tooltip: 'ملصقات',
                            ),
                            IconButton.filledTonal(
                              onPressed: _undoStack.isEmpty ? null : () => _undo(page),
                              icon: const Icon(Icons.undo_rounded),
                              tooltip: 'تراجع',
                            ),
                            IconButton.filledTonal(
                              onPressed: _redoStack.isEmpty ? null : () => _redo(page),
                              icon: const Icon(Icons.redo_rounded),
                              tooltip: 'إعادة',
                            ),
                            IconButton.filledTonal(
                              onPressed: () => _savePage(page),
                              icon: const Icon(Icons.save_rounded),
                              tooltip: 'حفظ',
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              if (editable && page.isImagePage)
                Positioned(
                  top: 54,
                  right: 10,
                  child: IconButton.filledTonal(
                    onPressed: () => _addImage(page),
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    tooltip: 'إضافة صورة',
                  ),
                ),
              Positioned(
                bottom: 12,
                left: 18,
                right: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('صفحة ${page.number}', style: const TextStyle(color: Color(0xFF5F7C78), fontWeight: FontWeight.w700)),
                    Text(page.isImagePage ? 'الجهة اليسرى' : 'الجهة اليمنى', style: const TextStyle(color: Color(0xFF7D9793))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<List<_BookPage>> _spreads() {
    final sorted = List<_BookPage>.from(_pages)..sort((a, b) => a.number.compareTo(b.number));
    final result = <List<_BookPage>>[];
    for (var i = 0; i < sorted.length; i += 2) {
      if (i + 1 < sorted.length) result.add([sorted[i], sorted[i + 1]]);
    }
    return result;
  }

  Widget _spreadView(List<_BookPage> spread) {
    final left = spread.firstWhere((p) => p.isImagePage, orElse: () => spread.first);
    final right = spread.firstWhere((p) => p.isWritingPage, orElse: () => spread.last);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Directionality(textDirection: TextDirection.rtl, child: _pageView(left))),
          Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 20), color: const Color(0xFFB8C8C5)),
          Expanded(child: Directionality(textDirection: TextDirection.rtl, child: _pageView(right))),
        ],
      ),
    );
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
        backgroundColor: const Color(0xFFF1FBF9),
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
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F7F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF0E7D75)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'لكل خريج أو مشارك صفحتان متقابلتان: اليسرى للصور والذكريات، واليمنى للكتابة والرسائل.',
                      style: TextStyle(color: Color(0xFF285D58), fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('ورقة × ${spreads.length}', style: const TextStyle(color: Color(0xFF54706B))),
                ],
              ),
            ),
            Expanded(
              child: spreads.isEmpty
                  ? const Center(child: Text('لا توجد صفحات بعد'))
                  : _owner
                      ? PageFlipWidget(
                          key: _flipKey,
                          backgroundColor: const Color(0xFFF1FBF9),
                          lastPage: Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F8F4),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            alignment: Alignment.center,
                            child: const Text('نهاية دفتر الخريجين', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0E5E59))),
                          ),
                          children: spreads.map(_spreadView).toList(),
                        )
                      : _spreadView(spreads.first),
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
        color: const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(studentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0E5E59))),
          if (university.isNotEmpty) Text(university, style: const TextStyle(color: Color(0xFF54706B))),
          if (major.isNotEmpty) Text(major, style: const TextStyle(color: Color(0xFF54706B))),
          if (year.isNotEmpty) Text('دفعة $year', style: const TextStyle(color: Color(0xFF0E7D75), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  final _BookPage page;
  const _PagePainter(this.page);

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..color = const Color(0xFFF0FBF8);
    canvas.drawCircle(Offset(size.width * .18, size.height * .76), size.shortestSide * .28, wash);
    canvas.drawCircle(Offset(size.width * .84, size.height * .22), size.shortestSide * .22, Paint()..color = const Color(0xFFF8FFFE));

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
  bool shouldRepaint(covariant _PagePainter oldDelegate) => true;
}

class _ReadOnlyImage extends StatelessWidget {
  final _BookImage image;
  final Size size;

  const _ReadOnlyImage({required this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    final w = image.width * image.scale;
    final h = image.height * image.scale;
    return Positioned(
      left: image.x * size.width - w / 2,
      top: image.y * size.height - h / 2,
      child: Transform.rotate(
        angle: image.rotation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(image.url, width: w, height: h, fit: BoxFit.cover),
        ),
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
    final w = widget.image.width * widget.image.scale;
    final h = widget.image.height * widget.image.scale;
    return Positioned(
      left: widget.image.x * widget.size.width - w / 2,
      top: widget.image.y * widget.size.height - h / 2,
      child: GestureDetector(
        onLongPress: widget.onDelete,
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
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF18C8BB), width: 2),
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(widget.image.url, fit: BoxFit.cover),
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
        onLongPress: widget.editable ? widget.onDelete : null,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(maxWidth: widget.size.width * .58),
          decoration: widget.editable
              ? BoxDecoration(
                  color: Colors.white.withAlpha(220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF18C8BB), width: 1.5),
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
      ),
    );
  }
}
