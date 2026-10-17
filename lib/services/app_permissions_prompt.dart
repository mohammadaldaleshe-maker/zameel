import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_join_sync165.dart';

/// Explains and requests the permissions Zameel needs once the home screen is
/// visible. Notifications are already requested by the push service at start.
/// Every feature still asks again at the moment of use, so refusing here never
/// blocks the app.
class AppPermissionsPrompt {
  AppPermissionsPrompt._();

  static const String _doneKey = 'zameel_permissions_done_165';
  static const String _shownKey = 'zameel_permissions_shown_165';
  static bool _running = false;

  static Future<void> maybeAsk(BuildContext context, bool arabic) async {
    if (_running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) == true) return;
      final shown = prefs.getInt(_shownKey) ?? 0;
      // Ask at most twice: a user who postponed twice is left alone.
      if (shown >= 2) return;
      await prefs.setInt(_shownKey, shown + 1);
      // Let the first frame and the feed settle before covering the screen.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(arabic
                ? 'أذونات تحتاجها زميل'
                : 'Permissions Zameel needs'),
            content: Text(arabic
                ? 'لتعمل زميل بشكل كامل نحتاج إلى:\n'
                    '• الإشعارات: لوصول الرسائل والمكالمات\n'
                    '• المايكروفون: للمكالمات والرسائل الصوتية\n'
                    '• الكاميرا: لمكالمات الفيديو\n'
                    '• الموقع: لخريطة الحرم واقتراح الزملاء القريبين\n'
                    '• جهات الاتصال: لإيجاد معارفك على زميل\n\n'
                    'يمكنك تغيير أي إذن لاحقاً من إعدادات الهاتف.'
                : 'To work fully Zameel needs:\n'
                    '• Notifications: messages and calls\n'
                    '• Microphone: calls and voice messages\n'
                    '• Camera: video calls\n'
                    '• Location: campus map and nearby colleagues\n'
                    '• Contacts: find people you know on Zameel\n\n'
                    'You can change any permission later in phone settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(arabic ? 'لاحقاً' : 'Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(arabic ? 'السماح' : 'Allow'),
              ),
            ],
          ),
        ),
      );
      if (agreed != true) return;
      await prefs.setBool(_doneKey, true);
      await _requestMicrophone();
      await _requestCamera();
      await _requestLocation();
      final contacts = await _requestContacts();
      if (contacts) {
        await ContactJoinSync165.sync(force: true);
      }
    } catch (_) {
      // Permission prompts are best effort and must never break the home screen.
    } finally {
      _running = false;
    }
  }

  static Future<void> _requestMicrophone() async {
    final recorder = AudioRecorder();
    try {
      await recorder.hasPermission();
    } catch (_) {
    } finally {
      try {
        await recorder.dispose();
      } catch (_) {}
    }
  }

  static Future<void> _requestCamera() async {
    try {
      final stream = await navigator.mediaDevices
          .getUserMedia(<String, dynamic>{'audio': false, 'video': true});
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    } catch (_) {}
  }

  static Future<void> _requestLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  static Future<bool> _requestContacts() async {
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (_) {
      return false;
    }
  }
}
