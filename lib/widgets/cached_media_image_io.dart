import 'dart:io';

import 'package:flutter/material.dart';

import '../services/media_cache_service.dart';

class CachedMediaImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final int? cacheWidth;

  const CachedMediaImage({
    super.key,
    required this.url,
    required this.fit,
    required this.fallback,
    this.cacheWidth,
  });

  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  late Future<String?> _path;

  String _identity(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('/storage/v1/object/sign/')) {
      return uri.replace(query: '').toString();
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _path = MediaCacheService.localPathForUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget.url) != _identity(widget.url)) {
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
            cacheWidth: widget.cacheWidth,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => widget.fallback,
          );
        },
      );
}
