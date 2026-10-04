import 'dart:async';
import 'package:flutter/material.dart';

class VerifiedBadge extends StatefulWidget {
  final String? expiresAt;
  const VerifiedBadge({super.key, required this.expiresAt});
  @override
  State<VerifiedBadge> createState() => _VerifiedBadgeState();
}

class _VerifiedBadgeState extends State<VerifiedBadge> {
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant VerifiedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _schedule();
  }

  void _schedule() {
    _expiry?.cancel();
    final end = DateTime.tryParse(widget.expiresAt ?? '');
    if (end != null && end.isAfter(DateTime.now()))
      _expiry = Timer(
          end.difference(DateTime.now()) > const Duration(days: 1)
              ? const Duration(days: 1)
              : end.difference(DateTime.now()), () {
        if (mounted) {
          setState(() {});
          _schedule();
        }
      });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(widget.expiresAt ?? '');
    if (end == null || !end.isAfter(DateTime.now()))
      return const SizedBox.shrink();
    return const Padding(
        padding: EdgeInsetsDirectional.only(start: 4),
        child: Tooltip(
            message: 'حساب موثّق باشتراك شهري',
            child: Icon(Icons.verified, color: Color(0xFF1877F2), size: 18)));
  }
}
