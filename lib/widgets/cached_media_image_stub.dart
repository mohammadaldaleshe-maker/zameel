import 'package:flutter/material.dart';
import '../services/secure_media_service.dart';

class CachedMediaImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final int? cacheWidth;
  const CachedMediaImage({super.key, required this.url, required this.fit,
    required this.fallback, this.cacheWidth});
  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}
class _CachedMediaImageState extends State<CachedMediaImage> {
  late Future<String> _url;
  @override
  void initState() { super.initState(); _url = SecureMediaService.resolve(widget.url); }
  @override
  void didUpdateWidget(covariant CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _url = SecureMediaService.resolve(widget.url);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(future: _url,
    builder: (_, snapshot) => snapshot.hasError ? widget.fallback :
        snapshot.hasData ? Image.network(snapshot.data!, fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => widget.fallback) :
        const Center(child: CircularProgressIndicator()),
  );
}
