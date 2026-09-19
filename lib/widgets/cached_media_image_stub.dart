import 'package:flutter/material.dart';

class CachedMediaImage extends StatelessWidget {
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
  Widget build(BuildContext context) => Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
      );
}
