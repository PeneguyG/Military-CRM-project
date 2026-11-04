import 'package:greeting_app/main.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/models/crm_models.dart';
import 'package:greeting_app/pages/offline_map_page.dart';
import 'package:greeting_app/utils/offline_map_helper.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Map attempted network access');
}

void main() {
  testWidgets(
    'Record navigation opens the Map tab and returns to the organization',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = CrmStore(
        organizations: [
          const Organization(
            id: 1,
            name: 'Map Navigation Unit',
            latitude: 36,
            longitude: -86,
          ),
        ],
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CrmHomePage(
            store: store,
            isDarkMode: false,
            automaticTheme: false,
            onToggleTheme: () {},
            onAutomaticThemeChanged: (_) {},
            onLock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organizations').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map Navigation Unit').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View on Map'));
      await tester.pumpAndSettle();
      expect(find.text('Offline map'), findsOneWidget);
      expect(find.text('Open record'), findsOneWidget);
      await tester.tap(find.text('Open record'));
      await tester.pumpAndSettle();
      expect(find.text('View on Map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Offline gazetteer and distance engine handle coordinates and unknowns',
    () {
      expect(
        OfflineMapHelper.resolve('36.1, -86.5')!.point,
        const LatLng(36.1, -86.5),
      );
      expect(OfflineMapHelper.resolve('91, 181'), isNull);
      expect(OfflineMapHelper.resolve('Unknown village overseas'), isNull);
      expect(
        OfflineMapHelper.resolve(
          '123 Example Road, Murfreesboro, TN 37130',
        )!.label,
        'murfreesboro',
      );
      expect(
        OfflineMapHelper.resolve('Fort Campbell, KY')!.precision,
        'Approximate city/base center',
      );
      expect(
        OfflineMapHelper.resolve('38501')!.precision,
        'Approximate ZIP region',
      );
      expect(
        OfflineMapHelper.resolve('Wyoming')!.precision,
        'Approximate state center',
      );
      expect(
        OfflineMapHelper.distanceMiles(const LatLng(0, 0), const LatLng(0, 1)),
        closeTo(69.093, 0.01),
      );
      expect(
        OfflineMapHelper.bearingCardinal(
          const LatLng(0, 0),
          const LatLng(1, 0),
        ),
        'N',
      );
      expect(
        OfflineMapHelper.bearingCardinal(
          const LatLng(0, 0),
          const LatLng(0, -1),
        ),
        'W',
      );
      expect(
        OfflineMapHelper.distanceMiles(
          const LatLng(0, 179),
          const LatLng(0, -179),
        ),
        closeTo(138.186, 0.02),
      );
      expect(
        OfflineMapHelper.midpoint(
          const LatLng(0, 179),
          const LatLng(0, -179),
        ).longitude.abs(),
        closeTo(180, 0.001),
      );
    },
  );
  test('Coordinates and home base persist and migrate', () async {
    final dir = Directory.systemTemp.createTempSync('map_store');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/crm.sqlite3';
    final database = CrmDatabase.unencryptedForTesting(path);
    final schema = File('assets/schema_v1.sql').readAsStringSync();
    var store = await CrmStore.open(database, schema);
    await store.saveOrganization(
      const Organization(name: 'Unit', address: 'Nashville, TN'),
    );
    expect(store.organizations.single.latitude, closeTo(36.163, 0.01));
    await store.saveContact(
      const Contact(firstName: 'Alex', lastName: 'Smith', address: 'Unknown'),
    );
    expect(store.contacts.single.latitude, isNull);
    await store.saveContact(
      store.contacts.single.copyWith(latitude: 0, longitude: 0),
    );
    expect(store.contacts.single.longitude, 0);
    await store.saveOrganization(
      store.organizations.single.copyWith(address: 'Unresolved new address'),
    );
    expect(store.organizations.single.latitude, isNull);
    await store.saveUserLocation(
      const UserLocation(latitude: 35.5, longitude: -86.4, label: 'Home'),
    );
    store.dispose();
    store = await CrmStore.open(database, schema);
    expect(store.userLocation.label, 'Home');
    expect(store.userLocation.latitude, 35.5);
    expect(store.contacts.single.latitude, 0);
    expect(
      store.contacts.single.copyWith(latitude: null, longitude: null).latitude,
      isNull,
    );
    store.dispose();
    final db = sqlite3.open(path);
    db.execute("UPDATE organizations SET address='Huntsville, AL'");
    for (final table in ['organizations', 'contacts']) {
      for (final column in ['latitude', 'longitude', 'coordinate_source']) {
        db.execute('ALTER TABLE $table DROP COLUMN $column');
      }
    }
    db.execute('DROP TABLE map_settings');
    db.execute('DELETE FROM crm_app_migrations WHERE version=16');
    db.close();
    final snapshot = await database.initialize(schema);
    expect(
      snapshot['organizations']!.single['latitude'],
      closeTo(34.731, 0.01),
    );
    expect(snapshot['contacts'], hasLength(1));
  });
  testWidgets(
    'Map renders offline, selects nearest records, filters and places pins',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = HttpOverrides.current;
      HttpOverrides.global = _NoNetwork();
      addTearDown(() => HttpOverrides.global = before);
      final store = CrmStore(
        organizations: [
          const Organization(
            id: 1,
            name: 'Atlas Brigade',
            industry: 'Defense',
            address: 'Nashville',
            latitude: 36.3,
            longitude: -86.7,
            coordinateSource: 'Approximate city center',
          ),
        ],
        contacts: [
          const Contact(
            id: 1,
            firstName: 'Alex',
            lastName: 'Smith',
            militaryRank: 'Major',
            latitude: 36.1,
            longitude: -86.9,
          ),
          const Contact(id: 2, firstName: 'Unmapped', lastName: 'Person'),
        ],
      );
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      Contact? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: OfflineMapPage(
                store: store,
                onOpenOrganization: (_) {},
                onOpenContact: (c) => opened = c,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      await tester.tap(find.text('Alex Smith').last);
      await tester.pumpAndSettle();
      expect(find.text('Nearest records'), findsOneWidget);
      expect(find.text('Open record'), findsOneWidget);

      await tester.tap(find.text('Open record'));
      expect(opened?.id, 1);
      await tester.tap(find.text('Place Me on map'));
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pumpAndSettle();
      expect(store.userLocation.label, 'My base');
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Nearest records'), findsNothing);
      expect(tester.takeException(), isNull);
      // Narrow layout and dark mode must remain usable without overflow.
      tester.view.physicalSize = const Size(560, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OfflineMapPage(
              store: store,
              onOpenOrganization: (_) {},
              onOpenContact: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
