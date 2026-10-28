import 'dart:async';
import 'package:flutter/material.dart';
import 'crm_store.dart';
import 'models/crm_models.dart';
import 'pages/contacts_page.dart';
import 'pages/organizations_page.dart';

void main() => runApp(const MilitaryCrmApp());

class MilitaryCrmApp extends StatefulWidget {
  const MilitaryCrmApp({super.key});
  @override
  State<MilitaryCrmApp> createState() => _MilitaryCrmAppState();
}

class _MilitaryCrmAppState extends State<MilitaryCrmApp>
    with WidgetsBindingObserver {
  ThemeMode? _override;
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final mode = _override ??
        (hour >= 6 && hour < 18 ? ThemeMode.light : ThemeMode.dark);
    return MaterialApp(
        title: 'Military CRM',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal, brightness: Brightness.dark)),
        home: CrmHomePage(
            isDarkMode: mode == ThemeMode.dark,
            automaticTheme: _override == null,
            onToggleTheme: () => setState(() => _override =
                mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
            onAutomaticTheme: () => setState(() => _override = null)));
  }
}

class CrmHomePage extends StatefulWidget {
  const CrmHomePage(
      {super.key,
      required this.isDarkMode,
      required this.onToggleTheme,
      required this.automaticTheme,
      required this.onAutomaticTheme});
  final bool isDarkMode, automaticTheme;
  final VoidCallback onToggleTheme, onAutomaticTheme;
  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  int _tab = 0, _contactNavigation = 0;
  int? _contactId;
  final _store = CrmStore(organizations: const [
    Organization(
        id: 1,
        name: 'Fort Liberty Support Group',
        industry: 'Military support',
        address: 'Fayetteville, NC',
        phone: '+1-202-555-0101',
        email: 'support@example.com',
        notes:
            'Fictional demonstration organization. Coordinates family readiness events.'),
    Organization(
        id: 2,
        name: 'Sentinel Defense Systems',
        industry: 'Defense technology',
        address: 'Arlington, VA',
        phone: '+1-202-555-0102',
        email: 'liaison@example.com',
        notes:
            'Fictional demonstration organization. Quarterly logistics briefings.'),
    Organization(
        id: 3,
        name: 'Veterans Outreach Unit',
        industry: 'Veteran services',
        address: 'Nashville, TN',
        notes: 'Former regional partner.',
        isArchived: true),
  ], contacts: const [
    Contact(
        id: 1,
        organizationId: 1,
        firstName: 'Alex',
        lastName: 'Morgan',
        title: 'Major',
        phone: '+1-202-555-0111',
        email: 'alex.morgan@example.com',
        address: 'Fayetteville, NC',
        spouseName: 'Jordan',
        childrenInfo: 'Two children',
        talkingPoints: 'Family readiness event; volunteer schedule.',
        notes: 'Fictional sample contact. Prefers afternoon calls.'),
    Contact(
        id: 2,
        organizationId: 2,
        firstName: 'Taylor',
        lastName: 'Reed',
        title: 'Liaison Officer',
        phone: '+1-202-555-0112',
        email: 'taylor.reed@example.com',
        address: 'Arlington, VA',
        talkingPoints: 'Upcoming logistics workshop.',
        status: ContactStatus.inactive),
    Contact(
        id: 3,
        organizationId: 3,
        firstName: 'Sam',
        lastName: 'Hayes',
        title: 'Colonel (Ret.)',
        status: ContactStatus.deceased,
        isArchived: true,
        notes: 'Historical contact retained in full.'),
  ], interactions: [
    InteractionLog(
        id: 1,
        contactId: 1,
        organizationId: 1,
        date: DateTime.now().subtract(const Duration(days: 3)),
        type: 'Call',
        summary: 'Discussed the next family readiness event.',
        followUpDate: DateTime.now().add(const Duration(days: 7))),
    InteractionLog(
        id: 2,
        contactId: 2,
        organizationId: 2,
        date: DateTime.now().subtract(const Duration(days: 1)),
        type: 'Email',
        summary: 'Shared workshop agenda.'),
  ]);
  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
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
                      icon: Icon(widget.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode)),
                  IconButton(
                      tooltip: widget.automaticTheme
                          ? 'Automatic theme enabled (06:00–18:00 light)'
                          : 'Use automatic time-based theme',
                      onPressed: widget.onAutomaticTheme,
                      icon: Icon(widget.automaticTheme
                          ? Icons.schedule
                          : Icons.update)),
                ]),
            body: SafeArea(
                child: Column(children: [
              const MaterialBanner(
                  content: Text(
                      'Demo · fictional data · changes last for this session'),
                  actions: [SizedBox.shrink()]),
              Expanded(
                  child: Row(children: [
                if (wide) ...[
                  NavigationRail(
                      selectedIndex: _tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (v) => setState(() => _tab = v),
                      destinations: const [
                        NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            label: Text('Contacts')),
                        NavigationRailDestination(
                            icon: Icon(Icons.business_outlined),
                            label: Text('Organizations')),
                      ]),
                  const VerticalDivider(width: 1)
                ],
                Expanded(
                    child: IndexedStack(index: _tab, children: [
                  ContactsPage(
                      key: ValueKey(_contactNavigation),
                      store: _store,
                      initialContactId: _contactId),
                  OrganizationsPage(
                      store: _store,
                      onSelectContact: (c) => setState(() {
                            _contactId = c.id;
                            _contactNavigation++;
                            _tab = 0;
                          })),
                ])),
              ])),
            ])),
            bottomNavigationBar: wide
                ? null
                : BottomNavigationBar(
                    currentIndex: _tab,
                    onTap: (v) => setState(() => _tab = v),
                    items: const [
                        BottomNavigationBarItem(
                            icon: Icon(Icons.people_outline),
                            label: 'Contacts'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.business_outlined),
                            label: 'Organizations'),
                      ]));
      });
}
