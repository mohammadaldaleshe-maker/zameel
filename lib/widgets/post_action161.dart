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
      this.padding = const EdgeInsets.symmetric(vertical: 2)});
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
      child: Padding(
          padding: padding,
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : (countText == null ? 44.0 : 76.0);
            final iconWidth = countText == null
                ? width.clamp(24.0, 44.0)
                : (width * .55).clamp(24.0, 44.0);
            return Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                      button: true,
                      label: label,
                      child: InkWell(
                          onTap: onPressed,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                              width: iconWidth,
                              height: 48,
                              child:
                                  Icon(icon, color: color, size: iconSize)))),
                  if (countText != null)
                    Semantics(
                        button: true,
                        label: onCountTap == null
                            ? '$label $countText'
                            : 'عرض $label $countText',
                        child: InkWell(
                            onTap: onCountTap ?? onPressed,
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                                width: (width - iconWidth).clamp(0.0, 1000.0),
                                height: 48,
                                child: Center(
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(countText!,
                                            style: TextStyle(
                                                color: color,
                                                fontSize: fontSize)))))))
                ]);
          })));
}
