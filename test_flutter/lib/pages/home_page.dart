import 'package:flutter/material.dart';

import '../crm_store.dart';
import '../models/crm_models.dart';
import 'crm_widgets.dart';

/// Holds the destination data needed to build a Home-page shortcut button.
class HomeShortcut {
  const HomeShortcut({
    required this.tabIndex,
    required this.label,
    required this.icon,
  });

  /// The index is shared with the parent navigation rail's destination list.
  final int tabIndex;
  final String label;
  final IconData icon;
}

/// Dashboard shown on the Home tab, with shortcuts and today's call list.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.shortcuts,
    required this.onSelectTab,
    required this.onOpenContact,
  });

  final CrmStore store;
  final List<HomeShortcut> shortcuts;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<Contact> onOpenContact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Scrolling keeps the dashboard usable when the desktop window is short.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back User!',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text('Quick access', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              // Every non-Home destination is supplied by the parent, so these
              // buttons use the same indices as the navigation rail.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final shortcut in shortcuts)
                    FilledButton.tonalIcon(
                      onPressed: () => onSelectTab(shortcut.tabIndex),
                      icon: Icon(shortcut.icon),
                      label: Text(shortcut.label),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              // This final dashboard section sits below the shortcuts and
              // updates whenever the shared CRM store changes.
              _ToCallTodayCard(store: store, onOpenContact: onOpenContact),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows non-archived, non-deceased contacts with a follow-up due today.
class _ToCallTodayCard extends StatelessWidget {
  const _ToCallTodayCard({required this.store, required this.onOpenContact});

  final CrmStore store;
  final ValueChanged<Contact> onOpenContact;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final today = DateTime.now();

      // Compare local calendar dates because follow-up dates are date-oriented
      // reminders and should not shift to a neighboring day by time zone.
      final dueContactIds = store.interactions
          .where((interaction) {
            final dueDate = interaction.followUpDate?.toLocal();
            return !interaction.followUpCompleted &&
                dueDate != null &&
                _isSameDay(dueDate, today);
          })
          .map((interaction) => interaction.contactId)
          .toSet();

      // A contact appears once even if multiple interaction logs have a
      // follow-up due today. Archived and deceased contacts are excluded.
      final dueContacts =
          store.contacts
              .where(
                (contact) =>
                    dueContactIds.contains(contact.id) &&
                    !contact.isArchived &&
                    contact.status != ContactStatus.deceased,
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );

      final colors = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_in_talk_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('To call today', style: textTheme.titleLarge),
                  ),
                  Chip(label: Text('${dueContacts.length}')),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Contacts with a follow-up scheduled for today.',
                style: textTheme.bodyMedium,
              ),
              const Divider(height: 24),
              if (dueContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('No contacts have follow-ups due today.'),
                      ),
                    ],
                  ),
                )
              else
                for (final contact in dueContacts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ContactPhoto(contact, size: 44),
                    title: Text(contact.fullName),
                    subtitle: Text(_contactDetails(contact)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpenContact(contact),
                  ),
            ],
          ),
        ),
      );
    },
  );

  /// Formats organization and phone information as a compact list subtitle.
  String _contactDetails(Contact contact) {
    final organization = store.organization(contact.organizationId)?.name;
    return [
      if (contact.title.trim().isNotEmpty) contact.title.trim(),
      if (organization != null && organization.trim().isNotEmpty)
        organization.trim(),
      contact.phone.trim().isNotEmpty
          ? contact.phone.trim()
          : 'No phone recorded',
    ].join(' · ');
  }
}

/// Returns whether two local dates have the same calendar day.
bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
