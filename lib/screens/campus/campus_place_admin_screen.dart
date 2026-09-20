import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CampusPlaceAdminScreen extends StatefulWidget {
  final String initialUniversity;
  final LatLng initialCenter;
  const CampusPlaceAdminScreen({super.key, required this.initialUniversity, required this.initialCenter});
  @override State<CampusPlaceAdminScreen> createState() => _CampusPlaceAdminScreenState();
}

class _CampusPlaceAdminScreenState extends State<CampusPlaceAdminScreen> {
  final _db = Supabase.instance.client;
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _description = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  LatLng? _selected;
  String _category = 'faculty';
  bool _loading = true;
  bool _saving = false;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final rows = await _db.from('campus_partner_places').select().eq('university_name', widget.initialUniversity).order('created_at', ascending: false);
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _add() async {
    if (_selected == null || _nameAr.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدد الموقع واكتب اسم المكان.'))); return;
    }
    setState(() => _saving = true);
    try {
      await _db.from('campus_partner_places').insert({
        'owner_id': _db.auth.currentUser!.id,
        'university_name': widget.initialUniversity,
        'name_ar': _nameAr.text.trim(),
        'name_en': _nameEn.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'latitude': _selected!.latitude,
        'longitude': _selected!.longitude,
        'status': 'approved',
      });
      _nameAr.clear(); _nameEn.clear(); _description.clear(); _selected = null;
      await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة المكان: $e'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _setStatus(String id, String status) async {
    await _db.from('campus_partner_places').update({'status': status}).eq('id', id);
    await _load();
  }

  @override Widget build(BuildContext context) {
    final center = _selected ?? widget.initialCenter;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة أماكن الحرم')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(12), children: [
        Text(widget.initialUniversity, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SizedBox(height: 310, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 16, onTap: (_, point) => setState(() => _selected = point)),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.zameel.app'),
            MarkerLayer(markers: [
              if (_selected != null) Marker(point: _selected!, width: 55, height: 55, child: const Icon(Icons.location_pin, color: Colors.red, size: 48)),
              for (final row in _rows) Marker(point: LatLng((row['latitude'] as num).toDouble(), (row['longitude'] as num).toDouble()), width: 42, height: 42, child: const Icon(Icons.place, color: Colors.teal, size: 36)),
            ]),
            RichAttributionWidget(attributions: const [TextSourceAttribution('OpenStreetMap contributors')]),
          ],
        ))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('اضغط على الخريطة لتحديد المكان بدقة. يمكنك التكبير قبل الاختيار.')),
        TextField(controller: _nameAr, decoration: const InputDecoration(labelText: 'اسم المكان بالعربية', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _nameEn, decoration: const InputDecoration(labelText: 'اسم المكان بالإنجليزية', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: 'faculty', child: Text('كلية أو مبنى')),
          DropdownMenuItem(value: 'gate', child: Text('بوابة')),
          DropdownMenuItem(value: 'library', child: Text('مكتبة')),
          DropdownMenuItem(value: 'bookshop', child: Text('متجر كتب')),
          DropdownMenuItem(value: 'printing', child: Text('طباعة وقرطاسية')),
          DropdownMenuItem(value: 'cafe', child: Text('مقهى')),
          DropdownMenuItem(value: 'restaurant', child: Text('مطعم')),
          DropdownMenuItem(value: 'leisure', child: Text('ترفيه')),
          DropdownMenuItem(value: 'student_service', child: Text('خدمة طلابية')),
        ], onChanged: (value) => setState(() => _category = value ?? 'faculty')),
        const SizedBox(height: 8),
        TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف اختياري', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _saving ? null : _add, icon: const Icon(Icons.add_location_alt_rounded), label: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة واعتماد المكان')),
        const Divider(height: 34),
        const Text('الأماكن المسجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        for (final row in _rows) Card(child: ListTile(
          leading: const Icon(Icons.place_rounded), title: Text(row['name_ar']?.toString() ?? ''),
          subtitle: Text('${row['category']} • ${row['status']}'),
          trailing: PopupMenuButton<String>(onSelected: (value) => _setStatus(row['id'].toString(), value), itemBuilder: (_) => const [
            PopupMenuItem(value: 'approved', child: Text('اعتماد')),
            PopupMenuItem(value: 'suspended', child: Text('إخفاء')),
            PopupMenuItem(value: 'rejected', child: Text('رفض')),
          ]),
        )),
      ]),
    );
  }

  @override void dispose() { _nameAr.dispose(); _nameEn.dispose(); _description.dispose(); super.dispose(); }
}
