import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../profile/profile_screen.dart';

class SuggestedColleaguesSection extends StatefulWidget {
  const SuggestedColleaguesSection({super.key});

  @override
  State<SuggestedColleaguesSection> createState() => _SuggestedColleaguesSectionState();
}

class _SuggestedColleaguesSectionState extends State<SuggestedColleaguesSection> {
  static List<String>? _cachedContactHashes;
  static Position? _cachedPosition;
  static DateTime? _signalsLoadedAt;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _phoneHash(String value) {
    var normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.startsWith('00')) normalized = normalized.substring(2);
    if (normalized.length == 10 && normalized.startsWith('0')) normalized = '962${normalized.substring(1)}';
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<void> _load([String searchText = '']) async {
    if (mounted) setState(() => _loading = true);
    await _requestSuggestions(searchText, const [], null);
    if (!mounted) return;
    final cachedAt = _signalsLoadedAt;
    if (_cachedContactHashes != null && cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 30)) {
      await _requestSuggestions(searchText, _cachedContactHashes!, _cachedPosition);
      return;
    }
    final results = await Future.wait<dynamic>([
      _readContactHashes(),
      _readPosition(),
    ]);
    _cachedContactHashes = results[0] as List<String>;
    _cachedPosition = results[1] as Position?;
    _signalsLoadedAt = DateTime.now();
    await _requestSuggestions(searchText, _cachedContactHashes!, _cachedPosition);
  }

  Future<List<String>> _readContactHashes() async {
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

  Future<Position?> _readPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
        return p;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _requestSuggestions(
    String searchText,
    List<String> hashes,
    Position? position,
  ) async {
    try {
      final result = await Supabase.instance.client.rpc('get_suggested_colleagues', params: {
        'search_text': searchText.trim(),
        'contact_hashes': hashes,
        'viewer_lat': position?.latitude,
        'viewer_lng': position?.longitude,
      });
      if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(result as List));
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(Map<String, dynamic> item) async {
    try {
      await Supabase.instance.client.rpc('send_colleague_request', params: {'target_user_id': item['user_id']});
      if (mounted) setState(() => item['request_status'] = 'pending');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال طلب الزمالة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()));
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.group_add_outlined, color: AppTheme.primary), SizedBox(width: 8), Text('زملاء مقترحون', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))]),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _load,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث عن زملاء آخرين', suffixIcon: IconButton(onPressed: () => _load(_search.text), icon: const Icon(Icons.arrow_forward)), isDense: true, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            const Padding(padding: EdgeInsets.all(10), child: Text('لا توجد اقتراحات جديدة حاليًا.'))
          else
            SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final u = _items[i];
                  final image = u['profile_image']?.toString();
                  final pending = u['request_status'] == 'pending';
                  return SizedBox(width: 126, child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: u['user_id']?.toString()))),
                    child: Column(children: [
                      CircleAvatar(radius: 31, backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person, size: 30) : null),
                      const SizedBox(height: 5),
                      Text(u['name']?.toString() ?? 'زميل', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(u['match_reason']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      const SizedBox(height: 5),
                      SizedBox(width: double.infinity, height: 31, child: FilledButton.tonal(onPressed: pending ? null : () => _add(u), child: Text(pending ? 'تم الإرسال' : 'إضافة', style: const TextStyle(fontSize: 11)))),
                    ]),
                  ));
                },
              ),
            ),
        ]),
      ),
    );
  }
}
