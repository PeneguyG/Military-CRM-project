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
import 'pages/home_page.dart';
import 'models/crm_models.dart';

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

/// One entry in the CRM navigation system, including its regular and selected icon.
class _CrmDestination {
  const _CrmDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Main CRM shell that coordinates navigation, existing record pages, and Home.
class CrmHomePage extends StatefulWidget {
  const CrmHomePage({
    super.key,
    required this.store,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.automaticTheme,
    required this.onAutomaticTheme,
  });

  final bool isDarkMode;
  final bool automaticTheme;
  final CrmStore store;
  final VoidCallback onToggleTheme;
  final VoidCallback onAutomaticTheme;

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  // These ordered destinations are the shared source for the rail, app-bar
  // title, Home shortcuts, and IndexedStack page routing.
  static const List<_CrmDestination> _destinations = [
    _CrmDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _CrmDestination(
      label: 'Contacts',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    _CrmDestination(
      label: 'Organizations',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
    ),
    _CrmDestination(
      label: 'Map',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
    ),
    _CrmDestination(
      label: 'Search and Reporting',
      icon: Icons.manage_search,
      selectedIcon: Icons.query_stats,
    ),
    _CrmDestination(
      label: 'Archive',
      icon: Icons.archive_outlined,
      selectedIcon: Icons.archive,
    ),
  ];

  // The active index is the single navigation state used by every route
  // control, so a rail selection and a Home shortcut open the same page.
  int _tab = 0;

  // ContactsPage is recreated when a contact is opened from another section.
  // This lets it select and show the requested contact even if it was already
  // mounted in the IndexedStack.
  int _contactNavigation = 0;
  int? _contactId;

  CrmStore get _store => widget.store;

  /// Selects a destination from either the rail or a Home shortcut.
  void _selectTab(int index) {
    setState(() => _tab = index);
  }

  /// Opens a contact in the existing Contacts page.
  void _openContact(Contact contact) {
    setState(() {
      _contactId = contact.id;
      _contactNavigation++;
      _tab = 1; // Contacts follows Home in the destination list.
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The rail expands to readable labels on wider desktop windows. On
      // narrower windows it stays compact and shows the active label only.
      final extendedRail = constraints.maxWidth >= 1000;

      return Scaffold(
        appBar: AppBar(
          title: Text(_destinations[_tab].label),
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
              // This banner continues to report whether records are saved in
              // SQLite or supplied by an in-memory test store.
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
                // Keep navigation on the left for desktop and compact windows.
                // Each indexed child retains its own page state while another
                // tab is selected.
                child: Row(
                  children: [
                    NavigationRail(
                      extended: extendedRail,
                      labelType: extendedRail
                          ? null
                          : NavigationRailLabelType.selected,
                      groupAlignment: -1,
                      selectedIndex: _tab,
                      onDestinationSelected: _selectTab,
                      destinations: [
                        for (final destination in _destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          HomePage(
                            store: _store,
                            shortcuts: [
                              // Build one Home shortcut for every destination
                              // after Home, using the same navigation indices.
                              for (
                                var index = 1;
                                index < _destinations.length;
                                index++
                              )
                                HomeShortcut(
                                  tabIndex: index,
                                  label: _destinations[index].label,
                                  icon: _destinations[index].icon,
                                ),
                            ],
                            onSelectTab: _selectTab,
                            onOpenContact: _openContact,
                          ),
                          ContactsPage(
                            key: ValueKey(_contactNavigation),
                            store: _store,
                            initialContactId: _contactId,
                          ),
                          OrganizationsPage(
                            store: _store,
                            onSelectContact: _openContact,
                          ),
                          _SectionPlaceholder(
                            title: _destinations[3].label,
                            icon: _destinations[3].icon,
                          ),
                          _SectionPlaceholder(
                            title: _destinations[4].label,
                            icon: _destinations[4].icon,
                          ),
                          _SectionPlaceholder(
                            title: _destinations[5].label,
                            icon: _destinations[5].icon,
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
      );
    },
  );
}

/// Keeps a destination visibly routable while its full feature page is pending.
class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}
