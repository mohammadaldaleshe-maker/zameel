import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the server's list of "people this user may know" up to date so that
/// the user is told when one of them joins Zameel. Only SHA-256 hashes of phone
/// numbers leave the phone (the same hashes already used to find colleagues),
/// never names or raw numbers. It runs only after the user granted the
/// contacts permission, at most once a day.
class ContactJoinSync165 {
  ContactJoinSync165._();

  static const String _lastKey = 'zameel_contact_join_sync_165';
  static const String _grantedKey = 'zameel_contacts_granted_165';
  static const String _triedKey = 'zameel_contact_join_tried_165';
  static bool _running = false;

  static String hashPhone(String value) {
    var normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.startsWith('00')) normalized = normalized.substring(2);
    if (normalized.length == 10 && normalized.startsWith('0')) {
      normalized = '962${normalized.substring(1)}';
    }
    if (normalized.length == 9 && normalized.startsWith('7')) {
      normalized = '962$normalized';
    }
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static Future<void> sync({bool force = false}) async {
    if (_running) return;
    _running = true;
    try {
      final db = Supabase.instance.client;
      if (db.auth.currentUser == null) return;
      final prefs = await SharedPreferences.getInstance();
      final last = DateTime.tryParse(prefs.getString(_lastKey) ?? '');
      if (!force &&
          last != null &&
          DateTime.now().difference(last) < const Duration(days: 1)) {
        return;
      }
      // A failed run must not repeat on every app start: wait six hours.
      final tried = DateTime.tryParse(prefs.getString(_triedKey) ?? '');
      if (!force &&
          tried != null &&
          DateTime.now().difference(tried) < const Duration(hours: 6)) {
        return;
      }
      await prefs.setString(_triedKey, DateTime.now().toIso8601String());
      // A background run never opens a permission dialog: it only continues
      // when an earlier, explicit request already granted the permission.
      if (!force && prefs.getBool(_grantedKey) != true) return;
      if (!await FlutterContacts.requestPermission(readonly: true)) return;
      await prefs.setBool(_grantedKey, true);
      // Only phone numbers are needed: no thumbnails or photos (those make the
      // call slow and heavy on phones with many contacts), and no sorting.
      final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withThumbnail: false,
          withPhoto: false,
          sorted: false);
      final hashes = <String>{};
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          if (phone.number.trim().isEmpty) continue;
          hashes.add(hashPhone(phone.number));
          if (hashes.length >= 2000) break;
        }
        if (hashes.length >= 2000) break;
      }
      await db.rpc('zameel_sync_contact_hashes165',
          params: <String, dynamic>{'p_hashes': hashes.toList()});
      await prefs.setString(_lastKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Best effort. The next app start tries again.
    } finally {
      _running = false;
    }
  }
}
