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
  final _searchController = TextEditingController();
  _SearchScope _scope = _SearchScope.all;

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

  String _contactSearchText(Contact contact, List<String> tags) {
    final organization = widget.store.organization(contact.organizationId);
    return [
      contact.fullName,
      contact.title,
      contact.militaryRank,
      contact.militaryBranch,
      contact.address,
      contact.latitude?.toString() ?? '',
      contact.longitude?.toString() ?? '',
      organization?.name ?? '',
      organization?.address ?? '',
      ...tags,
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final query = _searchController.text.trim();
      final contacts =
          _scope == _SearchScope.organizations
                ? <Contact>[]
                : widget.store.contacts.where((contact) {
                    if (contact.isArchived) return false;
                    final tags = _tagsFor(contact);
                    return query.isEmpty ||
                        _matches(query, _contactSearchText(contact, tags));
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
                    final text = [
                      organization.name,
                      organization.industry,
                      organization.address,
                      organization.latitude?.toString() ?? '',
                      organization.longitude?.toString() ?? '',
                    ].join(' ');
                    return query.isEmpty || _matches(query, text);
                  }).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchSection(context, query, contacts, organizations),
                const SizedBox(height: 24),
                _analyticsSection(context),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _searchSection(
    BuildContext context,
    String query,
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
              'Search contact names, tags, locations, military ranks, and organization details.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search records',
                hintText: 'Name, tag, city, address, or military rank',
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
            const SizedBox(height: 12),
            SegmentedButton<_SearchScope>(
              segments: const [
                ButtonSegment(value: _SearchScope.all, label: Text('All')),
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
            if (query.isNotEmpty) ...[
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
                'Enter one or more terms to filter contacts and organizations.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

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
    return Column(
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
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const Divider(height: 28),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
        ),
      ],
    );
  }
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
