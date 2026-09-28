import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _phoneHash(String value) {
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

List<String> _hashPhones(List<String> numbers) =>
    numbers.map(_phoneHash).toSet().toList(growable: false);

class ColleagueSuggestionService {
  ColleagueSuggestionService._();

  static final SupabaseClient _db = Supabase.instance.client;
  static List<String>? _cachedContactHashes;
  static Position? _cachedPosition;
  static DateTime? _signalsLoadedAt;
  static Future<void>? _signalsPending;
  static String? _cacheUserId;
  static final Map<String, (DateTime, List<Map<String, dynamic>>)> _resultCache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>> _pending = {};

  static Future<List<Map<String, dynamic>>> suggestions({
    String searchText = '',
    bool refreshSignals = false,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (_cacheUserId != userId) {
      _cacheUserId = userId;
      _resultCache.clear();
      _cachedContactHashes = null;
      _cachedPosition = null;
      _signalsLoadedAt = null;
      _signalsPending = null;
    }
    final key = '${userId ?? ''}:${searchText.trim().toLowerCase()}';
    final now = DateTime.now();
    final previous = _resultCache[key];
    if (!refreshSignals && previous != null &&
        now.difference(previous.$1) < const Duration(minutes: 5)) {
      return previous.$2.map((row) => Map<String, dynamic>.from(row)).toList();
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    final request = _fetchSuggestions(key, searchText.trim(), refreshSignals: refreshSignals);
    _pending[key] = request;
    try {
      return await request;
    } finally {
      _pending.remove(key);
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchSuggestions(String key, String searchText,
      {required bool refreshSignals}) async {
    final now = DateTime.now();
    final cacheFresh = !refreshSignals &&
        _signalsLoadedAt != null &&
        now.difference(_signalsLoadedAt!) < const Duration(minutes: 30);

    if (!cacheFresh) {
      final signalRequest = _signalsPending ??= _loadSignals(_cacheUserId);
      try {
        await signalRequest;
      } finally {
        if (identical(_signalsPending, signalRequest)) _signalsPending = null;
      }
    }

    final result = await _db.rpc('get_suggested_colleagues', params: {
      'search_text': searchText,
      'contact_hashes': _cachedContactHashes ?? const <String>[],
      'viewer_lat': _cachedPosition?.latitude,
      'viewer_lng': _cachedPosition?.longitude,
    });
    final rows = List<Map<String, dynamic>>.from(result as List? ?? const []);
    if (key.startsWith('${_db.auth.currentUser?.id ?? ''}:')) {
      _resultCache[key] = (DateTime.now(), rows);
    }
    return rows;
  }

  static Future<void> _loadSignals(String? userId) async {
    final results = await Future.wait<dynamic>([
      _readContactHashes(),
      _readPosition(),
    ]);
    if (_cacheUserId != userId) return;
    _cachedContactHashes = results[0] as List<String>;
    _cachedPosition = results[1] as Position?;
    _signalsLoadedAt = DateTime.now();
  }

  static Future<void> sendRequest(String targetUserId) async {
    if (targetUserId.isEmpty) return;
    await _db.rpc('send_colleague_request', params: {
      'target_user_id': targetUserId,
    });
    _resultCache.clear();
  }

  static Future<List<String>> _readContactHashes() async {
    final numbers = <String>[];
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        for (final contact in contacts) {
          for (final phone in contact.phones) {
            if (phone.number.trim().isNotEmpty) numbers.add(phone.number);
            if (numbers.length >= 1500) break;
          }
          if (numbers.length >= 1500) break;
        }
      }
    } catch (_) {}
    return compute(_hashPhones, numbers);
  }

  static Future<Position?> _readPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {}
    return null;
  }
}
