import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/screen_awake_service.dart';
import 'live_map_screen.dart';

/// يفتح خريطة جامعة المستخدم مباشرة، بلا شاشة مبانٍ تجريبية وسيطة.
class CampusScreen extends StatelessWidget {
  const CampusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return ScreenAwakeScope(
      child: Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'الحرم الجامعي' : 'University campus'), centerTitle: true),
        body: Stack(children: [
          const Positioned.fill(child: LiveMapScreen(embedded: true)),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: SafeArea(
              child: Material(
                elevation: 8,
                color: Colors.white.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    _CampusAction(
                      icon: Icons.public_rounded,
                      label: ar ? 'الخريطة' : 'Map',
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const LiveMapScreen(showUniversityWorldInitially: true),
                      )),
                    ),
                    _CampusAction(
                      icon: Icons.local_library_rounded,
                      label: ar ? 'الخدمات' : 'Services',
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const LiveMapScreen(initialDestinationLabel: 'student_services'),
                      )),
                    ),
                    _CampusAction(
                      icon: Icons.local_cafe_rounded,
                      label: ar ? 'أماكن الترفيه' : 'Leisure',
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const LiveMapScreen(initialDestinationLabel: 'leisure_places'),
                      )),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        ),
      ),
    );
  }
}

class _CampusAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CampusAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppTheme.primaryDark),
              const SizedBox(height: 4),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}
