import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ColleagueSuggestionService {
  ColleagueSuggestionService._();

  static final SupabaseClient _db = Supabase.instance.client;
  static List<String>? _cachedContactHashes;
  static Position? _cachedPosition;
  static DateTime? _signalsLoadedAt;

  static String _phoneHash(String value) {
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

  static Future<List<Map<String, dynamic>>> suggestions({
    String searchText = '',
    bool refreshSignals = false,
  }) async {
    final now = DateTime.now();
    final cacheFresh = !refreshSignals &&
        _signalsLoadedAt != null &&
        now.difference(_signalsLoadedAt!) < const Duration(minutes: 30);

    if (!cacheFresh) {
      final results = await Future.wait<dynamic>([
        _readContactHashes(),
        _readPosition(),
      ]);
      _cachedContactHashes = results[0] as List<String>;
      _cachedPosition = results[1] as Position?;
      _signalsLoadedAt = now;
    }

    final result = await _db.rpc('get_suggested_colleagues', params: {
      'search_text': searchText.trim(),
      'contact_hashes': _cachedContactHashes ?? const <String>[],
      'viewer_lat': _cachedPosition?.latitude,
      'viewer_lng': _cachedPosition?.longitude,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? const []);
  }

  static Future<void> sendRequest(String targetUserId) async {
    if (targetUserId.isEmpty) return;
    await _db.rpc('send_colleague_request', params: {
      'target_user_id': targetUserId,
    });
  }

  static Future<List<String>> _readContactHashes() async {
    final hashes = <String>[];
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        for (final contact in contacts) {
          for (final phone in contact.phones) {
            if (phone.number.trim().isNotEmpty) hashes.add(_phoneHash(phone.number));
          }
        }
      }
    } catch (_) {}
    return hashes.toSet().take(1500).toList(growable: false);
  }

  static Future<Position?> _readPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        );
      }
    } catch (_) {}
    return null;
  }
}
