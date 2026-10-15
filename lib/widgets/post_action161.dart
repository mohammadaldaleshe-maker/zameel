import 'package:flutter/material.dart';

class PostAction161 extends StatelessWidget {
  const PostAction161(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      this.countText,
      this.onPressed,
      this.onCountTap,
      this.iconSize = 22,
      this.fontSize = 12,
      this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12)});
  final IconData icon;
  final String label;
  final Color color;
  final String? countText;
  final VoidCallback? onPressed, onCountTap;
  final double iconSize, fontSize;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Tooltip(
      message: label,
      child: Semantics(
          button: true,
          label: label,
          enabled: onPressed != null,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                    padding: padding,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: color, size: iconSize),
                          if (countText != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                                onTap: onCountTap ?? onPressed,
                                child: Text(countText!,
                                    style: TextStyle(
                                        color: color, fontSize: fontSize)))
                          ],
                        ]))),
          )));
}
