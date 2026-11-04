import 'package:flutter/material.dart';
import '../crm_store.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';
import 'crm_widgets.dart';
import 'record_browser.dart';

Future<void> editOrganization(
  BuildContext context,
  CrmStore store, [
  Organization? organization,
]) async {
  final original = organization ?? const Organization(name: '');
  await showDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecordForm(
      title: organization == null ? 'Add organization' : 'Edit organization',
      values: original.toMap(),
      onSave: (values) => store.saveOrganization(Organization.fromMap(values)),
      organizationForm: true,
      fields: const {
        'logo_blob': 'Organization logo',
        'name': 'Organization name *',
        'industry': 'Industry *',
        'address': 'Address / Location',
        'phone': 'Phone',
        'email': 'Email address *',
        'notes': 'Notes (optional)',
      },
    ),
  );
}

class OrganizationsPage extends StatefulWidget {
  const OrganizationsPage({
    super.key,
    required this.store,
    required this.onSelectContact,
  });
  final CrmStore store;
  final ValueChanged<Contact> onSelectContact;
  @override
  State<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  String _search = '';
  int? _selected;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final items =
            widget.store.organizations
                .where(
                  (o) =>
                      !o.isArchived &&
                      [
                        o.name,
                        o.industry,
                        o.address,
                        o.notes,
                      ].join(' ').toLowerCase().contains(_search),
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        final selected = items.where((o) => o.id == _selected).firstOrNull;
        return RecordBrowser(
          onAdd: () => editOrganization(context, widget.store),
          filters: TextField(
            decoration: const InputDecoration(
              labelText: 'Search organizations',
              hintText: 'Name, industry, location or notes',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
          list: items.isEmpty
              ? const Center(child: Text('No matching organizations'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final o = items[index];
                    return ListTile(
                      selected: o.id == _selected,
                      leading: OrganizationLogo(o, size: 40),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RecordStatusIndicator(isActive: !o.isArchived),
                        ],
                      ),
                      subtitle: Text(
                        [
                          o.industry,
                          o.address,
                        ].where((s) => s.isNotEmpty).join('\n'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        setState(() => _selected = o.id);
                        if (constraints.maxWidth < 850)
                          openDetail(
                            context,
                            OrganizationDetail(
                              store: widget.store,
                              id: o.id!,
                              onSelectContact: (c) {
                                Navigator.of(context).pop();
                                widget.onSelectContact(c);
                              },
                            ),
                            o.name,
                          );
                      },
                    );
                  },
                ),
          detail: selected == null
              ? const Center(child: Text('Select an organization'))
              : OrganizationDetail(
                  store: widget.store,
                  id: selected.id!,
                  onSelectContact: widget.onSelectContact,
                ),
        );
      },
    ),
  );
}

class OrganizationDetail extends StatelessWidget {
  const OrganizationDetail({
    super.key,
    required this.store,
    required this.id,
    required this.onSelectContact,
  });
  final CrmStore store;
  final int id;
  final ValueChanged<Contact> onSelectContact;

  Future<void> _addNote(BuildContext context, Organization organization) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _AddOrganizationNoteDialog(),
    );
    if (text == null || !context.mounted) return;
    await runDatabaseAction(
      context,
      () => store.addOrganizationNote(
        OrganizationNote(
          organizationId: organization.id!,
          text: capitalizeInitial(text),
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final o = store.organization(id);
      if (o == null)
        return const Center(child: Text('Organization unavailable'));
      if (o.isArchived) {
        return const Center(
          child: Text(
            'This organization is archived. Open the Archive tab to view it.',
          ),
        );
      }
      final contacts =
          store.contacts
              .where((c) => c.organizationId == id && !c.isArchived)
              .toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
      final organizationActions = Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => editOrganization(context, store, o),
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          OutlinedButton.icon(
            onPressed: () => runDatabaseAction(
              context,
              () => store.archiveOrganization(o.id!, true),
            ),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        ],
      );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    OrganizationLogo(o, size: 64),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        o.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RecordStatusIndicator(isActive: !o.isArchived),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final industry = Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(o.industry)),
                ],
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    industry,
                    Align(
                      alignment: Alignment.centerRight,
                      child: organizationActions,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: industry),
                  const SizedBox(width: 12),
                  organizationActions,
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (o.phone.isNotEmpty)
            InfoCard(
              'Phone',
              formatPhoneForDisplay(o.phone),
              icon: Icons.phone_outlined,
              trailing: OutlinedButton.icon(
                onPressed: () => phoneAction(context, o.phone),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Call or text'),
              ),
            ),
          InfoCard(
            'Address / Location',
            o.address,
            icon: Icons.location_on_outlined,
          ),
          InfoCard('Email', o.email, icon: Icons.email_outlined),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _addNote(context, o),
              icon: const Icon(Icons.add),
              label: const Text('Add note'),
            ),
          ),
          const SizedBox(height: 8),
          _OrganizationNotesCard(
            legacyNotes: o.notes,
            notes: store.notesForOrganization(id),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Associated Contacts (${contacts.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No associated contacts'),
            ),
          for (final c in contacts)
            Card(
              child: ListTile(
                leading: ContactPhoto(c, size: 40),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RecordStatusIndicator(
                      isActive: c.status == ContactStatus.active,
                      contactStatus: c.status,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.militaryRank.isNotEmpty ||
                        c.militaryBranch.isNotEmpty)
                      Text(
                        [
                          if (c.militaryRank.isNotEmpty) c.militaryRank,
                          if (c.militaryBranch.isNotEmpty) c.militaryBranch,
                        ].join(' · '),
                      ),
                    if (c.title.isNotEmpty) Text(c.title),
                  ],
                ),
                onTap: () => onSelectContact(c),
              ),
            ),
        ],
      );
    },
  );
}

class _OrganizationNotesCard extends StatelessWidget {
  const _OrganizationNotesCard({
    required this.legacyNotes,
    required this.notes,
  });

  final String legacyNotes;
  final List<OrganizationNote> notes;

  @override
  Widget build(BuildContext context) {
    final hasLegacyNotes = legacyNotes.trim().isNotEmpty;
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasLegacyNotes && notes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No notes yet.'),
              ),
            if (hasLegacyNotes) ...[
              SelectableText(legacyNotes.trim()),
              if (notes.isNotEmpty) const Divider(height: 24),
            ],
            for (var index = 0; index < notes.length; index++) ...[
              if (index > 0) const Divider(height: 24),
              SelectableText(notes[index].text),
              const SizedBox(height: 4),
              Text(
                '${localizations.formatMediumDate(notes[index].createdAt.toLocal())} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(notes[index].createdAt.toLocal()))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddOrganizationNoteDialog extends StatefulWidget {
  const _AddOrganizationNoteDialog();

  @override
  State<_AddOrganizationNoteDialog> createState() =>
      _AddOrganizationNoteDialogState();
}

class _AddOrganizationNoteDialogState
    extends State<_AddOrganizationNoteDialog> {
  final _key = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add organization note'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _key,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'Add a note to this organization’s profile',
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a note' : null,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(context, capitalizeInitial(_controller.text));
        },
        child: const Text('Add note'),
      ),
    ],
  );
}
