import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'crm_store.dart';
import 'data/crm_database.dart';
import 'pages/crm_widgets.dart';
import 'pages/contacts_page.dart';
import 'pages/organizations_page.dart';

void main() => runApp(const MilitaryCrmApp());

class MilitaryCrmApp extends StatefulWidget {
  const MilitaryCrmApp({super.key, this.store});
  final CrmStore? store;
  @override
  State<MilitaryCrmApp> createState() => _MilitaryCrmAppState();
}

class _MilitaryCrmAppState extends State<MilitaryCrmApp>
    with WidgetsBindingObserver {
  ThemeMode? _override;
  late final Timer _timer;
  late Future<CrmStore> _opening;
  CrmStore? _ownedStore;
  Future<CrmStore> _openStore() async {
    if (widget.store != null) return widget.store!;
    const override = String.fromEnvironment('CRM_DATABASE_PATH');
    final databasePath = override.isNotEmpty
        ? p.absolute(override)
        : p.join(
            (await getApplicationSupportDirectory()).path,
            'MilitaryCRM',
            'military_crm.sqlite3',
          );
    final schema = await rootBundle.loadString('assets/schema_v1.sql');
    final store = await CrmStore.open(CrmDatabase(databasePath), schema);
    if (!mounted) {
      store.dispose();
    } else {
      _ownedStore = store;
    }
    return store;
  }

  @override
  void initState() {
    super.initState();
    _opening = _openStore();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_override == null) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _override == null)
      setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    _ownedStore?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final mode =
        _override ??
        (hour >= 6 && hour < 18 ? ThemeMode.light : ThemeMode.dark);
    return MaterialApp(
      title: 'Military CRM',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: FutureBuilder<CrmStore>(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Scaffold(
              appBar: AppBar(title: const Text('Military CRM')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not open the local database. Check that its folder is writable and the database is not locked.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText('${snapshot.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _opening = _openStore()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          if (!snapshot.hasData)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          return CrmHomePage(
            store: snapshot.data!,
            isDarkMode: mode == ThemeMode.dark,
            automaticTheme: _override == null,
            onToggleTheme: () => setState(
              () => _override = mode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
            onAutomaticTheme: () => setState(() => _override = null),
          );
        },
      ),
    );
  }
}

class CrmHomePage extends StatefulWidget {
  const CrmHomePage({
    super.key,
    required this.store,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.automaticTheme,
    required this.onAutomaticTheme,
  });
  final bool isDarkMode, automaticTheme;
  final CrmStore store;
  final VoidCallback onToggleTheme, onAutomaticTheme;
  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  int _tab = 0, _contactNavigation = 0;
  int? _contactId;
  CrmStore get _store => widget.store;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      return Scaffold(
        appBar: AppBar(
          title: Text(_tab == 0 ? 'Contacts' : 'Organizations'),
          actions: [
            IconButton(
              tooltip: widget.isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
            ),
            IconButton(
              tooltip: widget.automaticTheme
                  ? 'Automatic theme enabled (06:00–18:00 light)'
                  : 'Use automatic time-based theme',
              onPressed: widget.onAutomaticTheme,
              icon: Icon(widget.automaticTheme ? Icons.schedule : Icons.update),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              MaterialBanner(
                content: Text(
                  _store.databasePath == null
                      ? 'Test data'
                      : 'Saved locally in SQLite',
                ),
                actions: [
                  if (_store.databasePath != null)
                    IconButton(
                      tooltip: 'Database location',
                      icon: const Icon(Icons.storage),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Database location'),
                          content: SelectableText(_store.databasePath!),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Refresh records',
                    onPressed: () => runDatabaseAction(context, _store.reload),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    if (wide) ...[
                      NavigationRail(
                        selectedIndex: _tab,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: (v) => setState(() => _tab = v),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            label: Text('Contacts'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.business_outlined),
                            label: Text('Organizations'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          ContactsPage(
                            key: ValueKey(_contactNavigation),
                            store: _store,
                            initialContactId: _contactId,
                          ),
                          OrganizationsPage(
                            store: _store,
                            onSelectContact: (c) => setState(() {
                              _contactId = c.id;
                              _contactNavigation++;
                              _tab = 0;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : BottomNavigationBar(
                currentIndex: _tab,
                onTap: (v) => setState(() => _tab = v),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_outline),
                    label: 'Contacts',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.business_outlined),
                    label: 'Organizations',
                  ),
                ],
              ),
      );
    },
  );
}
