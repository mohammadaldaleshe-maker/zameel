import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The saved rectangle is exactly the visible frame; avatars mask it as a circle.
class ProfileImageCropper extends StatefulWidget {
  final Uint8List bytes;
  final bool cover;
  final bool arabic;
  const ProfileImageCropper(
      {super.key, required this.bytes, this.cover = false, this.arabic = true});
  @override
  State<ProfileImageCropper> createState() => _ProfileImageCropperState();
}

class _ProfileImageCropperState extends State<ProfileImageCropper> {
  ui.Image? _image;
  String? _error;
  Size _frame = Size.zero;
  double _zoom = 1, _startZoom = 1;
  Offset _offset = Offset.zero,
      _startOffset = Offset.zero,
      _startFocal = Offset.zero;
  bool _saving = false;
  double get _base =>
      math.max(_frame.width / _image!.width, _frame.height / _image!.height);
  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            widget.arabic ? 'تعذر فتح الصورة' : 'Unable to open image');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Offset _clamp(Offset value) {
    final x = math.max(0.0, (_image!.width * _base * _zoom - _frame.width) / 2);
    final y =
        math.max(0.0, (_image!.height * _base * _zoom - _frame.height) / 2);
    return Offset(value.dx.clamp(-x, x), value.dy.clamp(-y, y));
  }

  Future<void> _save() async {
    if (_image == null || _frame.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final scale = _base * _zoom;
      final source = Rect.fromLTWH(
          (_image!.width - _frame.width / scale) / 2 - _offset.dx / scale,
          (_image!.height - _frame.height / scale) / 2 - _offset.dy / scale,
          _frame.width / scale,
          _frame.height / scale);
      final width = widget.cover ? 1500 : 900;
      final height = widget.cover ? 500 : 900;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
          _image!,
          source,
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..filterQuality = FilterQuality.high);
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(width, height);
      picture.dispose();
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (data == null) throw StateError('Image encoding failed');
      if (mounted) Navigator.pop(context, data.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.arabic
                ? 'تعذر حفظ الصورة. حاول مجددًا.'
                : 'Unable to save image. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.arabic
                ? (widget.cover ? 'ضبط الغلاف' : 'ضبط الصورة الشخصية')
                : 'Position image')),
        body: _error != null
            ? Center(child: Text(_error!))
            : _image == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(widget.arabic
                            ? 'حرّك الصورة بإصبعك وكبّرها بإصبعين لتناسب الإطار.'
                            : 'Drag to position. Pinch to zoom.')),
                    Expanded(child: Center(
                        child: LayoutBuilder(builder: (context, constraints) {
                      final width = math.min(constraints.maxWidth - 32,
                          widget.cover ? 600.0 : 320.0);
                      final height = width / (widget.cover ? 3 : 1);
                      final available =
                          math.min(1.0, constraints.maxHeight / height);
                      final next = Size(width * available, height * available);
                      if (next != _frame) {
                        _frame = next;
                        _offset = _clamp(_offset);
                      }
                      return GestureDetector(
                          key: const ValueKey('profileCropFrame'),
                          onScaleStart: _saving
                              ? null
                              : (d) {
                                  _startZoom = _zoom;
                                  _startOffset = _offset;
                                  _startFocal = d.localFocalPoint;
                                },
                          onScaleUpdate: _saving
                              ? null
                              : (d) => setState(() {
                                    _zoom = (_startZoom * d.scale).clamp(1, 4);
                                    final ratio = _zoom / _startZoom;
                                    final focalFromCenter = _startFocal -
                                        Offset(_frame.width / 2,
                                            _frame.height / 2);
                                    _offset = _clamp(_startOffset * ratio +
                                        (d.localFocalPoint - _startFocal) +
                                        focalFromCenter * (1 - ratio));
                                  }),
                          child: ClipPath(
                              clipper: widget.cover ? null : _CircleClipper(),
                              child: SizedBox(
                                  width: _frame.width,
                                  height: _frame.height,
                                  child: CustomPaint(
                                      painter: _CropPainter(
                                          _image!, _base * _zoom, _offset)))));
                    }))),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                        _zoom = 1;
                                        _offset = Offset.zero;
                                      }),
                              child:
                                  Text(widget.arabic ? 'إعادة ضبط' : 'Reset')),
                          const Spacer(),
                          FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(widget.arabic
                                  ? (_saving ? 'جارٍ الحفظ…' : 'حفظ الصورة')
                                  : 'Save image')),
                        ])),
                  ])),
      );
}

class _CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()..addOval(Offset.zero & size);
  @override
  bool shouldReclip(_CircleClipper oldClipper) => false;
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;
  _CropPainter(this.image, this.scale, this.offset);
  @override
  void paint(Canvas canvas, Size size) {
    final target = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2) + offset,
        width: image.width * scale,
        height: image.height * scale);
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        target,
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      image != oldDelegate.image ||
      scale != oldDelegate.scale ||
      offset != oldDelegate.offset;
}
