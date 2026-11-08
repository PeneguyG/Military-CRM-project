import 'package:flutter/material.dart';

import '../crm_store.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';
import 'crm_widgets.dart';

/// Dashboard shown on the Home tab, with CRM statistics and today's call list.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.onOpenContact});

  final CrmStore store;
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
              _ToCallTodayCard(store: store, onOpenContact: onOpenContact),
              const SizedBox(height: 16),
              _FutureCallsCard(store: store, onOpenContact: onOpenContact),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows non-archived contacts with a follow-up due today.
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
      final dueReasonsByContact = <int, Set<String>>{};
      for (final interaction in store.interactions) {
        final dueDate = interaction.followUpDate?.toLocal();
        if (interaction.followUpCompleted ||
            dueDate == null ||
            !_isSameDay(dueDate, today)) {
          continue;
        }
        final reason = interaction.followUpReason.trim();
        final time = formatFollowUpTime(context, interaction.followUpTime);
        dueReasonsByContact
            .putIfAbsent(interaction.contactId, () => <String>{})
            .add('$time · ${reason.isEmpty ? 'Reason not specified' : reason}');
      }
      final dueContactIds = dueReasonsByContact.keys.toSet();

      // A contact appears once even if multiple interaction logs have a
      // follow-up due today. Archived contacts are excluded from Home.
      final dueContacts =
          store.contacts
              .where(
                (contact) =>
                    dueContactIds.contains(contact.id) &&
                    contact.status == ContactStatus.active &&
                    !contact.isArchived,
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
                    subtitle: Text(
                      _contactDetails(
                        contact,
                        dueReasonsByContact[contact.id] ?? const {},
                      ),
                    ),
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
  String _contactDetails(Contact contact, Set<String> followUpReasons) {
    final organization = store.organization(contact.organizationId)?.name;
    return [
      if (contact.militaryRank.trim().isNotEmpty) contact.militaryRank.trim(),
      if (contact.militaryBranch.trim().isNotEmpty)
        contact.militaryBranch.trim(),
      if (contact.title.trim().isNotEmpty) contact.title.trim(),
      if (organization != null && organization.trim().isNotEmpty)
        organization.trim(),
      contact.phone.trim().isNotEmpty
          ? formatPhoneForDisplay(contact.phone)
          : 'No phone recorded',
      if (followUpReasons.isNotEmpty)
        'Follow-up: ${followUpReasons.join('; ')}',
    ].join(' · ');
  }
}

/// One scheduled future interaction paired with its current contact record.
class _ScheduledFollowUp {
  const _ScheduledFollowUp({
    required this.contact,
    required this.interaction,
    required this.date,
  });

  final Contact contact;
  final InteractionLog interaction;
  final DateTime date;
}

/// Shows each incomplete follow-up scheduled after today, with its due date.
class _FutureCallsCard extends StatelessWidget {
  const _FutureCallsCard({required this.store, required this.onOpenContact});

  final CrmStore store;
  final ValueChanged<Contact> onOpenContact;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final today = DateUtils.dateOnly(DateTime.now());
      final futureCalls = <_ScheduledFollowUp>[];

      // Each interaction is a separate scheduled call, so a contact can
      // appear more than once when they have multiple future follow-ups.
      for (final interaction in store.interactions) {
        final followUpDate = interaction.followUpDate?.toLocal();
        if (interaction.followUpCompleted || followUpDate == null) continue;

        final date = DateUtils.dateOnly(followUpDate);
        if (!date.isAfter(today)) continue;

        final contact = store.contact(interaction.contactId);
        if (contact == null ||
            contact.status != ContactStatus.active ||
            contact.isArchived) {
          continue;
        }
        futureCalls.add(
          _ScheduledFollowUp(
            contact: contact,
            interaction: interaction,
            date: date,
          ),
        );
      }
      futureCalls.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return (a.interaction.followUpTime ?? '').compareTo(
          b.interaction.followUpTime ?? '',
        );
      });

      final colors = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      final localizations = MaterialLocalizations.of(context);

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Future Calls', style: textTheme.titleLarge),
                  ),
                  Chip(label: Text('${futureCalls.length}')),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Scheduled follow-ups for your active contacts.',
                style: textTheme.bodyMedium,
              ),
              const Divider(height: 24),
              if (futureCalls.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_outlined),
                      SizedBox(width: 12),
                      Expanded(child: Text('No future follow-ups scheduled.')),
                    ],
                  ),
                )
              else
                for (final followUp in futureCalls)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ContactPhoto(followUp.contact, size: 44),
                    title: Text(followUp.contact.fullName),
                    subtitle: Text(
                      [
                        followUp.contact.phone.trim().isNotEmpty
                            ? formatPhoneForDisplay(followUp.contact.phone)
                            : 'No phone recorded',
                        'Follow-up: ${followUp.interaction.followUpReason.trim().isEmpty ? 'Reason not specified' : followUp.interaction.followUpReason.trim()}',
                      ].join(' · '),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(localizations.formatMediumDate(followUp.date)),
                        Text(
                          formatFollowUpTime(
                            context,
                            followUp.interaction.followUpTime,
                          ),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    onTap: () => onOpenContact(followUp.contact),
                  ),
            ],
          ),
        ),
      );
    },
  );
}

/// Returns whether two local dates have the same calendar day.
bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
