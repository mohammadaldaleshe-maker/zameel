import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/appearance_controller.dart';

class PostMediaFrame extends StatelessWidget {
  const PostMediaFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppTheme.adaptiveGlassBorder, width: 1.5)),
        child: child);
  }
}
