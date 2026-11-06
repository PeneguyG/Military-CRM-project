import 'pages/offline_map_page.dart';
import 'dart:io';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
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
import 'pages/search_reporting_page.dart';
import 'models/crm_models.dart';

const _hopePrimary = Color(0xFF3A57E8);

ThemeData _hopeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF121722) : const Color(0xFFF5F7FB);
  final surface = dark ? const Color(0xFF1B2230) : Colors.white;
  final border = dark ? const Color(0xFF30394A) : const Color(0xFFE5E9F0);
  final inputSurface = dark ? const Color(0xFF202837) : const Color(0xFFF9FAFC);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _hopePrimary,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFA8B7FF) : _hopePrimary,
        onPrimary: dark ? const Color(0xFF111A42) : Colors.white,
        secondaryContainer: dark
            ? const Color(0xFF293653)
            : const Color(0xFFE8EDFF),
        onSecondaryContainer: dark
            ? const Color(0xFFD6DFFF)
            : const Color(0xFF253DA8),
        surface: surface,
        onSurface: dark ? const Color(0xFFE9ECF3) : const Color(0xFF202638),
        surfaceContainerLow: dark
            ? const Color(0xFF202735)
            : const Color(0xFFFAFBFD),
        outline: border,
        outlineVariant: border,
      );
  const inputRadius = BorderRadius.all(Radius.circular(11));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.secondaryContainer,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSecondaryContainer),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

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
  bool _themePreferenceLoaded = false;
  late final Timer _timer;
  Future<CrmStore>? _opening;
  CrmStore? _ownedStore;

  void _authenticate() {
    setState(() {
      _isAuthenticated = true;
      _opening = _openStore();
    });
  }

  void _lockApp() {
    _ownedStore?.dispose();
    _ownedStore = null;
    setState(() {
      _isAuthenticated = false;
      _opening = null;
    });
  }

  Future<File> _themePreferenceFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directoryPath = Platform.isWindows
        ? p.join(
            Platform.environment['APPDATA'] ?? supportDirectory.path,
            'com.example',
            'Steel Wings CRM',
            'MilitaryCRM',
          )
        : p.join(supportDirectory.path, 'MilitaryCRM');
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'theme_preference.txt'));
  }

  String? _windowsThemePreferencePath() {
    if (!Platform.isWindows) return null;
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return null;
    return p.join(
      appData,
      'com.example',
      'Steel Wings CRM',
      'MilitaryCRM',
      'theme_preference.txt',
    );
  }

  Future<void> _loadThemePreference() async {
    ThemeMode? savedPreference;
    try {
      final file = await _themePreferenceFile();
      if (await file.exists()) {
        savedPreference = switch ((await file.readAsString()).trim()) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => null,
        };
      }
    } catch (_) {
      // Start with automatic mode if local preferences cannot be read.
    }
    if (!mounted) return;
    setState(() {
      _override = savedPreference;
      _themePreferenceLoaded = true;
    });
  }

  void _setThemePreference(ThemeMode? preference) {
    setState(() => _override = preference);
    unawaited(_saveThemePreference(preference));
  }

  Future<void> _saveThemePreference(ThemeMode? preference) async {
    try {
      final value = preference?.name ?? 'automatic';
      final windowsPath = _windowsThemePreferencePath();
      if (windowsPath != null) {
        Directory(p.dirname(windowsPath)).createSync(recursive: true);
        File(windowsPath).writeAsStringSync(value, flush: true);
        return;
      }
      final file = await _themePreferenceFile();
      await file.writeAsString(value, flush: true);
    } catch (_) {
      // Keep the current in-memory selection even if the preference file is unavailable.
    }
  }

  Future<CrmStore> _openStore() async {
    if (widget.store != null) return widget.store!;
    const override = String.fromEnvironment('CRM_DATABASE_PATH');
    final databasePath = override.isNotEmpty
        ? p.absolute(override)
        : p.join(
            Platform.isWindows
                ? p.join(
                    Platform.environment['APPDATA'] ??
                        (throw StateError(
                          'Windows application-data folder is unavailable.',
                        )),
                    'com.example',
                    'Steel Wings CRM',
                  )
                : (await getApplicationSupportDirectory()).path,
            'MilitaryCRM',
            'military_crm.sqlite3',
          );
    final schema = await rootBundle.loadString('assets/schema_v1.sql');
    final database = await CrmDatabase.open(databasePath);
    final store = await CrmStore.open(database, schema);
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
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadThemePreference());
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
      localizationsDelegates: const [FlutterQuillLocalizations.delegate],
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _hopeTheme(Brightness.light),
      darkTheme: _hopeTheme(Brightness.dark),
      home: !_themePreferenceLoaded
          ? const _ThemePreferenceLoadingPage()
          : _isAuthenticated
          ? FutureBuilder<CrmStore>(
              future: _opening!,
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
                              'Could not open the protected database. Use the original Windows account and preserve the database and key files.',
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
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Loading Steel Wings CRM…',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                return CrmHomePage(
                  store: snapshot.data!,
                  isDarkMode: mode == ThemeMode.dark,
                  automaticTheme: _override == null,
                  onToggleTheme: () => _setThemePreference(
                    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  ),
                  onAutomaticThemeChanged: (enabled) =>
                      _setThemePreference(enabled ? null : mode),
                  onLock: _lockApp,
                );
              },
            )
          : _SignInPage(onAuthenticated: _authenticate),
    );
  }
}

class _ThemePreferenceLoadingPage extends StatelessWidget {
  const _ThemePreferenceLoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      label: 'Archive',
      icon: Icons.archive_outlined,
      selectedIcon: Icons.archive,
    ),
    _CrmDestination(
      label: 'Search and Reporting',
      icon: Icons.manage_search,
      selectedIcon: Icons.query_stats,
    ),
  ];

  // The active index is the navigation state used by the rail and page stack.
  int _tab = 0;
  bool _navigationCollapsed = false;

  // ContactsPage is recreated when a contact is opened from another section.
  // This lets it select and show the requested contact even if it was already
  // mounted in the IndexedStack.
  int _contactNavigation = 0;
  int? _contactId;
  int? _organizationId;
  int _organizationNavigation = 0;
  String? _mapFocus;
  int _mapRevision = 0;

  CrmStore get _store => widget.store;

  /// Selects a destination from the navigation rail.
  void _selectTab(int index) {
    setState(() => _tab = index);
  }

  /// Opens a contact in the existing Contacts page.
  void _openContact(Contact contact) {
    if (contact.isArchived) {
      editContact(context, _store, contact);
      return;
    }
    setState(() {
      _contactId = contact.id;
      _contactNavigation++;
      _tab = 1; // Contacts follows Home in the destination list.
    });
  }

  void _openOrganization(Organization organization) {
    if (organization.isArchived) {
      editOrganization(context, _store, organization);
      return;
    }
    setState(() {
      _organizationId = organization.id;
      _organizationNavigation++;
      _tab = 2;
    });
  }

  void _viewMap(String key) {
    setState(() {
      _mapFocus = key;
      _mapRevision++;
      _tab = 3;
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
      // The rail expands to readable labels on wider desktop windows. The
      // control in the content header can collapse it to icons only. The
      // destination buttons below update immediately without rail animations.
      final extendedRail =
          constraints.maxWidth >= 1000 && !_navigationCollapsed;
      final compactSelectedLabel =
          constraints.maxWidth < 1000 && !_navigationCollapsed;
      final railWidth = extendedRail ? 256.0 : 72.0;

      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: railWidth + 1,
                    height: 64,
                    padding: EdgeInsets.symmetric(
                      horizontal: extendedRail ? 14 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: extendedRail
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/steel_wings_crm_logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                        if (extendedRail) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Steel Wings CRM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: _navigationCollapsed
                                ? 'Expand navigation'
                                : 'Collapse navigation',
                            onPressed: () => setState(
                              () =>
                                  _navigationCollapsed = !_navigationCollapsed,
                            ),
                            icon: Icon(
                              _navigationCollapsed
                                  ? Icons.menu
                                  : Icons.menu_open,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tab == _settingsTab
                                ? 'Settings'
                                : _destinations[_tab].label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              tooltip: 'Lock app',
                              onPressed: widget.onLock,
                              icon: const Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      width: railWidth,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                children: [
                                  for (
                                    var index = 0;
                                    index < _destinations.length;
                                    index++
                                  )
                                    _NavigationItem(
                                      label: _destinations[index].label,
                                      icon: _tab == index
                                          ? _destinations[index].selectedIcon
                                          : _destinations[index].icon,
                                      selected: _tab == index,
                                      showLabel:
                                          extendedRail ||
                                          (compactSelectedLabel &&
                                              _tab == index),
                                      onPressed: () => _selectTab(index),
                                    ),
                                ],
                              ),
                            ),
                            _NavigationItem(
                              label: 'Settings',
                              icon: _tab == _settingsTab
                                  ? Icons.settings
                                  : Icons.settings_outlined,
                              selected: _tab == _settingsTab,
                              showLabel: extendedRail,
                              onPressed: () => _selectTab(_settingsTab),
                            ),
                          ],
                        ),
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
                            onViewMap: _viewMap,
                          ),
                          OrganizationsPage(
                            key: ValueKey(
                              'organization:$_organizationNavigation',
                            ),
                            initialOrganizationId: _organizationId,
                            onViewMap: _viewMap,
                            store: _store,
                            onSelectContact: _openContact,
                          ),
                          OfflineMapPage(
                            store: _store,
                            onOpenContact: _openContact,
                            onOpenOrganization: _openOrganization,
                            focusRecordKey: _mapFocus,
                            focusRevision: _mapRevision,
                          ),
                          ArchivePage(store: _store),
                          SearchReportingPage(
                            store: _store,
                            onOpenContact: _openContact,
                            onOpenOrganization: _openOrganization,
                          ),
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.showLabel,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          selected: selected,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onPressed,
              mouseCursor: SystemMouseCursors.click,
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Icon(
                        icon,
                        color: selected ? colors.onSecondaryContainer : null,
                      ),
                    ),
                    if (showLabel)
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? colors.onSecondaryContainer
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
