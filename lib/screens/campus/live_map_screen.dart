import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import 'campus_place_admin_screen.dart';

class LiveMapScreen extends StatefulWidget {
  final bool embedded;
  final String? initialQuery;
  final String? initialDestinationLabel;
  final bool showUniversityWorldInitially;
  const LiveMapScreen({
    super.key,
    this.embedded = false,
    this.initialQuery,
    this.initialDestinationLabel,
    this.showUniversityWorldInitially = false,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _CampusData {
  final String id;
  final String ar;
  final String en;
  final LatLng center;
  final double radius;
  const _CampusData(this.id, this.ar, this.en, this.center, this.radius);

  bool matches(String value) {
    final q = value.trim().toLowerCase();
    return q.isNotEmpty &&
        (ar.toLowerCase().contains(q) ||
            en.toLowerCase().contains(q) ||
            q.contains(ar.toLowerCase()));
  }
}

class _CampusPlace {
  final String id;
  final String nameAr;
  final String nameEn;
  final String category;
  final LatLng point;
  const _CampusPlace(
      this.id, this.nameAr, this.nameEn, this.category, this.point);
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with TickerProviderStateMixin {
  final _db = Supabase.instance.client;
  final _map = MapController();
  late final AnimationController _walk;
  late final AnimationController _measure;
  LatLng? _measureFrom;
  LatLng? _measureTo;
  bool _measuring = false;
  StreamSubscription<Position>? _positionStream;
  List<_CampusData> _campuses = const [];
  List<_CampusPlace> _places = const [];
  _CampusData? _campus;
  _CampusData? _registeredCampus;
  _CampusPlace? _destination;
  LatLng? _customDestination;
  List<LatLng> _routePoints = const [];
  String _travelMode = 'walking';
  double _routeMeters = 0;
  double _routeSeconds = 0;
  bool _routing = false;
  bool _activityActive = false;
  DateTime? _activityStartedAt;
  LatLng? _activityLastPoint;
  double _todayWalkMeters = 0;
  int _todayWalkSeconds = 0;
  Position? _position;
  String _registeredUniversity = '';
  String _role = 'student';
  String _gender = 'male';
  bool _loading = true;
  bool _world = false;

  bool get _canManage =>
      _role == 'admin' || _role == 'owner' || _role == 'campus_manager';
  LatLng? get _destinationPoint => _destination?.point ?? _customDestination;

  @override
  void initState() {
    super.initState();
    _world = widget.showUniversityWorldInitially;
    _walk = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _measure = AnimationController(vsync: this);
    _measure.addListener(() {
      if (mounted) setState(() {});
    });
    _measure.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _measure.reverse();
        });
      } else if (status == AnimationStatus.dismissed && _measuring) {
        if (mounted) setState(() => _measuring = false);
      }
    });
    _loadActivity();
    _load();
  }

  String get _activityKey =>
      'campus_activity_${DateTime.now().toIso8601String().substring(0, 10)}';
  Future<void> _loadActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activityKey);
    if (raw == null) return;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (mounted)
      setState(() {
        _todayWalkMeters = (value['meters'] as num?)?.toDouble() ?? 0;
        _todayWalkSeconds = (value['seconds'] as num?)?.toInt() ?? 0;
      });
  }

  Future<void> _saveActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activityKey,
        jsonEncode({'meters': _todayWalkMeters, 'seconds': _todayWalkSeconds}));
  }

  Future<void> _load() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid != null) {
        final user = await _db
            .from('users')
            .select('university,role,gender')
            .eq('id', uid)
            .maybeSingle();
        _registeredUniversity = user?['university']?.toString().trim() ?? '';
        _role = user?['role']?.toString().toLowerCase() ?? 'student';
        _gender = (_role == 'company' || _role == 'business')
            ? 'male'
            : (user?['gender']?.toString().toLowerCase() == 'female'
                ? 'female'
                : 'male');
      }
      final rows = await _db
          .from('university_campuses')
          .select(
              'id,name_ar,name_en,center_latitude,center_longitude,campus_radius_meters')
          .eq('is_active', true);
      _campuses = List<Map<String, dynamic>>.from(rows)
          .map((row) => _CampusData(
                row['id'].toString(),
                row['name_ar']?.toString() ?? '',
                row['name_en']?.toString() ?? '',
                LatLng((row['center_latitude'] as num).toDouble(),
                    (row['center_longitude'] as num).toDouble()),
                (row['campus_radius_meters'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      _campuses = const [
        _CampusData('uj', 'الجامعة الأردنية', 'The University of Jordan',
            LatLng(32.0138, 35.8720), 1100),
        _CampusData(
            'just',
            'جامعة العلوم والتكنولوجيا الأردنية',
            'Jordan University of Science and Technology',
            LatLng(32.4931, 35.9870),
            1700),
      ];
    }
    final requested = widget.initialQuery?.trim().isNotEmpty == true
        ? widget.initialQuery!.trim()
        : _registeredUniversity;
    for (final campus in _campuses) {
      if (campus.matches(requested)) {
        _registeredCampus = campus;
        break;
      }
    }
    if (_campuses.isNotEmpty) _campus = _registeredCampus ?? _campuses.first;
    await _startLocation();
    if (!_world && _campuses.isNotEmpty)
      await _openCampus(_registeredCampus ?? _campuses.first);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCampus(_CampusData campus) async {
    _campus = campus;
    _world = false;
    _destination = null;
    _customDestination = null;
    _routePoints = const [];
    try {
      final rows = await _db
          .from('campus_partner_places')
          .select('id,name_ar,name_en,category,latitude,longitude')
          .eq('university_name', campus.ar)
          .eq('status', 'approved');
      _places = List<Map<String, dynamic>>.from(rows)
          .map((row) => _CampusPlace(
                row['id'].toString(),
                row['name_ar']?.toString() ?? '',
                row['name_en']?.toString() ?? '',
                row['category']?.toString() ?? 'place',
                LatLng((row['latitude'] as num).toDouble(),
                    (row['longitude'] as num).toDouble()),
              ))
          .toList();
    } catch (_) {
      _places = const [];
    }
    _selectRequestedCategory();
    if (mounted) setState(() {});
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _map.move(campus.center, 16.4));
  }

  void _selectRequestedCategory() {
    final request = widget.initialDestinationLabel;
    final categories = request == 'student_services'
        ? {'library', 'bookshop', 'printing', 'student_service'}
        : request == 'leisure_places'
            ? {'cafe', 'restaurant', 'leisure', 'stadium'}
            : <String>{};
    if (categories.isEmpty) return;
    final candidates =
        _places.where((place) => categories.contains(place.category)).toList();
    if (candidates.isEmpty) return;
    final origin = _position == null
        ? _campus!.center
        : LatLng(_position!.latitude, _position!.longitude);
    candidates.sort((a, b) => const Distance()
        .distance(origin, a.point)
        .compareTo(const Distance().distance(origin, b.point)));
    _destination = candidates.first;
  }

  Future<void> _startLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      _position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best, distanceFilter: 2));
      _positionStream = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.best, distanceFilter: 2))
          .listen((value) {
        if (!mounted) return;
        final nowPoint = LatLng(value.latitude, value.longitude);
        if (_activityActive && _activityLastPoint != null) {
          final delta =
              const Distance().distance(_activityLastPoint!, nowPoint);
          if (delta >= 1 && delta < 80) _todayWalkMeters += delta;
          _todayWalkSeconds =
              DateTime.now().difference(_activityStartedAt!).inSeconds;
          _activityLastPoint = nowPoint;
          _saveActivity();
        }
        setState(() => _position = value);
        if (value.speed > .35 && !_walk.isAnimating)
          _walk.repeat(reverse: true);
        if (value.speed <= .35 && _walk.isAnimating) {
          _walk.stop();
          _walk.value = 0;
        }
        final campus = _campus;
        if (campus != null && _insideCampus(value, campus))
          _map.move(LatLng(value.latitude, value.longitude), _map.camera.zoom);
      });
    } catch (_) {}
  }

  bool _insideCampus(Position position, _CampusData campus) =>
      Geolocator.distanceBetween(position.latitude, position.longitude,
          campus.center.latitude, campus.center.longitude) <=
      campus.radius + 100;

  LatLng get _avatarPoint {
    final campus = _campus!;
    final position = _position;
    return position != null
        ? LatLng(position.latitude, position.longitude)
        : campus.center;
  }

  LatLng get _displayAvatarPoint {
    if (!_measuring || _measureFrom == null || _measureTo == null)
      return _avatarPoint;
    final t = Curves.easeInOut.transform(_measure.value);
    return LatLng(
      _measureFrom!.latitude +
          (_measureTo!.latitude - _measureFrom!.latitude) * t,
      _measureFrom!.longitude +
          (_measureTo!.longitude - _measureFrom!.longitude) * t,
    );
  }

  Future<void> _searchUniversity(bool ar) async {
    final selected = await showSearch<_CampusData?>(
        context: context, delegate: _CampusSearch(_campuses, ar));
    if (selected != null) await _openCampus(selected);
  }

  Future<void> _searchCampus(bool ar) async {
    final selected = await showSearch<_CampusPlace?>(
        context: context, delegate: _PlaceSearch(_places, ar));
    if (selected != null) {
      setState(() {
        _destination = selected;
        _customDestination = null;
      });
      await _buildRoute();
    }
  }

  Future<void> _selectDestination(LatLng point, {_CampusPlace? place}) async {
    setState(() {
      _destination = place;
      _customDestination = place == null ? point : null;
    });
    final straightMeters = const Distance().distance(_avatarPoint, point);
    _measureFrom = _avatarPoint;
    _measureTo = point;
    _measuring = true;
    _measure.duration = Duration(
        milliseconds: (650 + math.log(math.max(1, straightMeters)) * 120)
            .round()
            .clamp(700, 2200)
            .toInt());
    await _measure.forward(from: 0);
    await _buildRoute();
  }

  Future<void> _buildRoute() async {
    final target = _destinationPoint;
    if (target == null || _campus == null) return;
    final origin = _avatarPoint;
    setState(() => _routing = true);
    try {
      final profile = _travelMode == 'driving' ? 'driving' : 'foot';
      final endpoint = const String.fromEnvironment('ROUTING_BASE_URL',
          defaultValue: 'https://router.project-osrm.org');
      final uri = Uri.parse(
          '$endpoint/route/v1/$profile/${origin.longitude},${origin.latitude};${target.longitude},${target.latitude}?overview=full&geometries=geojson&steps=false');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw StateError('route_unavailable');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final route = (data['routes'] as List).first as Map<String, dynamic>;
      final coords =
          ((route['geometry'] as Map<String, dynamic>)['coordinates'] as List);
      _routePoints = coords.map((p) {
        final v = p as List;
        return LatLng((v[1] as num).toDouble(), (v[0] as num).toDouble());
      }).toList();
      _routeMeters = (route['distance'] as num).toDouble();
      _routeSeconds = (route['duration'] as num).toDouble();
    } catch (_) {
      _routeMeters = const Distance().distance(origin, target);
      _routeSeconds = _routeMeters / (_travelMode == 'driving' ? 6.9 : 1.3);
      _routePoints = [origin, target];
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _toggleActivity() {
    setState(() {
      _activityActive = !_activityActive;
      if (_activityActive) {
        _activityStartedAt =
            DateTime.now().subtract(Duration(seconds: _todayWalkSeconds));
        _activityLastPoint = _position == null
            ? null
            : LatLng(_position!.latitude, _position!.longitude);
      } else {
        _activityLastPoint = null;
        _saveActivity();
      }
    });
  }

  IconData _placeIcon(String category) {
    if (category.contains('library')) return Icons.local_library_rounded;
    if (category.contains('book')) return Icons.menu_book_rounded;
    if (category.contains('cafe')) return Icons.local_cafe_rounded;
    if (category.contains('restaurant')) return Icons.restaurant_rounded;
    if (category.contains('gate')) return Icons.door_sliding_rounded;
    if (category.contains('college') || category.contains('faculty'))
      return Icons.account_balance_rounded;
    return Icons.place_rounded;
  }

  Widget _campusMap(bool ar) {
    final campus = _campus!;
    final avatar = _displayAvatarPoint;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
          initialCenter: campus.center,
          initialZoom: 16.4,
          minZoom: 2,
          maxZoom: 19,
          onTap: (_, point) => _selectDestination(point)),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zameel.app',
          tileBuilder: (context, tileWidget, tile) => ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              .82,
              .12,
              .06,
              0,
              15,
              .08,
              .92,
              .05,
              0,
              12,
              .05,
              .16,
              .79,
              0,
              18,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: tileWidget,
          ),
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
                points: _routePoints, color: AppTheme.primary, strokeWidth: 6)
          ]),
        MarkerLayer(markers: [
          for (final place in _places)
            Marker(
                point: place.point,
                width: 62,
                height: 70,
                child: GestureDetector(
                  onTap: () => _selectDestination(place.point, place: place),
                  child: Column(children: [
                    Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: _destination?.id == place.id
                                ? AppTheme.primary
                                : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 7)
                            ]),
                        child: Icon(_placeIcon(place.category),
                            color: _destination?.id == place.id
                                ? Colors.white
                                : AppTheme.primaryDark,
                            size: 23)),
                    Text(ar ? place.nameAr : place.nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            backgroundColor: Colors.white70)),
                  ]),
                )),
          Marker(
              point: avatar,
              width: 68,
              height: 86,
              child: AnimatedBuilder(
                  animation: _walk,
                  builder: (_, __) => _HumanAvatar(
                      gender: _gender,
                      phase: _walk.value,
                      heading: _position?.heading ?? 0))),
          if (_customDestination != null)
            Marker(
                point: _customDestination!,
                width: 48,
                height: 58,
                child: const Icon(Icons.location_pin,
                    color: Colors.red, size: 48)),
        ]),
        RichAttributionWidget(attributions: const [
          TextSourceAttribution('OpenStreetMap contributors')
        ]),
      ],
    );
  }

  Widget _worldMap(bool ar) => FlutterMap(
        mapController: _map,
        options: MapOptions(
            initialCenter: _position == null
                ? const LatLng(32.23, 36.00)
                : LatLng(_position!.latitude, _position!.longitude),
            initialZoom: 5,
            minZoom: 2,
            maxZoom: 19,
            onTap: (_, point) => _selectDestination(point)),
        children: [
          TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zameel.app'),
          if (_routePoints.isNotEmpty)
            PolylineLayer(polylines: [
              Polyline(
                  points: _routePoints, color: AppTheme.primary, strokeWidth: 5)
            ]),
          MarkerLayer(markers: [
            for (final campus in _campuses)
              Marker(
                  point: campus.center,
                  width: 150,
                  height: 78,
                  child: GestureDetector(
                      onTap: () => _openCampus(campus),
                      child: Card(
                          color: identical(campus, _registeredCampus)
                              ? const Color(0xFFFFF2B7)
                              : Colors.white,
                          child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_rounded,
                                        color: AppTheme.primaryDark),
                                    Text(ar ? campus.ar : campus.en,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900))
                                  ]))))),
            if (_campus != null)
              Marker(
                  point: _displayAvatarPoint,
                  width: 68,
                  height: 86,
                  child: AnimatedBuilder(
                      animation: _walk,
                      builder: (_, __) => _HumanAvatar(
                          gender: _gender,
                          phase: _walk.value,
                          heading: _position?.heading ?? 0))),
            if (_customDestination != null)
              Marker(
                  point: _customDestination!,
                  width: 48,
                  height: 58,
                  child: const Icon(Icons.location_pin,
                      color: Colors.red, size: 48))
          ]),
          RichAttributionWidget(attributions: const [
            TextSourceAttribution('OpenStreetMap contributors')
          ]),
        ],
      );

  Widget _worldMeasurementCard(bool ar) => Card(
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.straighten_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        _measuring
                            ? (ar
                                ? 'الشخصية تقيس المسافة…'
                                : 'Avatar is measuring…')
                            : (ar ? 'تم قياس المسافة' : 'Distance measured'),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: () => setState(() {
                          _destination = null;
                          _customDestination = null;
                          _routePoints = const [];
                        }),
                    icon: const Icon(Icons.close_rounded))
              ]),
              Text(
                  _routing
                      ? (ar ? 'جارٍ حساب أفضل مسار…' : 'Calculating route…')
                      : _routeMeters < 1000
                          ? '${_routeMeters.round()} ${ar ? 'متر' : 'm'} • ${math.max(1, (_routeSeconds / 60).ceil())} ${ar ? 'دقيقة' : 'min'}'
                          : '${(_routeMeters / 1000).toStringAsFixed(1)} ${ar ? 'كم' : 'km'} • ${math.max(1, (_routeSeconds / 60).ceil())} ${ar ? 'دقيقة' : 'min'}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
      );

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _world
            ? Stack(children: [
                Positioned.fill(child: _worldMap(ar)),
                if (_destinationPoint != null)
                  Positioned(
                      left: 14,
                      right: 14,
                      bottom: 24,
                      child: _worldMeasurementCard(ar))
              ])
            : _campus == null
                ? const Center(child: Text('لا توجد جامعة متاحة'))
                : Stack(children: [
                    Positioned.fill(child: _campusMap(ar)),
                    Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: SafeArea(
                            child: Row(children: [
                          Expanded(
                              child: Material(
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(24),
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () => _searchCampus(ar),
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Row(children: [
                                            const Icon(Icons.search_rounded),
                                            const SizedBox(width: 9),
                                            Expanded(
                                                child: Text(ar
                                                    ? 'ابحث عن مبنى أو خدمة أو مكان'
                                                    : 'Search buildings, services or places'))
                                          ]))))),
                          const SizedBox(width: 8),
                          IconButton.filled(
                              tooltip: ar ? 'نشاطي' : 'My activity',
                              onPressed: () => _showActivity(ar),
                              icon: const Icon(Icons.directions_walk_rounded)),
                        ]))),
                    if (widget.embedded && _canManage)
                      Positioned(
                          top: 92,
                          left: 12,
                          child: SafeArea(
                              child: FloatingActionButton.small(
                            heroTag: 'campus-place-admin',
                            tooltip: ar
                                ? 'إدارة أماكن الحرم'
                                : 'Manage campus places',
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => CampusPlaceAdminScreen(
                                          initialUniversity: _campus!.ar,
                                          initialCenter: _campus!.center)));
                              await _openCampus(_campus!);
                            },
                            child: const Icon(Icons.edit_location_alt_rounded),
                          ))),
                    if (_places.isEmpty)
                      Positioned(
                          left: 20,
                          right: 20,
                          bottom: 28,
                          child: Material(
                              elevation: 5,
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                      ar
                                          ? 'لا توجد أماكن معتمدة لهذا الحرم بعد. تظهر المباني والطرق الحقيقية على الخريطة، وستضاف نقاط زميل بعد توثيقها.'
                                          : 'No verified Zameel places yet. Real map buildings remain visible.',
                                      textAlign: TextAlign.center)))),
                    if (_destinationPoint != null)
                      Positioned(
                          left: 14,
                          right: 14,
                          bottom: 24,
                          child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(children: [
                                          Icon(
                                              _destination == null
                                                  ? Icons.location_pin
                                                  : _placeIcon(
                                                      _destination!.category),
                                              color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  _destination == null
                                                      ? (ar
                                                          ? 'نقطة محددة على الخريطة'
                                                          : 'Selected map point')
                                                      : (ar
                                                          ? _destination!.nameAr
                                                          : _destination!
                                                              .nameEn),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800))),
                                          IconButton(
                                              onPressed: () => setState(() {
                                                    _destination = null;
                                                    _customDestination = null;
                                                    _routePoints = const [];
                                                  }),
                                              icon: const Icon(
                                                  Icons.close_rounded))
                                        ]),
                                        SegmentedButton<String>(
                                            segments: [
                                              ButtonSegment(
                                                  value: 'walking',
                                                  icon: const Icon(
                                                      Icons.directions_walk),
                                                  label: Text(
                                                      ar ? 'مشي' : 'Walk')),
                                              ButtonSegment(
                                                  value: 'driving',
                                                  icon: const Icon(
                                                      Icons.directions_car),
                                                  label: Text(
                                                      ar ? 'سيارة' : 'Car'))
                                            ],
                                            selected: {
                                              _travelMode
                                            },
                                            onSelectionChanged: (v) {
                                              setState(
                                                  () => _travelMode = v.first);
                                              _buildRoute();
                                            }),
                                        const SizedBox(height: 7),
                                        Text(
                                            _routing
                                                ? (ar
                                                    ? 'جارٍ حساب أفضل مسار…'
                                                    : 'Calculating best route…')
                                                : '${_routeMeters.round()} ${ar ? 'متر' : 'm'} • ${math.max(1, (_routeSeconds / 60).ceil())} ${ar ? 'دقيقة' : 'min'}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ])))),
                  ]);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        leading: !_world
            ? IconButton(
                onPressed: () => setState(() => _world = true),
                icon: const Icon(Icons.public_rounded))
            : null,
        title: Text(_world
            ? (ar ? 'عالم جامعات زميل' : 'Zameel University World')
            : (ar ? _campus?.ar ?? 'الحرم الجامعي' : _campus?.en ?? 'Campus')),
        actions: [
          IconButton(
              onPressed: () =>
                  _world ? _searchUniversity(ar) : _searchCampus(ar),
              icon: const Icon(Icons.search_rounded)),
          if (!_world && _canManage)
            IconButton(
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CampusPlaceAdminScreen(
                              initialUniversity: _campus!.ar,
                              initialCenter: _campus!.center)));
                  await _openCampus(_campus!);
                },
                icon: const Icon(Icons.edit_location_alt_rounded),
                tooltip: ar ? 'إدارة الأماكن' : 'Manage places'),
        ],
      ),
      body: body,
    );
  }

  Future<void> _showActivity(bool ar) async {
    await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) {
          final km = _todayWalkMeters / 1000;
          final steps = (_todayWalkMeters / .75).round();
          final calories = (km * 50).round();
          final goal = 3000.0;
          return StatefulBuilder(
              builder: (context, refresh) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            ar
                                ? 'نشاطي — برنامج المشي الجامعي'
                                : 'My Activity — Campus Walking',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                            value: math.min(1, _todayWalkMeters / goal),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(8)),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _metric('$steps', ar ? 'خطوة' : 'steps'),
                              _metric('${km.toStringAsFixed(2)} كم',
                                  ar ? 'المسافة' : 'distance'),
                              _metric('${(_todayWalkSeconds / 60).round()} د',
                                  ar ? 'المدة' : 'duration'),
                              _metric('$calories', ar ? 'سعرة' : 'kcal')
                            ]),
                        const SizedBox(height: 14),
                        Text(
                            ar
                                ? 'هدف اليوم: 3 كم • لا تُرفع بيانات نشاطك إلى الخادم.'
                                : 'Today: 3 km • Activity stays on this device.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: () {
                              _toggleActivity();
                              refresh(() {});
                            },
                            icon: Icon(_activityActive
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(_activityActive
                                ? (ar ? 'إيقاف مؤقت' : 'Pause')
                                : (ar ? 'ابدأ المشي' : 'Start walking'))),
                      ])));
        });
  }

  Widget _metric(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11))
      ]);

  @override
  void dispose() {
    _positionStream?.cancel();
    _walk.dispose();
    _measure.dispose();
    super.dispose();
  }
}

class _HumanAvatar extends StatelessWidget {
  final String gender;
  final double phase;
  final double heading;
  const _HumanAvatar(
      {required this.gender, required this.phase, required this.heading});
  @override
  Widget build(BuildContext context) {
    final female = gender == 'female';
    final swing = math.sin(phase * math.pi * 2) * .22;
    return Transform.rotate(
        angle: heading * math.pi / 180,
        child: CustomPaint(
            size: const Size(58, 78), painter: _HumanPainter(female, swing)));
  }
}

class _HumanPainter extends CustomPainter {
  final bool female;
  final double swing;
  const _HumanPainter(this.female, this.swing);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, 69), width: 40, height: 12),
        Paint()..color = Colors.black26);
    final skin = Paint()..color = const Color(0xFFF2C7A5);
    final clothes = Paint()
      ..color = female ? const Color(0xFF8B5CC7) : AppTheme.primary;
    final dark = Paint()
      ..color = const Color(0xFF243B43)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(26, 49), Offset(22 + swing * 18, 67), dark);
    canvas.drawLine(const Offset(33, 49), Offset(37 - swing * 18, 67), dark);
    canvas.drawLine(
        const Offset(22, 31),
        Offset(13 - swing * 17, 48),
        Paint()
          ..color = clothes.color
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        const Offset(37, 31),
        Offset(46 + swing * 17, 48),
        Paint()
          ..color = clothes.color
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(19, 23, 21, 31), const Radius.circular(9)),
        clothes);
    canvas.drawCircle(const Offset(29.5, 15), 12, skin);
    canvas.drawArc(
        const Rect.fromLTWH(17, 3, 25, 20),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = female ? const Color(0xFF4B2E63) : const Color(0xFF29363A)
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(
        const Offset(25, 15), 1.5, Paint()..color = Colors.black87);
    canvas.drawCircle(
        const Offset(34, 15), 1.5, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _HumanPainter old) =>
      old.swing != swing || old.female != female;
}

class _CampusSearch extends SearchDelegate<_CampusData?> {
  final List<_CampusData> campuses;
  final bool ar;
  _CampusSearch(this.campuses, this.ar);
  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back));
  @override
  Widget buildResults(BuildContext context) => _list(context);
  @override
  Widget buildSuggestions(BuildContext context) => _list(context);
  Widget _list(BuildContext context) {
    final q = query.toLowerCase();
    final rows = campuses
        .where((c) =>
            q.isEmpty ||
            c.ar.toLowerCase().contains(q) ||
            c.en.toLowerCase().contains(q))
        .toList();
    return ListView(children: [
      for (final c in rows)
        ListTile(
            leading: const Icon(Icons.account_balance_rounded),
            title: Text(ar ? c.ar : c.en),
            onTap: () => close(context, c))
    ]);
  }
}

class _PlaceSearch extends SearchDelegate<_CampusPlace?> {
  final List<_CampusPlace> places;
  final bool ar;
  _PlaceSearch(this.places, this.ar);
  @override
  String? get searchFieldLabel =>
      ar ? 'مبنى، خدمة، مقهى…' : 'Building, service, cafe…';
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
            onPressed: () => query = '', icon: const Icon(Icons.clear_rounded))
      ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded));
  @override
  Widget buildResults(BuildContext context) => _results(context);
  @override
  Widget buildSuggestions(BuildContext context) => _results(context);
  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rows = places
        .where((p) =>
            q.isEmpty ||
            p.nameAr.toLowerCase().contains(q) ||
            p.nameEn.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
    if (rows.isEmpty)
      return Center(
          child: Text(ar
              ? 'لا توجد نتيجة ضمن الأماكن المعتمدة'
              : 'No verified place found'));
    return ListView(children: [
      for (final p in rows)
        ListTile(
            leading: const Icon(Icons.place_rounded),
            title: Text(ar ? p.nameAr : p.nameEn),
            subtitle: Text(p.category),
            onTap: () => close(context, p))
    ]);
  }
}
