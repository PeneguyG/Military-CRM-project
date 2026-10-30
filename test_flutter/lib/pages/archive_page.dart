import 'package:flutter/material.dart';

import '../crm_store.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';
import 'contacts_page.dart' show editContact;
import 'crm_widgets.dart' show ContactPhoto, runDatabaseAction;
import 'organizations_page.dart' show editOrganization;

/// Lists archived contacts and organizations in one place and lets users
/// restore a record by changing its status back to Active.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final contacts =
          store.contacts.where((contact) => contact.isArchived).toList()..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );
      final organizations =
          store.organizations
              .where((organization) => organization.isArchived)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Archived accounts',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Archived records are kept here until you mark them Active again.',
          ),
          const SizedBox(height: 24),
          if (contacts.isEmpty && organizations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('There are no archived contacts or organizations.'),
              ),
            ),
          if (contacts.isNotEmpty) ...[
            _ArchiveSectionHeading(title: 'Contacts', count: contacts.length),
            const SizedBox(height: 8),
            for (final contact in contacts)
              _ArchivedContactCard(
                contact: contact,
                organizationName: store
                    .organization(contact.organizationId)
                    ?.name,
                onEdit: () => editContact(context, store, contact),
                onMarkActive: contact.id == null
                    ? null
                    : () => runDatabaseAction(
                        context,
                        () => store.archiveContact(contact.id!, false),
                      ),
              ),
            const SizedBox(height: 24),
          ],
          if (organizations.isNotEmpty) ...[
            _ArchiveSectionHeading(
              title: 'Organizations',
              count: organizations.length,
            ),
            const SizedBox(height: 8),
            for (final organization in organizations)
              _ArchivedOrganizationCard(
                organization: organization,
                onEdit: () => editOrganization(context, store, organization),
                onMarkActive: organization.id == null
                    ? null
                    : () => runDatabaseAction(
                        context,
                        () =>
                            store.archiveOrganization(organization.id!, false),
                      ),
              ),
          ],
        ],
      );
    },
  );
}

/// Provides a heading and count for one kind of archived account.
class _ArchiveSectionHeading extends StatelessWidget {
  const _ArchiveSectionHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Chip(label: Text('$count')),
    ],
  );
}

/// Contact card exposes the status editor and a one-click Active action.
class _ArchivedContactCard extends StatelessWidget {
  const _ArchivedContactCard({
    required this.contact,
    required this.organizationName,
    required this.onEdit,
    required this.onMarkActive,
  });

  final Contact contact;
  final String? organizationName;
  final VoidCallback onEdit;
  final VoidCallback? onMarkActive;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (contact.title.trim().isNotEmpty) contact.title.trim(),
      if (organizationName != null && organizationName!.trim().isNotEmpty)
        organizationName!.trim(),
      if (contact.phone.trim().isNotEmpty) formatPhoneForDisplay(contact.phone),
    ].join(' · ');

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: ContactPhoto(contact, size: 44),
            title: Text(contact.fullName),
            subtitle: Text(details.isEmpty ? 'Archived contact' : details),
            onTap: onEdit,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit status'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onMarkActive,
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Mark active'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Organization card exposes a manual action to return it to active records.
class _ArchivedOrganizationCard extends StatelessWidget {
  const _ArchivedOrganizationCard({
    required this.organization,
    required this.onEdit,
    required this.onMarkActive,
  });

  final Organization organization;
  final VoidCallback onEdit;
  final VoidCallback? onMarkActive;

  @override
  Widget build(BuildContext context) {
    final details = [
      organization.industry,
      organization.address,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
            title: Text(organization.name),
            subtitle: Text(details.isEmpty ? 'Archived organization' : details),
            onTap: onEdit,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit details'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onMarkActive,
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Mark active'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
