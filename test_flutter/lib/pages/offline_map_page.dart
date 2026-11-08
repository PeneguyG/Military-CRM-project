import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../crm_store.dart';
import '../models/crm_models.dart';
import '../utils/offline_map_helper.dart';
import '../utils/offline_map_boundaries.dart';
import 'crm_widgets.dart';
import 'responsive_dialog.dart';

class MapRecord {
  const MapRecord.organization(Organization value)
    : organization = value,
      contact = null;
  const MapRecord.contact(Contact value) : contact = value, organization = null;
  final Organization? organization;
  final Contact? contact;
  String get key => organization != null
      ? 'org:${organization!.id}'
      : 'contact:${contact!.id}';
  String get name => organization?.name ?? contact!.fullName;
  String get detail =>
      organization?.industry ??
      [
        contact!.militaryRank,
        contact!.title,
      ].where((s) => s.isNotEmpty).join(' · ');
  String get address => organization?.address ?? contact!.address;
  String get phone => organization?.phone ?? contact!.phone;
  String get source =>
      organization?.coordinateSource ?? contact!.coordinateSource;
  bool get archived => organization?.isArchived ?? contact!.isArchived;
  LatLng? get point {
    final lat = organization?.latitude ?? contact?.latitude,
        lng = organization?.longitude ?? contact?.longitude;
    return OfflineMapHelper.validCoordinates(lat, lng)
        ? LatLng(lat!, lng!)
        : null;
  }

  Color get color => archived
      ? Colors.grey
      : organization != null
      ? Colors.blue
      : contact!.lifeStatus == 'deceased'
      ? Colors.grey
      : contact!.status == ContactStatus.inactive
      ? Colors.orange
      : Colors.green;
  IconData get icon => organization != null ? Icons.business : Icons.person;
}

class OfflineMapPage extends StatefulWidget {
  const OfflineMapPage({
    super.key,
    required this.store,
    required this.onOpenOrganization,
    required this.onOpenContact,
    this.focusRecordKey,
    this.focusRevision = 0,
  });
  final CrmStore store;
  final ValueChanged<Organization> onOpenOrganization;
  final ValueChanged<Contact> onOpenContact;
  final String? focusRecordKey;
  final int focusRevision;
  @override
  State<OfflineMapPage> createState() => _OfflineMapPageState();
}

class _OfflineMapPageState extends State<OfflineMapPage> {
  final _map = MapController();
  bool _ready = false,
      _organizations = true,
      _contacts = true,
      _lines = true,
      _archived = false,
      _placingMe = false,
      _busy = false;
  String? _assignKey, _selectedKey, _referenceKey;
  List<MapRecord> get _all => [
    for (final o in widget.store.organizations) MapRecord.organization(o),
    for (final c in widget.store.contacts) MapRecord.contact(c),
  ];
  List<MapRecord> get _visible => _all
      .where(
        (r) =>
            (_archived || !r.archived) &&
            (r.organization != null ? _organizations : _contacts),
      )
      .toList();
  MapRecord? _record(String? key) =>
      _all.where((r) => r.key == key).firstOrNull;
  LatLng get _me => LatLng(
    widget.store.userLocation.latitude,
    widget.store.userLocation.longitude,
  );
  LatLng get _reference => _record(_referenceKey)?.point ?? _me;
  String get _referenceName => _record(_referenceKey)?.name ?? 'Me';
  @override
  void didUpdateWidget(OfflineMapPage old) {
    super.didUpdateWidget(old);
    if (old.focusRevision != widget.focusRevision ||
        old.focusRecordKey != widget.focusRecordKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusRequested();
      });
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _focusRequested() {
    final record = _record(widget.focusRecordKey);
    if (record == null) return;
    setState(() {
      _selectedKey = record.key;
      _organizations = true;
      _contacts = true;
      if (record.archived) _archived = true;
    });
    if (record.point != null && _ready)
      _map.move(record.point!, 11);
    else if (record.point == null)
      _message(
        'This record has no map position. Use Assign pin or edit its coordinates.',
      );
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _select(MapRecord record, {bool center = false}) {
    setState(() => _selectedKey = record.key);
    if (center && record.point != null && _ready) _map.move(record.point!, 10);
  }

  void _setArchivedVisible(bool visible) {
    setState(() => _archived = visible);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRecords();
    });
  }

  Future<void> _enterLocation() async {
    final result = await showDialog<UserLocation>(
      context: context,
      builder: (_) => _LocationDialog(current: widget.store.userLocation),
    );
    if (result == null) return;
    try {
      await widget.store.saveUserLocation(result);
      if (mounted && _ready) _map.move(_me, 10);
    } catch (error) {
      _message('Location was not saved: $error');
    }
  }

  Future<void> _assignPin() async {
    final records = _all.where((r) => !r.archived || _archived).toList()
      ..sort((a, b) {
        if ((a.point == null) != (b.point == null))
          return a.point == null ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: responsiveDialogConstraints(context),
        insetPadding: responsiveDialogInsetPadding(context),
        title: const Text('Choose a record to place'),
        content: SizedBox(
          width: responsiveDialogContentWidth(context),
          height: responsiveDialogContentHeight(context),
          child: ListView(
            children: [
              for (final r in records)
                ListTile(
                  leading: Icon(r.icon),
                  title: Text(r.name),
                  subtitle: Text(
                    r.point == null ? 'Unmapped' : 'Move existing pin',
                  ),
                  onTap: () => Navigator.pop(context, r.key),
                ),
              if (records.isEmpty)
                const Text('Add a contact or organization first.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (key != null && mounted)
      setState(() {
        _assignKey = key;
        _placingMe = false;
      });
  }

  Future<void> _tap(LatLng point) async {
    if (!_placingMe && _assignKey == null) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_placingMe) {
        await widget.store.saveUserLocation(
          UserLocation(
            latitude: point.latitude,
            longitude: point.longitude,
            label: 'My base',
          ),
        );
      } else {
        final r = _record(_assignKey);
        if (r == null) throw StateError('Record no longer exists');
        if (r.organization != null)
          await widget.store.saveOrganization(
            r.organization!.copyWith(
              latitude: point.latitude,
              longitude: point.longitude,
              coordinateSource: 'Manually placed',
            ),
          );
        else
          await widget.store.saveContact(
            r.contact!.copyWith(
              latitude: point.latitude,
              longitude: point.longitude,
              coordinateSource: 'Manually placed',
            ),
          );
      }
      if (mounted)
        setState(() {
          _selectedKey = _assignKey ?? _selectedKey;
          _assignKey = null;
          _placingMe = false;
        });
    } catch (error) {
      _message('Pin was not saved: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fitRecords() {
    final points = [_me, ..._visible.map((r) => r.point).whereType<LatLng>()];
    if (_ready)
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(65),
          maxZoom: 12,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final records = _visible;
      final selected = records.where((r) => r.key == _selectedKey).firstOrNull;
      final mapped = records.where((r) => r.point != null).toList();
      final nearest = selected?.point == null
          ? <MapRecord>[]
          : (mapped.where((r) => r.key != selected!.key).toList()..sort(
              (a, b) =>
                  OfflineMapHelper.distanceMiles(
                    selected!.point!,
                    a.point!,
                  ).compareTo(
                    OfflineMapHelper.distanceMiles(selected.point!, b.point!),
                  ),
            ));
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.offline_pin_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline map',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text(
                  '${mapped.length} mapped · ${records.length - mapped.length} unmapped',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Organizations'),
                    selected: _organizations,
                    onSelected: (v) => setState(() => _organizations = v),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Contacts'),
                    selected: _contacts,
                    onSelected: (v) => setState(() => _contacts = v),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Distance lines'),
                    selected: _lines,
                    onSelected: (v) => setState(() => _lines = v),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Include archived'),
                    selected: _archived,
                    onSelected: _setArchivedVisible,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _enterLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Set my location'),
                  ),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _placingMe = true;
                            _assignKey = null;
                          }),
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Place Me on map'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _assignPin,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Assign pin'),
                  ),
                  TextButton.icon(
                    onPressed: _fitRecords,
                    icon: const Icon(Icons.fit_screen),
                    label: const Text('Fit all'),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_placingMe || _assignKey != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _placingMe
                          ? 'Click the map to place Me.'
                          : 'Click the map to place ${_record(_assignKey)?.name ?? 'the record'}.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _placingMe = false;
                      _assignKey = null;
                    }),
                    child: const Text('Cancel placement'),
                  ),
                ],
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final panel = _inspector(selected, nearest, records);
                  final map = _mapView(mapped, selected, nearest);
                  return constraints.maxWidth >= 850
                      ? Row(
                          children: [
                            Expanded(child: map),
                            const SizedBox(width: 12),
                            SizedBox(width: 310, child: panel),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: map),
                            SizedBox(
                              height: constraints.maxHeight > 480 ? 230 : 160,
                              child: panel,
                            ),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _mapView(
    List<MapRecord> records,
    MapRecord? selected,
    List<MapRecord> nearest,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final links = <(LatLng, LatLng, Color)>[];
    if (_lines && selected?.point != null) {
      links.add((_reference, selected!.point!, colors.primary));
      for (final other in nearest.take(3)) {
        links.add((selected.point!, other.point!, colors.tertiary));
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _me,
              initialZoom: 6,
              minZoom: 2,
              maxZoom: 19,
              backgroundColor: dark
                  ? const Color(0xFF101F27)
                  : const Color(0xFFE4EFF1),
              onMapReady: () {
                _ready = true;
                if (widget.focusRecordKey != null)
                  _focusRequested();
                else
                  _fitRecords();
              },
              onTap: (_, point) => _tap(point),
            ),
            children: [
              PolygonLayer(
                polygons: [
                  for (final polygon in worldOutlines)
                    Polygon(
                      points: polygon,
                      color: dark
                          ? const Color(0xFF203B3F)
                          : const Color(0xFFD1DECD),
                      borderColor: dark
                          ? Colors.teal.shade700
                          : Colors.teal.shade300,
                      borderStrokeWidth: 0.7,
                    ),
                ],
              ),
              PolylineLayer(
                polylines: [
                  for (final line in stateOutlines)
                    Polyline(
                      points: line,
                      color: dark ? Colors.teal.shade600 : Colors.teal.shade400,
                      strokeWidth: 0.8,
                    ),
                ],
              ),
              const _CoordinateGrid(),
              PolylineLayer(
                polylines: [
                  for (final link in links)
                    Polyline(
                      points: [link.$1, link.$2],
                      color: link.$3,
                      strokeWidth: 2,
                      pattern: StrokePattern.dashed(segments: [8, 6]),
                    ),
                ],
              ),
              IgnorePointer(
                ignoring: _placingMe || _assignKey != null,
                child: MarkerLayer(
                  markers: [
                    Marker(
                      point: _me,
                      width: 190,
                      height: 66,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _referenceKey = null);
                          _message(widget.store.userLocation.label);
                        },
                        child: Column(
                          children: [
                            Icon(Icons.stars, size: 34, color: colors.primary),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              color: colors.surface,
                              child: const Text(
                                'ME (Base)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (var i = 0; i < records.length; i++)
                      _marker(records[i], records, selected),
                    for (final link in links)
                      Marker(
                        point: OfflineMapHelper.midpoint(link.$1, link.$2),
                        width: 90,
                        height: 24,
                        child: IgnorePointer(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: link.$3),
                            ),
                            child: Text(
                              '${OfflineMapHelper.distanceMiles(link.$1, link.$2).toStringAsFixed(1)} mi',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(6),
                color: colors.surface.withValues(alpha: 0.92),
                child: Text(
                  'Natural Earth · offline boundaries\nStraight-line distances; approximate pins are not street-level locations.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_zoom_in',
                  onPressed: () => _map.move(
                    _map.camera.center,
                    (_map.camera.zoom + 1).clamp(2, 19),
                  ),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'map_zoom_out',
                  onPressed: () => _map.move(
                    _map.camera.center,
                    (_map.camera.zoom - 1).clamp(2, 19),
                  ),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(
    MapRecord record,
    List<MapRecord> records,
    MapRecord? selected,
  ) {
    final colocated = records
        .where(
          (r) =>
              OfflineMapHelper.distanceMiles(r.point!, record.point!) < 0.001,
        )
        .toList();
    final index = colocated.indexOf(record);
    final offset = colocated.length > 1
        ? Offset(
            (index - (colocated.length - 1) / 2) * 38,
            index.isEven ? -10 : 15,
          )
        : Offset.zero;
    return Marker(
      key: ValueKey(record.key),
      point: record.point!,
      width: 170,
      height: 72,
      child: Transform.translate(
        offset: offset,
        child: Tooltip(
          message: '${record.name}\n${record.detail}\n${record.source}',
          child: GestureDetector(
            onTap: () => _select(record),
            child: Column(
              children: [
                Icon(
                  record.icon,
                  color: record.color,
                  size: selected?.key == record.key ? 36 : 28,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: record.color),
                  ),
                  child: Text(
                    '${record.archived ? 'Archived · ' : ''}${record.contact == null ? record.name : '${record.contact!.militaryRank} ${record.name}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inspector(
    MapRecord? selected,
    List<MapRecord> nearest,
    List<MapRecord> records,
  ) => Card(
    margin: EdgeInsets.zero,
    child: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (selected == null) ...[
          Text('Map records', style: Theme.of(context).textTheme.titleMedium),
          Text(widget.store.userLocation.label),
          if (widget.store.userLocation.label.startsWith('Demo base'))
            const Text(
              'Me is a demo reference. Set your location to use your own base.',
            ),
          const SizedBox(height: 8),
          for (final record in records)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(record.icon, color: record.color),
              title: Text(record.name),
              subtitle: Text(
                [
                  if (record.archived) 'Archived',
                  record.point == null
                      ? 'Unmapped — assign a pin'
                      : OfflineMapHelper.formatRelativePosition(
                          _reference,
                          record.point!,
                          _referenceName,
                        ),
                ].join(' · '),
              ),
              onTap: () => _select(record, center: true),
            ),
          if (records.isEmpty) const Text('No records match these filters.'),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  selected.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Close selection',
                onPressed: () => setState(() => _selectedKey = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(selected.detail),
          if (selected.archived) const Text('Archived record'),
          Text(selected.address),
          const SizedBox(height: 8),
          if (selected.point != null) ...[
            SelectableText(
              '${selected.point!.latitude.toStringAsFixed(5)}, ${selected.point!.longitude.toStringAsFixed(5)}',
            ),
            Text(
              selected.source.isEmpty ? 'Saved coordinates' : selected.source,
            ),
            Text(
              OfflineMapHelper.formatRelativePosition(
                _me,
                selected.point!,
                'Me',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_referenceKey != null)
              Text(
                OfflineMapHelper.formatRelativePosition(
                  _reference,
                  selected.point!,
                  _referenceName,
                ),
              ),
          ] else
            const Text(
              'No coordinates yet. Use Assign pin to place this record.',
            ),
          Wrap(
            spacing: 6,
            children: [
              TextButton(
                onPressed: () {
                  if (selected.organization != null)
                    widget.onOpenOrganization(selected.organization!);
                  else
                    widget.onOpenContact(selected.contact!);
                },
                child: const Text('Open record'),
              ),
              if (selected.phone.isNotEmpty)
                TextButton(
                  onPressed: () => phoneAction(context, selected.phone),
                  child: const Text('Call / Text'),
                ),
              if (selected.point != null)
                TextButton(
                  onPressed: () => setState(() => _referenceKey = selected.key),
                  child: const Text('Set as reference point'),
                ),
              if (_referenceKey != null)
                TextButton(
                  onPressed: () => setState(() => _referenceKey = null),
                  child: const Text('Reference: Me'),
                ),
            ],
          ),
          const Divider(),
          Text(
            'Nearest records',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (nearest.isEmpty)
            const Text('No other mapped records match your filters.'),
          for (final other in nearest)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(other.icon, color: other.color),
              title: Text(other.name),
              subtitle: Text(
                OfflineMapHelper.formatRelativePosition(
                  selected.point!,
                  other.point!,
                  'selected pin',
                ),
              ),
              onTap: () => _select(other, center: true),
            ),
        ],
      ],
    ),
  );
}

class _CoordinateGrid extends StatelessWidget {
  const _CoordinateGrid();
  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(
          camera,
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.camera, this.color);
  final MapCamera camera;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final step = camera.zoom < 4
        ? 10.0
        : camera.zoom < 7
        ? 2.0
        : camera.zoom < 10
        ? 0.5
        : camera.zoom < 13
        ? 0.1
        : 0.01;
    final bounds = camera.visibleBounds;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    void label(String text, Offset offset) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, offset);
    }

    for (
      double lat = (bounds.south / step).floor() * step;
      lat <= bounds.north && lat <= 85;
      lat += step
    ) {
      if (lat < -85) continue;
      final a = camera.latLngToScreenPoint(LatLng(lat, bounds.west));
      final b = camera.latLngToScreenPoint(LatLng(lat, bounds.east));
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
      label('${lat.toStringAsFixed(step < 1 ? 2 : 0)}°', Offset(3, a.y));
    }
    final west = bounds.west, east = bounds.east;
    if (east - west > 360 || east < west) return;
    for (double lng = (west / step).floor() * step; lng <= east; lng += step) {
      final a = camera.latLngToScreenPoint(
        LatLng(bounds.south.clamp(-85, 85), lng),
      );
      final b = camera.latLngToScreenPoint(
        LatLng(bounds.north.clamp(-85, 85), lng),
      );
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
      label('${lng.toStringAsFixed(step < 1 ? 2 : 0)}°', Offset(b.x, 3));
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.camera != camera || old.color != color;
}

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({required this.current});
  final UserLocation current;
  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final _address = TextEditingController();
  late final _label = TextEditingController(
    text: widget.current.label.startsWith('Demo base')
        ? 'My base'
        : widget.current.label,
  );
  String? _error;
  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    constraints: responsiveDialogConstraints(context),
    insetPadding: responsiveDialogInsetPadding(context),
    title: const Text('Set my location'),
    scrollable: true,
    content: SizedBox(
      width: responsiveDialogContentWidth(context, maxWidth: 900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Location label'),
          ),
          TextField(
            controller: _address,
            decoration: InputDecoration(
              labelText: 'Coordinates, city, base, or address',
              hintText: '36.163, -86.782',
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          const Text(
            'City, base, ZIP and state matches are approximate. Enter coordinates or click the map for a precise pin.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final match = OfflineMapHelper.resolve(_address.text);
          if (match == null) {
            setState(
              () => _error =
                  'No offline match. Enter latitude, longitude or place Me on the map.',
            );
            return;
          }
          Navigator.pop(
            context,
            UserLocation(
              latitude: match.point.latitude,
              longitude: match.point.longitude,
              label:
                  '${_label.text.trim().isEmpty ? 'My base' : _label.text.trim()}${match.precision == 'coordinates' ? '' : ' · ${match.precision}'}',
            ),
          );
        },
        child: const Text('Save location'),
      ),
    ],
  );
}
