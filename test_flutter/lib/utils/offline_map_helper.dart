import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class OfflineLocationMatch {
  const OfflineLocationMatch(this.point, this.label, this.precision);
  final LatLng point;
  final String label;
  final String precision;
}

/// Approximate gazetteer centroids, not street-level geocoding. No network I/O.
class OfflineMapHelper {
  static bool validCoordinates(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static const places = <String, LatLng>{
    'fort campbell': LatLng(36.663, -87.477),
    'arnold afb': LatLng(35.393, -86.086),
    'arnold air force base': LatLng(35.393, -86.086),
    'redstone arsenal': LatLng(34.684, -86.655),
    'pentagon': LatLng(38.872, -77.056),
    'fort bragg': LatLng(35.139, -79.006),
    'fort liberty': LatLng(35.139, -79.006),
    'fort knox': LatLng(37.900, -85.960),
    'fort benning': LatLng(32.360, -84.950),
    'fort moore': LatLng(32.360, -84.950),
    'fort hood': LatLng(31.134, -97.778),
    'fort cavazos': LatLng(31.134, -97.778),
    'camp pendleton': LatLng(33.303, -117.351),
    'camp lejeune': LatLng(34.626, -77.386),
    'joint base lewis mcchord': LatLng(47.104, -122.579),
    'norfolk naval station': LatLng(36.946, -76.303),
    'nashville': LatLng(36.163, -86.782),
    'smyrna': LatLng(35.982, -86.519),
    'murfreesboro': LatLng(35.846, -86.390),
    'knoxville': LatLng(35.961, -83.921),
    'maryville': LatLng(35.756, -83.970),
    'cookeville': LatLng(36.163, -85.501),
    'clarksville': LatLng(36.529, -87.359),
    'huntsville': LatLng(34.731, -86.586),
    'norfolk': LatLng(36.851, -76.286),
    'chattanooga': LatLng(35.045, -85.310),
    'memphis': LatLng(35.150, -90.049),
    'tullahoma': LatLng(35.362, -86.209),
    'washington': LatLng(38.907, -77.037),
    'new york': LatLng(40.713, -74.006),
    'los angeles': LatLng(34.052, -118.244),
    'chicago': LatLng(41.878, -87.630),
    'houston': LatLng(29.760, -95.370),
    'dallas': LatLng(32.777, -96.797),
    'san antonio': LatLng(29.424, -98.494),
    'san diego': LatLng(32.716, -117.161),
    'phoenix': LatLng(33.448, -112.074),
    'philadelphia': LatLng(39.953, -75.165),
    'boston': LatLng(42.360, -71.059),
    'seattle': LatLng(47.606, -122.332),
    'denver': LatLng(39.739, -104.990),
    'atlanta': LatLng(33.749, -84.388),
    'miami': LatLng(25.762, -80.192),
    'jacksonville': LatLng(30.332, -81.656),
    'colorado springs': LatLng(38.834, -104.821),
    'honolulu': LatLng(21.307, -157.858),
    'anchorage': LatLng(61.218, -149.900),
  };
  static const zipPrefixes = <String, String>{
    '370': 'nashville',
    '371': 'murfreesboro',
    '372': 'nashville',
    '373': 'chattanooga',
    '374': 'chattanooga',
    '375': 'memphis',
    '377': 'knoxville',
    '378': 'knoxville',
    '379': 'knoxville',
    '385': 'cookeville',
    '358': 'huntsville',
    '422': 'fort campbell',
    '235': 'norfolk',
    '236': 'norfolk',
    '200': 'washington',
    '203': 'pentagon',
  };
  static const states = <String, (String, double, double)>{
    'AL': ('Alabama', 32.8, -86.8),
    'AK': ('Alaska', 64.0, -153.0),
    'AZ': ('Arizona', 34.3, -111.7),
    'AR': ('Arkansas', 34.8, -92.2),
    'CA': ('California', 37.2, -119.7),
    'CO': ('Colorado', 39.0, -105.5),
    'CT': ('Connecticut', 41.6, -72.7),
    'DE': ('Delaware', 39.0, -75.5),
    'FL': ('Florida', 28.6, -82.4),
    'GA': ('Georgia', 32.7, -83.4),
    'HI': ('Hawaii', 20.5, -157.0),
    'ID': ('Idaho', 44.4, -114.6),
    'IL': ('Illinois', 40.0, -89.2),
    'IN': ('Indiana', 40.0, -86.2),
    'IA': ('Iowa', 42.1, -93.5),
    'KS': ('Kansas', 38.5, -98.4),
    'KY': ('Kentucky', 37.5, -85.3),
    'LA': ('Louisiana', 31.0, -92.0),
    'ME': ('Maine', 45.3, -69.0),
    'MD': ('Maryland', 39.0, -76.7),
    'MA': ('Massachusetts', 42.3, -71.8),
    'MI': ('Michigan', 44.2, -85.4),
    'MN': ('Minnesota', 46.0, -94.6),
    'MS': ('Mississippi', 32.7, -89.7),
    'MO': ('Missouri', 38.5, -92.5),
    'MT': ('Montana', 47.0, -109.6),
    'NE': ('Nebraska', 41.5, -99.8),
    'NV': ('Nevada', 39.3, -116.6),
    'NH': ('New Hampshire', 43.7, -71.6),
    'NJ': ('New Jersey', 40.1, -74.7),
    'NM': ('New Mexico', 34.5, -106.0),
    'NY': ('New York', 43.0, -75.5),
    'NC': ('North Carolina', 35.5, -79.8),
    'ND': ('North Dakota', 47.5, -100.5),
    'OH': ('Ohio', 40.4, -82.8),
    'OK': ('Oklahoma', 35.6, -97.5),
    'OR': ('Oregon', 44.0, -120.6),
    'PA': ('Pennsylvania', 40.9, -77.8),
    'RI': ('Rhode Island', 41.7, -71.5),
    'SC': ('South Carolina', 33.8, -80.9),
    'SD': ('South Dakota', 44.5, -100.2),
    'TN': ('Tennessee', 35.8, -86.4),
    'TX': ('Texas', 31.0, -99.0),
    'UT': ('Utah', 39.3, -111.7),
    'VT': ('Vermont', 44.0, -72.7),
    'VA': ('Virginia', 37.5, -79.0),
    'WA': ('Washington', 47.4, -120.5),
    'WV': ('West Virginia', 38.6, -80.6),
    'WI': ('Wisconsin', 44.6, -89.7),
    'WY': ('Wyoming', 43.0, -107.5),
    'DC': ('District of Columbia', 38.9, -77.0),
  };

  static OfflineLocationMatch? resolve(String address) {
    final raw = address.trim();
    final pair = RegExp(
      r'^\s*([+-]?\d+(?:\.\d+)?)\s*,\s*([+-]?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(raw);
    if (pair != null) {
      final lat = double.parse(pair[1]!);
      final lng = double.parse(pair[2]!);
      return validCoordinates(lat, lng)
          ? OfflineLocationMatch(
              LatLng(lat, lng),
              'Entered coordinates',
              'coordinates',
            )
          : null;
    }
    final text = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (text.isEmpty) return null;
    final keys = places.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in keys) {
      if ((' $text ').contains(' $name ')) {
        // Ambiguous Washington alone means the state; Washington DC means the city.
        if (name == 'washington' &&
            !text.contains('dc') &&
            !text.contains('d c'))
          continue;
        return OfflineLocationMatch(
          places[name]!,
          name,
          'Approximate city/base center',
        );
      }
    }
    final zip = RegExp(r'\b(\d{5})(?:-\d{4})?\b').firstMatch(raw);
    final zipPlace = zip == null ? null : zipPrefixes[zip[1]!.substring(0, 3)];
    if (zipPlace != null)
      return OfflineLocationMatch(
        places[zipPlace]!,
        'ZIP ${zip![1]!.substring(0, 3)} region',
        'Approximate ZIP region',
      );
    for (final state in states.entries) {
      final name = state.value.$1.toLowerCase();
      if (text == state.key.toLowerCase() ||
          (' $text ').contains(' $name ') ||
          RegExp(
            '(?:,|\\s)${state.key}(?:\\s+\\d{5}|\\s*\u0024)',
          ).hasMatch(raw)) {
        return OfflineLocationMatch(
          LatLng(state.value.$2, state.value.$3),
          state.value.$1,
          'Approximate state center',
        );
      }
    }
    return null;
  }

  static double distanceMiles(LatLng a, LatLng b) {
    final lat = (b.latitude - a.latitude) * math.pi / 180;
    final lng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.pow(math.sin(lat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.pow(math.sin(lng / 2), 2);
    return 3958.7613 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }

  static String bearingCardinal(LatLng from, LatLng to) {
    if (distanceMiles(from, to) < 0.00001) return 'same position';
    final a = from.latitude * math.pi / 180,
        b = to.latitude * math.pi / 180,
        d = (to.longitude - from.longitude) * math.pi / 180;
    final degrees =
        (math.atan2(
                  math.sin(d) * math.cos(b),
                  math.cos(a) * math.sin(b) -
                      math.sin(a) * math.cos(b) * math.cos(d),
                ) *
                180 /
                math.pi +
            360) %
        360;
    return const [
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW',
    ][((degrees + 22.5) / 45).floor() % 8];
  }

  static String formatRelativePosition(
    LatLng from,
    LatLng to,
    String referenceName,
  ) =>
      '${distanceMiles(from, to).toStringAsFixed(1)} mi ${bearingCardinal(from, to)} of $referenceName';
  static LatLng midpoint(LatLng a, LatLng b) {
    final aLat = a.latitude * math.pi / 180,
        bLat = b.latitude * math.pi / 180,
        d = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.cos(bLat) * math.cos(d), y = math.cos(bLat) * math.sin(d);
    final lat = math.atan2(
      math.sin(aLat) + math.sin(bLat),
      math.sqrt(math.pow(math.cos(aLat) + x, 2) + y * y),
    );
    final lng = a.longitude * math.pi / 180 + math.atan2(y, math.cos(aLat) + x);
    return LatLng(
      lat * 180 / math.pi,
      ((lng * 180 / math.pi + 540) % 360) - 180,
    );
  }
}
