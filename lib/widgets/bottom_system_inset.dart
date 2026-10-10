import 'package:flutter/material.dart';

/// Reserves the system navigation area once, while retaining keyboard insets.
class BottomSystemInset extends StatelessWidget {
  const BottomSystemInset({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        left: false,
        right: false,
        child: child,
      );
}
