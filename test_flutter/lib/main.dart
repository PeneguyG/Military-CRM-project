import 'package:flutter/material.dart';

/// Starts the Flutter application with the CRM home page as its root screen.
void main() {
  runApp(const MilitaryCrmApp());
}

/// Owns app-wide settings, including the theme used by every navigation tab.
class MilitaryCrmApp extends StatefulWidget {
  const MilitaryCrmApp({super.key});

  @override
  State<MilitaryCrmApp> createState() => _MilitaryCrmAppState();
}

class _MilitaryCrmAppState extends State<MilitaryCrmApp> {
  // Keeping the theme mode here lets MaterialApp rebuild the entire app when
  // the user taps the theme button in the home page's app bar.
  ThemeMode _themeMode = ThemeMode.light;

  /// Switches between the light and dark Material 3 color schemes.
  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Military CRM',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      // Both color schemes use the same seed, so the visual identity stays
      // consistent while Flutter adjusts colors for the selected brightness.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // The home page owns the selected destination and its page content.
      home: CrmHomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

/// Describes one destination and the centered text shown when it is selected.
///
/// Both the navigation rail and active page use the same tab list. This keeps
/// each label, icon, and page message paired at the same list index.
class _AppTab {
  const _AppTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.bodyText,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String bodyText;
}

/// Main CRM shell containing the app bar, left navigation rail, and page body.
class CrmHomePage extends StatefulWidget {
  const CrmHomePage({
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  // This immutable list defines the six destinations in display order.
  // The selected index identifies the active destination and body message.
  static const List<_AppTab> _tabs = [
    _AppTab(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      bodyText: 'Welcome back user',
    ),
    _AppTab(
      label: 'Contacts',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      bodyText: 'Contacts',
    ),
    _AppTab(
      label: 'Organizations',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      bodyText: 'Organizations',
    ),
    _AppTab(
      label: 'Map',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      bodyText: 'Map',
    ),
    _AppTab(
      label: 'Search and Reporting',
      icon: Icons.manage_search,
      selectedIcon: Icons.query_stats,
      bodyText: 'Search and Reporting',
    ),
    _AppTab(
      label: 'Archive',
      icon: Icons.archive_outlined,
      selectedIcon: Icons.archive,
      bodyText: 'Archive',
    ),
  ];

  // NavigationRail reports the tapped destination's index. Starting at zero
  // makes Home the first page shown when the app opens.
  int _selectedTabIndex = 0;

  /// Updates the selected destination and asks Flutter to rebuild this page.
  void _selectTab(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // A single selected-tab lookup keeps the app bar title and page body in
    // sync with the selected navigation destination.
    final selectedTab = _tabs[_selectedTabIndex];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedTab.label),
        actions: [
          // The theme action remains available from every destination.
          IconButton(
            tooltip: widget.isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // The row places navigation on the left and the active page beside it.
      body: SafeArea(
        child: Row(
          children: [
            // Extended mode shows labels beside icons, so all six destinations
            // remain readable, including the longer Search and Reporting tab.
            NavigationRail(
              extended: true,
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: _selectTab,
              destinations: [
                for (final tab in _tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              // The selected tab's message stays centered in the space to the
              // right of the rail, independent of the sidebar's width.
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    selectedTab.bodyText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
