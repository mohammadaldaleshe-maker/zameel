import 'dart:io';

import 'package:flutter/material.dart';

import '../services/media_cache_service.dart';

class CachedMediaImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;

  const CachedMediaImage({
    super.key,
    required this.url,
    required this.fit,
    required this.fallback,
  });

  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  late Future<String?> _path;

  @override
  void initState() {
    super.initState();
    _path = MediaCacheService.localPathForUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _path = MediaCacheService.localPathForUrl(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _path,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final path = snapshot.data;
          if (path == null || path.isEmpty) return widget.fallback;
          return Image.file(
            File(path),
            fit: widget.fit,
            errorBuilder: (_, __, ___) => widget.fallback,
          );
        },
      );
}
