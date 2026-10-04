import 'package:flutter/material.dart';
import '../../theme/appearance_controller.dart';
import '../../theme/app_theme.dart';

class AppearanceScreen extends StatelessWidget {
  final bool arabic;
  const AppearanceScreen({super.key, required this.arabic});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppearanceController.instance,
        builder: (context, _) => Scaffold(
          appBar:
              AppBar(title: Text(arabic ? 'مظهر التطبيق' : 'App appearance')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(arabic
                ? 'اختر المظهر المناسب لك. يبقى شعار زميل وألوان الهوية وعلامة التوثيق ثابتة.'
                : 'Choose your appearance. Zameel branding and the verification badge stay unchanged.'),
            const SizedBox(height: 16),
            for (final mode in AppAppearance.values)
              Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () async {
                      try {
                        await AppearanceController.instance.select(mode);
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(arabic
                                  ? 'تم تغيير المظهر، لكن تعذر حفظه. حاول مجددًا.'
                                  : 'Appearance changed but could not be saved. Please retry.')));
                      }
                    },
                    leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: mode == AppAppearance.original
                                ? AppTheme.signatureGradient
                                : null,
                            color: mode == AppAppearance.dark
                                ? const Color(0xFF151725)
                                : mode == AppAppearance.original
                                    ? null
                                    : const Color(0xFFF7F8FC),
                            border: Border.all(color: AppTheme.primary)),
                        child: const Icon(Icons.palette_outlined,
                            color: AppTheme.primary)),
                    title: Text(arabic
                        ? [
                            'زميل الأصلي',
                            'فاتح',
                            'داكن',
                            'حسب إعدادات الهاتف'
                          ][mode.index]
                        : [
                            'Zameel original',
                            'Light',
                            'Dark',
                            'Follow device'
                          ][mode.index]),
                    trailing: AppearanceController.instance.appearance == mode
                        ? const Icon(Icons.check_circle,
                            color: AppTheme.primary)
                        : null,
                  )),
          ]),
        ),
      );
}
