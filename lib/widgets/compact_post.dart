import 'package:flutter/material.dart';

/// Compact width and text keep layout, gestures and accessibility in agreement.
class CompactPost extends StatelessWidget {
  final Widget child;
  const CompactPost({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
          widthFactor: .85,
          child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler:
                      _PostTextScaler(MediaQuery.textScalerOf(context))),
              child: child)));
}

class _PostTextScaler extends TextScaler {
  final TextScaler parent;
  const _PostTextScaler(this.parent);
  @override
  double scale(double size) => parent.scale(size * .85);
  @override
  double get textScaleFactor => scale(14) / 14;
}
