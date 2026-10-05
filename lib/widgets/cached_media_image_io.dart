import 'dart:io';

import 'package:flutter/material.dart';

import '../services/media_cache_service.dart';

class CachedMediaImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final int? cacheWidth;
  final VoidCallback? onError;

  const CachedMediaImage({
    super.key,
    required this.url,
    required this.fit,
    required this.fallback,
    this.cacheWidth,
    this.onError,
  });

  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  late Future<String?> _path;

  bool _failed = false;
  bool _errorReported = false;
  String _identity(String url) => MediaCacheService.identity(url);

  Future<String?> _load() async {
    final path = await MediaCacheService.localPathForUrl(widget.url)
        .timeout(const Duration(seconds: 12), onTimeout: () => null);
    _failed = path == null;
    return path;
  }

  @override
  void initState() {
    super.initState();
    _path = _load();
  }

  @override
  void didUpdateWidget(covariant CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget.url) != _identity(widget.url) ||
        (_failed && oldWidget.url != widget.url)) {
      _failed = false;
      _errorReported = false;
      _path = _load();
    }
  }

  Widget _errorFallback() {
    if (!_errorReported && widget.onError != null) {
      _errorReported = true;
      final failedUrl = widget.url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.url == failedUrl) widget.onError?.call();
      });
    }
    return widget.fallback;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _path,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final path = snapshot.data;
          if (path == null || path.isEmpty) return _errorFallback();
          return Image.file(
            File(path),
            fit: widget.fit,
            cacheWidth: widget.cacheWidth ??
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(1, 1440)
                    .toInt(),
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _errorFallback(),
          );
        },
      );
}
