import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/appearance_controller.dart';
import '../profile/appearance_screen.dart';
import '../../services/native_incoming_call_service.dart';

/// Device presentation and navigation preferences, separate from account data.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key, this.onCustomizeFloatingMenu});
  final VoidCallback? onCustomizeFloatingMenu;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final language = context.watch<LanguageProvider>();
    final ar = language.isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'إعدادات التطبيق' : 'App settings')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: ListTile(
            key: const ValueKey('appAppearanceSettings'),
            leading: const Icon(Icons.palette_outlined),
            title: Text(ar ? 'مظهر التطبيق' : 'App appearance'),
            subtitle: Text(ar
                ? 'الأصلي، الفاتح، الداكن أو حسب الهاتف'
                : 'Original, light, dark or follow device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppearanceScreen(arabic: ar),
                )),
          )),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('appLanguageSettings'),
              initialValue: language.currentLanguage,
              decoration: InputDecoration(
                labelText: ar ? 'لغة التطبيق' : 'App language',
                prefixIcon: const Icon(Icons.language),
              ),
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) language.changeLanguage(value);
              },
            ),
          )),
          if (NativeIncomingCallService.supported)
            Card(
                child: ListTile(
              leading: const Icon(Icons.call_rounded),
              title:
                  Text(ar ? 'عرض المكالمات الواردة' : 'Incoming call display'),
              subtitle: Text(ar
                  ? 'السماح بظهور شاشة الرد أثناء قفل الهاتف'
                  : 'Allow the answer screen on the lock screen'),
              onTap: () async {
                final allowed = await NativeIncomingCallService.canFullScreen();
                if (!allowed) {
                  await NativeIncomingCallService.requestFullScreen();
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ar
                          ? 'عرض المكالمات بملء الشاشة مسموح'
                          : 'Full-screen incoming calls are allowed')));
                }
              },
            )),
          if (onCustomizeFloatingMenu != null)
            Card(
                child: ListTile(
              key: const ValueKey('appFloatingMenuSettings'),
              leading: const Icon(Icons.tune_rounded),
              title: Text(ar ? 'تخصيص الزر العائم' : 'Customize floating menu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onCustomizeFloatingMenu!();
              },
            )),
        ]),
      ),
    );
  }
}
