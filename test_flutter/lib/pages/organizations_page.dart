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
        'name': 'Organization name *',
        'industry': 'Industry',
        'address': 'Address / Location',
        'phone': 'Phone',
        'email': 'Email',
        'notes': 'Notes',
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
                      title: Text(o.name),
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
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(o.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(o.industry),
          Wrap(
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
          ),
          InfoCard('Address / Location', o.address),
          if (o.phone.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone),
              title: Text(formatPhoneForDisplay(o.phone)),
              subtitle: const Text('Call or text'),
              onTap: () => phoneAction(context, o.phone),
            ),
          InfoCard('Email', o.email),
          InfoCard('Notes', o.notes),
          const SizedBox(height: 16),
          Text(
            'Associated Contacts (${contacts.length})',
            style: Theme.of(context).textTheme.titleLarge,
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
                title: Text('${c.title} ${c.fullName}'.trim()),
                subtitle: Wrap(spacing: 8, children: [StatusBadge(c.status)]),
                onTap: () => onSelectContact(c),
              ),
            ),
        ],
      );
    },
  );
}
