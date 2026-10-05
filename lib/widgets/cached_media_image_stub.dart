import 'package:flutter/material.dart';
import '../services/secure_media_service.dart';

class CachedMediaImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final int? cacheWidth;
  final VoidCallback? onError;
  const CachedMediaImage(
      {super.key,
      required this.url,
      required this.fit,
      required this.fallback,
      this.cacheWidth,
      this.onError});
  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  late Future<String> _url;
  bool _errorReported = false;
  @override
  void initState() {
    super.initState();
    _url = SecureMediaService.resolve(widget.url)
        .timeout(const Duration(seconds: 12));
  }

  @override
  void didUpdateWidget(covariant CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _errorReported = false;
      _url = SecureMediaService.resolve(widget.url)
          .timeout(const Duration(seconds: 12));
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
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _url,
        builder: (_, snapshot) => snapshot.hasError
            ? _errorFallback()
            : snapshot.hasData
                ? Image.network(snapshot.data!,
                    fit: widget.fit,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => _errorFallback())
                : const Center(child: CircularProgressIndicator()),
      );
}
