import 'package:flutter/material.dart';

/// Post metadata keeps its normal width and typography.
class CompactPost extends StatelessWidget {
  final Widget child;
  const CompactPost({super.key, required this.child});
  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: _PostTextScaler(MediaQuery.textScalerOf(context))),
        child: child,
      );
}

double postMediaHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height * .65;

class _PostTextScaler extends TextScaler {
  final TextScaler parent;
  const _PostTextScaler(this.parent);
  @override
  double scale(double size) => parent.scale(size * .85);
  @override
  double get textScaleFactor => scale(14) / 14;
}
