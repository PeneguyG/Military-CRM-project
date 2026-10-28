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
      // The home page has its own state for the selected navigation tab.
      home: CrmHomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

/// Describes one destination and the centered text shown when it is selected.
///
/// The navigation bar and the page body both read from the same tab list,
/// so a tab's label and its verification text stay paired by list index.
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

/// Main CRM shell containing the app bar, active page, and bottom tab bar.
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
  // This immutable list defines the four routes in display order. The selected
  // index is used for the navigation destination and the matching body text.
  static const List<_AppTab> _tabs = [
    _AppTab(
      label: 'Homepage',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      bodyText: 'Welcome back user',
    ),
    _AppTab(
      label: 'Customer lookup',
      icon: Icons.person_search_outlined,
      selectedIcon: Icons.person_search,
      bodyText: 'Customer lookup',
    ),
    _AppTab(
      label: 'Add customer',
      icon: Icons.person_add_alt_1_outlined,
      selectedIcon: Icons.person_add_alt_1,
      bodyText: 'Add customer',
    ),
    _AppTab(
      label: 'Statistics',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      bodyText: 'Statistics',
    ),
  ];

  // NavigationBar reports the tapped destination's index. Starting at zero
  // makes Homepage the initial screen when the app opens.
  int _selectedTabIndex = 0;

  /// Updates the one source of truth for tab selection and refreshes the UI.
  void _selectTab(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Looking up both title and body from the same tab ensures the app bar and
    // centered verification text always correspond to the selected tab.
    final selectedTab = _tabs[_selectedTabIndex];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedTab.label),
        actions: [
          // The theme action is kept available regardless of the active tab.
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
      // Each destination displays its required exact text, centered in the
      // available content area to make routing easy to verify.
      body: SafeArea(
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
      // Selecting a destination calls _selectTab; setState rebuilds the page
      // using the matching item in _tabs above.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
