import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../crm_store.dart';
import '../models/crm_models.dart';
import 'crm_widgets.dart';

enum _SearchScope { all, contacts, organizations }

class SearchReportingPage extends StatefulWidget {
  const SearchReportingPage({
    super.key,
    required this.store,
    required this.onOpenContact,
    required this.onOpenOrganization,
  });

  final CrmStore store;
  final ValueChanged<Contact> onOpenContact;
  final ValueChanged<Organization> onOpenOrganization;

  @override
  State<SearchReportingPage> createState() => _SearchReportingPageState();
}

class _SearchReportingPageState extends State<SearchReportingPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  _SearchScope _scope = _SearchScope.all;
  final Set<int> _selectedContactIds = {};
  final Set<int> _selectedOrganizationIds = {};
  final Set<int> _selectedTagIds = {};
  final Set<String> _selectedLocations = {};
  final Set<String> _selectedRanks = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(String query, String searchableText) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final haystack = searchableText.toLowerCase();
    return terms.every(haystack.contains);
  }

  int get _activeFilterCount =>
      _selectedContactIds.length +
      _selectedOrganizationIds.length +
      _selectedTagIds.length +
      _selectedLocations.length +
      _selectedRanks.length +
      (_scope == _SearchScope.all ? 0 : 1);

  List<String> _tagsFor(Contact contact) {
    final matchingTags = widget.store.profileTags.where((tag) {
      if (tag.category == 'preferred_contact' &&
          tag.value == contact.preferredContactMethod) {
        return true;
      }
      if (tag.category == 'life_status' && tag.value == contact.lifeStatus) {
        return true;
      }
      return tag.id != null && contact.customTagIds.contains(tag.id);
    });
    return matchingTags
        .expand((tag) => [tag.label, tag.value])
        .where((text) => text.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  bool _hasTag(Contact contact, ProfileTagDefinition tag) =>
      (tag.id != null && contact.customTagIds.contains(tag.id)) ||
      (tag.category == 'preferred_contact' &&
          tag.value == contact.preferredContactMethod) ||
      (tag.category == 'life_status' && tag.value == contact.lifeStatus);

  String _tagCategoryLabel(String category) => switch (category) {
    'preferred_contact' => 'Preferred contact',
    'life_status' => 'Life status',
    _ => 'Custom',
  };

  String _contactSearchText(Contact contact) {
    final organization = widget.store.organization(contact.organizationId);
    return [
      contact.searchText,
      ..._tagsFor(contact),
      organization?.searchText ?? '',
    ].join(' ');
  }

  bool _matchesContact(Contact contact, String query) {
    if (_scope == _SearchScope.organizations) return false;
    if (_selectedContactIds.isNotEmpty &&
        !(_selectedContactIds.contains(contact.id))) {
      return false;
    }
    if (_selectedContactIds.isEmpty && _selectedOrganizationIds.isNotEmpty) {
      return false;
    }
    if (_selectedTagIds.isNotEmpty &&
        !widget.store.profileTags.any(
          (tag) => _selectedTagIds.contains(tag.id) && _hasTag(contact, tag),
        )) {
      return false;
    }
    if (_selectedRanks.isNotEmpty &&
        !_selectedRanks.contains(contact.militaryRank.trim())) {
      return false;
    }
    if (_selectedLocations.isNotEmpty) {
      final organization = widget.store.organization(contact.organizationId);
      if (!_selectedLocations.contains(contact.address.trim()) &&
          !_selectedLocations.contains(organization?.address.trim())) {
        return false;
      }
    }
    return query.isEmpty || _matches(query, _contactSearchText(contact));
  }

  bool _matchesOrganization(Organization organization, String query) {
    if (_scope == _SearchScope.contacts ||
        _selectedContactIds.isNotEmpty && _selectedOrganizationIds.isEmpty ||
        _selectedTagIds.isNotEmpty ||
        _selectedRanks.isNotEmpty) {
      return false;
    }
    if (_selectedOrganizationIds.isNotEmpty &&
        !(_selectedOrganizationIds.contains(organization.id))) {
      return false;
    }
    if (_selectedLocations.isNotEmpty &&
        !_selectedLocations.contains(organization.address.trim())) {
      return false;
    }
    return query.isEmpty || _matches(query, organization.searchText);
  }

  void _clearFilters() {
    setState(() {
      _scope = _SearchScope.all;
      _selectedContactIds.clear();
      _selectedOrganizationIds.clear();
      _selectedTagIds.clear();
      _selectedLocations.clear();
      _selectedRanks.clear();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final query = _searchController.text.trim();
      final contactsWithIds =
          widget.store.contacts
              .where((contact) => !contact.isArchived && contact.id != null)
              .toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
      final organizationsWithIds =
          widget.store.organizations
              .where(
                (organization) =>
                    !organization.isArchived && organization.id != null,
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      final tagDefinitions =
          widget.store.profileTags.where((tag) => tag.id != null).toList()
            ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
            );
      final locations = <String>{
        for (final contact in contactsWithIds)
          if (contact.address.trim().isNotEmpty) contact.address.trim(),
        for (final organization in organizationsWithIds)
          if (organization.address.trim().isNotEmpty)
            organization.address.trim(),
      }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final ranks =
          contactsWithIds
              .map((contact) => contact.militaryRank.trim())
              .where((rank) => rank.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final hasFilter = query.isNotEmpty || _activeFilterCount > 0;
      final contacts =
          _scope == _SearchScope.organizations
                ? <Contact>[]
                : widget.store.contacts.where((contact) {
                    if (contact.isArchived) return false;
                    return _matchesContact(contact, query);
                  }).toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
      final organizations =
          _scope == _SearchScope.contacts
                ? <Organization>[]
                : widget.store.organizations.where((organization) {
                    if (organization.isArchived) return false;
                    return _matchesOrganization(organization, query);
                  }).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      final drawerWidth = math.min(
        420.0,
        MediaQuery.sizeOf(context).width * 0.85,
      );
      return Scaffold(
        key: _scaffoldKey,
        endDrawer: _filterDrawer(
          context,
          drawerWidth,
          contactsWithIds,
          organizationsWithIds,
          tagDefinitions,
          locations,
          ranks,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchSection(
                    context,
                    query,
                    hasFilter,
                    contacts,
                    organizations,
                  ),
                  const Divider(height: 48, indent: 8, endIndent: 8),
                  _analyticsSection(context),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _searchSection(
    BuildContext context,
    String query,
    bool hasFilter,
    List<Contact> contacts,
    List<Organization> organizations,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter records', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Search records, then use the filter button to narrow results by selected values.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Search records',
                      hintText:
                          'Search names, tags, locations, or military ranks',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Open filters',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: Badge(
                    isLabelVisible: _activeFilterCount > 0,
                    label: Text('$_activeFilterCount'),
                    child: const Icon(Icons.filter_alt_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasFilter) ...[
              const Divider(height: 28),
              Text(
                '${contacts.length + organizations.length} results',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (contacts.isEmpty && organizations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No matching contacts or organizations.'),
                )
              else ...[
                for (final contact in contacts)
                  _contactResult(context, contact),
                for (final organization in organizations)
                  _organizationResult(context, organization),
              ],
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Enter a search or choose filters to see matching records.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterDrawer(
    BuildContext context,
    double width,
    List<Contact> contacts,
    List<Organization> organizations,
    List<ProfileTagDefinition> tags,
    List<String> locations,
    List<String> ranks,
  ) => Drawer(
    width: width,
    child: SafeArea(
      child: Builder(
        builder: (drawerContext) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Filter records',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () =>
                        Scaffold.of(drawerContext).closeEndDrawer(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SegmentedButton<_SearchScope>(
                      segments: const [
                        ButtonSegment(
                          value: _SearchScope.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: _SearchScope.contacts,
                          label: Text('Contacts'),
                        ),
                        ButtonSegment(
                          value: _SearchScope.organizations,
                          label: Text('Organizations'),
                        ),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (selection) =>
                          setState(() => _scope = selection.first),
                    ),
                  ),
                  _selectionGroup<int>(
                    title: 'Contact names',
                    selected: _selectedContactIds,
                    choices: [
                      for (final contact in contacts)
                        _FilterChoice(contact.id!, contact.fullName),
                    ],
                    onToggle: (id, selected) => selected
                        ? _selectedContactIds.add(id)
                        : _selectedContactIds.remove(id),
                  ),
                  _selectionGroup<int>(
                    title: 'Organization names',
                    selected: _selectedOrganizationIds,
                    choices: [
                      for (final organization in organizations)
                        _FilterChoice(organization.id!, organization.name),
                    ],
                    onToggle: (id, selected) => selected
                        ? _selectedOrganizationIds.add(id)
                        : _selectedOrganizationIds.remove(id),
                  ),
                  _selectionGroup<int>(
                    title: 'Tags',
                    selected: _selectedTagIds,
                    choices: [
                      for (final tag in tags)
                        _FilterChoice(
                          tag.id!,
                          '${tag.label} · ${_tagCategoryLabel(tag.category)}',
                        ),
                    ],
                    onToggle: (id, selected) => selected
                        ? _selectedTagIds.add(id)
                        : _selectedTagIds.remove(id),
                  ),
                  _selectionGroup<String>(
                    title: 'Locations',
                    selected: _selectedLocations,
                    choices: [
                      for (final location in locations)
                        _FilterChoice(location, location),
                    ],
                    onToggle: (location, selected) => selected
                        ? _selectedLocations.add(location)
                        : _selectedLocations.remove(location),
                  ),
                  _selectionGroup<String>(
                    title: 'Military ranks',
                    selected: _selectedRanks,
                    choices: [
                      for (final rank in ranks) _FilterChoice(rank, rank),
                    ],
                    onToggle: (rank, selected) => selected
                        ? _selectedRanks.add(rank)
                        : _selectedRanks.remove(rank),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _activeFilterCount == 0 ? null : _clearFilters,
                    child: const Text('Clear all'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () =>
                        Scaffold.of(drawerContext).closeEndDrawer(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _selectionGroup<T>({
    required String title,
    required Set<T> selected,
    required List<_FilterChoice<T>> choices,
    required void Function(T value, bool isSelected) onToggle,
  }) => ExpansionTile(
    title: Text(title),
    subtitle: selected.isEmpty ? null : Text('${selected.length} selected'),
    children: [
      if (choices.isEmpty)
        const ListTile(title: Text('No options available'))
      else
        SizedBox(
          height: math.min(choices.length * 52.0, 260.0),
          child: ListView.builder(
            itemCount: choices.length,
            itemBuilder: (context, index) {
              final choice = choices[index];
              return CheckboxListTile(
                dense: true,
                value: selected.contains(choice.value),
                title: Text(
                  choice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) =>
                    setState(() => onToggle(choice.value, value ?? false)),
              );
            },
          ),
        ),
    ],
  );

  Widget _contactResult(BuildContext context, Contact contact) {
    final tags = _tagsFor(contact);
    final subtitle = [
      if (contact.militaryRank.trim().isNotEmpty) contact.militaryRank.trim(),
      if (contact.militaryBranch.trim().isNotEmpty)
        contact.militaryBranch.trim(),
      if (contact.address.trim().isNotEmpty) contact.address.trim(),
      ...tags,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(contact.fullName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2),
      trailing: StatusBadge(contact.status),
      onTap: () => widget.onOpenContact(contact),
    );
  }

  Widget _organizationResult(BuildContext context, Organization organization) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
        title: Text(organization.name),
        subtitle:
            [
              organization.industry,
              organization.address,
            ].where((text) => text.trim().isNotEmpty).join(' · ').isEmpty
            ? null
            : Text(
                [
                  organization.industry,
                  organization.address,
                ].where((text) => text.trim().isNotEmpty).join(' · '),
                maxLines: 2,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onOpenOrganization(organization),
      );

  Widget _analyticsSection(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final start30Days = today.subtract(const Duration(days: 29));
    final recentInteractions = widget.store.interactions.where((interaction) {
      final date = interaction.date.toLocal();
      return !date.isBefore(start30Days) && !date.isAfter(now);
    }).toList();
    final activeContacts = widget.store.contacts
        .where(
          (contact) =>
              !contact.isArchived && contact.status == ContactStatus.active,
        )
        .toList();
    final recentlyContactedIds = recentInteractions
        .map((interaction) => interaction.contactId)
        .toSet();
    final contactsNeedingAttention = activeContacts
        .where((contact) => !recentlyContactedIds.contains(contact.id))
        .length;

    var openFollowUps = 0;
    var overdueFollowUps = 0;
    for (final interaction in widget.store.interactions) {
      final dueDate = interaction.followUpDate?.toLocal();
      if (dueDate == null || interaction.followUpCompleted) continue;
      final contact = widget.store.contact(interaction.contactId);
      if (contact == null ||
          contact.isArchived ||
          contact.status != ContactStatus.active) {
        continue;
      }
      openFollowUps++;
      if (DateUtils.dateOnly(dueDate).isBefore(today)) overdueFollowUps++;
    }

    final metrics = [
      _ReportMetric(
        'Interactions · 30 days',
        recentInteractions.length.toString(),
        Icons.forum_outlined,
      ),
      _ReportMetric(
        'Average per day',
        (recentInteractions.length / 30).toStringAsFixed(1),
        Icons.show_chart,
      ),
      _ReportMetric(
        'Open follow-ups',
        openFollowUps.toString(),
        Icons.event_note_outlined,
      ),
      _ReportMetric(
        'Overdue follow-ups',
        overdueFollowUps.toString(),
        Icons.notification_important_outlined,
      ),
      _ReportMetric(
        'Active contacts untouched · 30 days',
        contactsNeedingAttention.toString(),
        Icons.person_search_outlined,
      ),
      _ReportMetric(
        'Active contacts',
        activeContacts.length.toString(),
        Icons.people_outline,
      ),
      _ReportMetric(
        'Organizations',
        widget.store.organizations
            .where((organization) => !organization.isArchived)
            .length
            .toString(),
        Icons.business_outlined,
      ),
    ];

    final dailyCounts = <DateTime, int>{};
    for (final interaction in widget.store.interactions) {
      final date = DateUtils.dateOnly(interaction.date.toLocal());
      if (!date.isBefore(today.subtract(const Duration(days: 13))) &&
          !date.isAfter(today)) {
        dailyCounts.update(date, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final days = List.generate(
      14,
      (index) => today.subtract(Duration(days: 13 - index)),
    );
    final maxDailyCount = days
        .map((day) => dailyCounts[day] ?? 0)
        .fold<int>(0, (largest, count) => count > largest ? count : largest);

    final typeCounts = {
      for (final type in InteractionLog.types)
        type: recentInteractions
            .where((interaction) => interaction.type == type)
            .length,
    };
    final maxTypeCount = typeCounts.values.fold<int>(
      0,
      (largest, count) => count > largest ? count : largest,
    );

    final contactCounts = <int, int>{};
    for (final interaction in recentInteractions) {
      contactCounts.update(
        interaction.contactId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final mostContacted = contactCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CRM analytics', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Interaction activity, follow-up workload, and contact coverage.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _MetricGrid(metrics: metrics),
            const Divider(height: 36),
            Text(
              'Interactions per day · last 14 days',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (maxDailyCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No interactions recorded yet.')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in days)
                      _DailyBar(
                        date: day,
                        count: dailyCounts[day] ?? 0,
                        maxCount: maxDailyCount,
                      ),
                  ],
                ),
              ),
            const Divider(height: 36),
            Text(
              'Interaction types · last 30 days',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final entry in typeCounts.entries)
              _InteractionTypeRow(
                type: entry.key,
                count: entry.value,
                maxCount: maxTypeCount,
              ),
            const Divider(height: 36),
            Text(
              'Most contacted · last 30 days',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (mostContacted.isEmpty)
              const Text('No recent interactions to rank yet.')
            else
              for (final entry in mostContacted.take(5))
                if (widget.store.contact(entry.key) case final contact?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(contact.fullName),
                    subtitle: Text('${entry.value} interactions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenContact(contact),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FilterChoice<T> {
  const _FilterChoice(this.value, this.label);

  final T value;
  final String label;
}

class _ReportMetric {
  const _ReportMetric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_ReportMetric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 650
          ? 2
          : 1;
      const spacing = 12.0;
      const cardHeight = 132.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              height: cardHeight,
              child: _MetricCard(metric: metric),
            ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(metric.icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBar extends StatelessWidget {
  const _DailyBar({
    required this.date,
    required this.count,
    required this.maxCount,
  });

  final DateTime date;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final height = count == 0 ? 2.0 : 84 * count / maxCount;
    return SizedBox(
      width: 48,
      height: 132,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$count', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          SizedBox(
            height: 88,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 22,
                height: height,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${date.month}/${date.day}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _InteractionTypeRow extends StatelessWidget {
  const _InteractionTypeRow({
    required this.type,
    required this.count,
    required this.maxCount,
  });

  final String type;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 84, child: Text(type)),
        Expanded(
          child: LinearProgressIndicator(
            value: maxCount == 0 ? 0 : count / maxCount,
            minHeight: 9,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.end)),
      ],
    ),
  );
}
