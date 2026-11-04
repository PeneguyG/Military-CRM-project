import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'crm_store.dart';
import 'data/crm_database.dart';
import 'pages/contacts_page.dart';
import 'pages/organizations_page.dart';
import 'pages/home_page.dart';
import 'pages/archive_page.dart';
import 'pages/settings_page.dart';
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
  bool _isAuthenticated = false;
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
      title: 'Steel Wings CRM',
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
      home: _isAuthenticated
          ? FutureBuilder<CrmStore>(
              future: _opening,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Scaffold(
                    appBar: AppBar(title: const Text('Steel Wings CRM')),
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
                  onAutomaticThemeChanged: (enabled) =>
                      setState(() => _override = enabled ? null : mode),
                  onLock: () => setState(() => _isAuthenticated = false),
                );
              },
            )
          : _SignInPage(
              onAuthenticated: () => setState(() => _isAuthenticated = true),
            ),
    );
  }
}

class _SignInPage extends StatefulWidget {
  const _SignInPage({required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  static const _password = 'Mushroomkingdom24?';
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passwordController.text == _password) {
      FocusScope.of(context).unfocus();
      widget.onAuthenticated();
      return;
    }

    setState(() {
      _error = 'Incorrect password. Try again.';
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/steel_wings_crm_logo.png',
                        width: 300,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to Steel Wings CRM',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: _error,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
    required this.onAutomaticThemeChanged,
    required this.onLock,
  });

  final bool isDarkMode;
  final bool automaticTheme;
  final CrmStore store;
  final VoidCallback onToggleTheme;
  final ValueChanged<bool> onAutomaticThemeChanged;
  final VoidCallback onLock;

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  static const int _settingsTab = 6;
  // These ordered destinations are shared by the navigation rail and the
  // IndexedStack page routing.
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

  // The active index is the navigation state used by the rail and page stack.
  int _tab = 0;

  // ContactsPage is recreated when a contact is opened from another section.
  // This lets it select and show the requested contact even if it was already
  // mounted in the IndexedStack.
  int _contactNavigation = 0;
  int? _contactId;

  CrmStore get _store => widget.store;

  /// Selects a destination from the navigation rail.
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

  void _showDatabaseLocation() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database location'),
        content: SelectableText(
          _store.databasePath ?? 'No persistent database is in use.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The rail expands to readable labels on wider desktop windows. On
      // narrower windows it stays compact and shows the active label only.
      final extendedRail = constraints.maxWidth >= 1000;

      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Lock app',
                    onPressed: widget.onLock,
                    icon: const Icon(Icons.lock_outline),
                  ),
                ),
              ),
              Expanded(
                // Keep navigation on the left for desktop and compact windows.
                // Each indexed child retains its own page state while another
                // tab is selected.
                child: Row(
                  children: [
                    SizedBox(
                      // Row gives non-flex children unbounded width; keep the
                      // rail and bottom Settings tab at a known width.
                      width: extendedRail ? 256 : 72,
                      child: Column(
                        children: [
                          Expanded(
                            child: NavigationRail(
                              minWidth: 72,
                              minExtendedWidth: 256,
                              extended: extendedRail,
                              labelType: extendedRail
                                  ? null
                                  : NavigationRailLabelType.selected,
                              groupAlignment: -1,
                              scrollable: true,
                              selectedIndex: _tab == _settingsTab ? null : _tab,
                              onDestinationSelected: _selectTab,
                              destinations: [
                                for (final destination in _destinations)
                                  NavigationRailDestination(
                                    icon: Icon(destination.icon),
                                    selectedIcon: Icon(
                                      destination.selectedIcon,
                                    ),
                                    label: Text(destination.label),
                                  ),
                              ],
                            ),
                          ),
                          _SettingsNavigationButton(
                            extended: extendedRail,
                            selected: _tab == _settingsTab,
                            onPressed: () => _selectTab(_settingsTab),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          HomePage(store: _store, onOpenContact: _openContact),
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
                          ArchivePage(store: _store),
                          SettingsPage(
                            store: _store,
                            isDarkMode: widget.isDarkMode,
                            automaticTheme: widget.automaticTheme,
                            onToggleTheme: widget.onToggleTheme,
                            onAutomaticThemeChanged:
                                widget.onAutomaticThemeChanged,
                            onDatabaseLocation: _showDatabaseLocation,
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

class _SettingsNavigationButton extends StatelessWidget {
  const _SettingsNavigationButton({
    required this.extended,
    required this.selected,
    required this.onPressed,
  });

  final bool extended;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: extended
          ? Material(
              color: selected ? colors.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: Icon(
                  selected ? Icons.settings : Icons.settings_outlined,
                ),
                title: const Text('Settings'),
                selected: selected,
                onTap: onPressed,
              ),
            )
          : IconButton(
              tooltip: 'Settings',
              onPressed: onPressed,
              style: selected
                  ? IconButton.styleFrom(
                      backgroundColor: colors.secondaryContainer,
                      foregroundColor: colors.onSecondaryContainer,
                    )
                  : null,
              icon: Icon(selected ? Icons.settings : Icons.settings_outlined),
            ),
    );
  }
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
