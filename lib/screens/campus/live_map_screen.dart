import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';

class LiveMapScreen extends StatefulWidget {
  final bool embedded;
  final String? initialQuery;
  final String? initialDestinationLabel;

  const LiveMapScreen({
    super.key,
    this.embedded = false,
    this.initialQuery,
    this.initialDestinationLabel,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _UniversityResult {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;

  const _UniversityResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _map = MapController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Position? _position;
  StreamSubscription<Position>? _positionSub;
  LatLng? _universityCenter;
  LatLng? _destination;
  List<LatLng> _route = const [];
  double? _distanceMeters;
  double? _durationSeconds;

  List<_UniversityResult> _universityResults = const [];
  bool _searchingUniversities = false;
  bool _showUniversityResults = false;
  bool _loading = true;
  bool _routing = false;
  bool _navigationMode = false;
  String? _selectedUniversityName;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _search.text = widget.initialQuery!.trim();
    }
    _startLocation();
    if (_search.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchUniversities());
    }
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('خدمة الموقع غير مفعلة على الهاتف');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('لم يتم منح صلاحية الموقع');
      }

      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
      _position = first;
      if (!mounted) return;
      setState(() => _loading = false);
      if (_universityCenter == null) {
        _map.move(LatLng(first.latitude, first.longitude), 16);
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) {
        _position = p;
        if (mounted) setState(() {});
        if (_navigationMode && _destination != null) {
          _routeTo(_destination!, keepDestination: true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _universityResults = const [];
        _showUniversityResults = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), _searchUniversities);
  }

  Future<void> _searchUniversities() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _searchingUniversities = true;
      _showUniversityResults = true;
      _error = null;
    });

    try {
      final query = q.toLowerCase().contains('university') || q.contains('جامعة')
          ? q
          : '$q university';
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'addressdetails': '1',
        'dedupe': '1',
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'Zameel/1.3.8 (campus-map)',
        'Accept-Language': 'ar,en',
      });
      if (response.statusCode != 200) {
        throw Exception('تعذر البحث عن الجامعة');
      }

      final raw = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      final results = raw.map((item) {
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) return null;
        final display = item['display_name']?.toString() ?? q;
        final localName = item['name']?.toString() ?? q;
        return _UniversityResult(
          name: localName,
          displayName: display,
          latitude: lat,
          longitude: lon,
        );
      }).whereType<_UniversityResult>().toList();

      if (!mounted) return;
      setState(() {
        _universityResults = results;
        _searchingUniversities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchingUniversities = false;
        _universityResults = const [];
        _error = e.toString();
      });
    }
  }

  void _selectUniversity(_UniversityResult result) {
    _searchFocus.unfocus();
    setState(() {
      _selectedUniversityName = result.name;
      _universityCenter = LatLng(result.latitude, result.longitude);
      _destination = null;
      _route = const [];
      _distanceMeters = null;
      _durationSeconds = null;
      _showUniversityResults = false;
      _navigationMode = false;
      _error = null;
      _search.text = result.name;
    });
    _map.move(_universityCenter!, 17);
  }

  Future<void> _routeTo(LatLng destination, {bool keepDestination = false}) async {
    final p = _position;
    if (p == null) {
      setState(() => _error = 'تعذر تحديد موقعك الحالي');
      return;
    }

    setState(() {
      _destination = destination;
      _routing = true;
      _error = null;
    });

    try {
      final from = '${p.longitude},${p.latitude}';
      final to = '${destination.longitude},${destination.latitude}';
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/$from;$to'
        '?overview=full&steps=true&geometries=geojson',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'Zameel/1.3.8 (campus-map)',
      });
      if (response.statusCode != 200) {
        throw Exception('تعذر حساب المسار');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? const [];
      if (routes.isEmpty) {
        throw Exception('لا يوجد مسار مشي متاح لهذه النقطة');
      }
      final route = Map<String, dynamic>.from(routes.first as Map);
      final geometry = Map<String, dynamic>.from(route['geometry'] as Map);
      final coords = (geometry['coordinates'] as List)
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _route = coords;
        _distanceMeters = (route['distance'] as num?)?.toDouble();
        _durationSeconds = (route['duration'] as num?)?.toDouble();
        _routing = false;
        if (!keepDestination) _navigationMode = true;
      });
      if (coords.length >= 2) {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(coords),
            padding: const EdgeInsets.all(60),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routing = false;
        _error = e.toString();
      });
    }
  }

  void _useMapTap(TapPosition _, LatLng point) {
    if (_universityCenter == null) {
      setState(() => _error = 'ابحث عن الجامعة أولًا');
      return;
    }
    _navigationMode = true;
    _routeTo(point);
  }

  void _startCampusNavigation() {
    if (_universityCenter == null) {
      setState(() => _error = 'ابحث عن الجامعة أولًا');
      return;
    }
    setState(() {
      _navigationMode = true;
      _destination = null;
      _route = const [];
      _distanceMeters = null;
      _durationSeconds = null;
      _error = 'اختر المبنى أو النقطة داخل الحرم بالضغط على الخريطة';
    });
    _map.move(_universityCenter!, 18);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _positionSub?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  Widget _buildSearchPanel(bool ar) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _searchUniversities(),
                  decoration: InputDecoration(
                    hintText: widget.initialDestinationLabel != null
                        ? (ar
                            ? 'ابحث عن الجامعة لموقع ${widget.initialDestinationLabel}'
                            : 'Search university for ${widget.initialDestinationLabel}')
                        : (ar ? 'ابحث عن اسم الجامعة' : 'Search university name'),
                    prefixIcon: const Icon(Icons.school_rounded),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              IconButton(
                onPressed: _searchingUniversities ? null : _searchUniversities,
                icon: _searchingUniversities
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded),
              ),
            ],
          ),
          if (_showUniversityResults)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _universityResults.isEmpty && !_searchingUniversities
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(ar ? 'لا توجد جامعات مطابقة' : 'No matching universities'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _universityResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = _universityResults[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withAlpha(24),
                            child: Icon(Icons.school_rounded, color: AppTheme.primary),
                          ),
                          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _selectUniversity(item),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(bool ar) {
    final current = _position == null
        ? const LatLng(31.9539, 35.9106)
        : LatLng(_position!.latitude, _position!.longitude);
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _universityCenter ?? current,
        initialZoom: _universityCenter == null ? 16 : 17,
        onTap: _useMapTap,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zameel.app',
        ),
        if (_route.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(points: _route, strokeWidth: 6, color: AppTheme.primary),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_position != null)
              Marker(
                point: current,
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 28),
                ),
              ),
            if (_universityCenter != null)
              Marker(
                point: _universityCenter!,
                width: 52,
                height: 52,
                child: Tooltip(
                  message: _selectedUniversityName ?? (ar ? 'الجامعة' : 'University'),
                  child: Icon(Icons.school_rounded, color: AppTheme.primary, size: 46),
                ),
              ),
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 48,
                height: 48,
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF18D4C6), size: 46),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _buildBody(bool ar) {
    return Stack(
      children: [
        _buildMap(ar),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _buildSearchPanel(ar),
        ),
        if (_selectedUniversityName != null)
          Positioned(
            top: 116,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedUniversityName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _routing ? null : _startCampusNavigation,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: Text(ar ? 'توجيه داخل الحرم' : 'Campus navigation'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_navigationMode && _selectedUniversityName != null)
          Positioned(
            bottom: 82,
            left: 12,
            right: 12,
            child: Card(
              color: Colors.white,
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  ar ? 'وضع التوجيه فعال: اضغط على المبنى أو نقطة الوجهة داخل الحرم.' : 'Navigation mode: tap a building or destination inside the campus.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Positioned(
            bottom: 18,
            left: 12,
            right: 12,
            child: Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(ar ? 'معلومة الخريطة' : 'Map information'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: () => setState(() => _error = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
        if (_distanceMeters != null && _durationSeconds != null)
          Positioned(
            bottom: 18,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  ar
                      ? '${(_distanceMeters! / 1000).toStringAsFixed(2)} كم • ${(_durationSeconds! / 60).round()} دقيقة'
                      : '${(_distanceMeters! / 1000).toStringAsFixed(2)} km • ${(_durationSeconds! / 60).round()} min',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 92,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: widget.embedded ? 'campus_my_location' : 'live_map_my_location',
            onPressed: () {
              if (_position != null) {
                _map.move(LatLng(_position!.latitude, _position!.longitude), 18);
              }
            },
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final content = Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: _buildBody(ar),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? '🗺️ الملاحة داخل زميل' : '🗺️ Zameel Navigation'),
        actions: [
          IconButton(
            onPressed: () {
              if (_route.length >= 2) {
                _map.fitCamera(
                  CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(_route),
                    padding: const EdgeInsets.all(60),
                  ),
                );
              }
            },
            icon: const Icon(Icons.route_rounded),
            tooltip: ar ? 'عرض المسار' : 'Show route',
          ),
        ],
      ),
      body: content,
    );
  }
}
