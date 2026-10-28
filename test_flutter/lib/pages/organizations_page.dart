import 'package:flutter/material.dart';
import '../crm_store.dart';
import '../models/crm_models.dart';
import 'crm_widgets.dart';
import 'record_browser.dart';

Future<void> editOrganization(BuildContext context, CrmStore store,
    [Organization? organization]) async {
  final original = organization ?? const Organization(name: '');
  final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => RecordForm(
              title: organization == null
                  ? 'Add organization'
                  : 'Edit organization',
              values: original.toMap(),
              organizationForm: true,
              fields: const {
                'name': 'Organization name *',
                'industry': 'Industry',
                'address': 'Address / Location',
                'phone': 'Phone',
                'email': 'Email',
                'notes': 'Notes'
              }));
  if (result != null) store.saveOrganization(Organization.fromMap(result));
}

class OrganizationsPage extends StatefulWidget {
  const OrganizationsPage(
      {super.key, required this.store, required this.onSelectContact});
  final CrmStore store;
  final ValueChanged<Contact> onSelectContact;
  @override
  State<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  String _search = '';
  bool _archived = false;
  int? _selected;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
            final items = widget.store.organizations
                .where((o) =>
                    o.isArchived == _archived &&
                    [o.name, o.industry, o.address, o.notes]
                        .join(' ')
                        .toLowerCase()
                        .contains(_search))
                .toList()
              ..sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            final selected = items.where((o) => o.id == _selected).firstOrNull;
            return RecordBrowser(
                onAdd: () => editOrganization(context, widget.store),
                filters: Column(children: [
                  TextField(
                      decoration: const InputDecoration(
                          labelText: 'Search organizations',
                          hintText: 'Name, industry, location or notes',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (v) =>
                          setState(() => _search = v.trim().toLowerCase())),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_archived
                          ? 'Archived organizations'
                          : 'Active organizations'),
                      value: _archived,
                      onChanged: (v) => setState(() {
                            _archived = v;
                            _selected = null;
                          }))
                ]),
                list: items.isEmpty
                    ? const Center(child: Text('No matching organizations'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final o = items[index];
                          return ListTile(
                              selected: o.id == _selected,
                              title: Text(o.name),
                              subtitle: Text([o.industry, o.address]
                                  .where((s) => s.isNotEmpty)
                                  .join('\n')),
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
                                          }),
                                      o.name);
                              });
                        }),
                detail: selected == null
                    ? const Center(child: Text('Select an organization'))
                    : OrganizationDetail(
                        store: widget.store,
                        id: selected.id!,
                        onSelectContact: widget.onSelectContact));
          }));
}

class OrganizationDetail extends StatelessWidget {
  const OrganizationDetail(
      {super.key,
      required this.store,
      required this.id,
      required this.onSelectContact});
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
        final contacts = store.contacts
            .where((c) => c.organizationId == id)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(o.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(o.industry),
          if (o.isArchived)
            const Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('Archived'))),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: () => editOrganization(context, store, o),
                icon: const Icon(Icons.edit),
                label: const Text('Edit')),
            OutlinedButton.icon(
                onPressed: () => store
                    .saveOrganization(o.copyWith(isArchived: !o.isArchived)),
                icon: Icon(
                    o.isArchived ? Icons.unarchive : Icons.archive_outlined),
                label: Text(o.isArchived ? 'Restore' : 'Archive'))
          ]),
          InfoCard('Address / Location', o.address),
          if (o.phone.isNotEmpty)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone),
                title: Text(o.phone),
                subtitle: const Text('Call or text'),
                onTap: () => phoneAction(context, o.phone)),
          InfoCard('Email', o.email),
          InfoCard('Notes', o.notes),
          const SizedBox(height: 16),
          Text('Associated Contacts (${contacts.length})',
              style: Theme.of(context).textTheme.titleLarge),
          if (contacts.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No associated contacts')),
          for (final c in contacts)
            Card(
                child: ListTile(
                    leading: ContactPhoto(c, size: 40),
                    title: Text('${c.title} ${c.fullName}'.trim()),
                    subtitle: Wrap(spacing: 8, children: [
                      StatusBadge(c.status),
                      if (c.isArchived) const Chip(label: Text('Archived'))
                    ]),
                    onTap: () => onSelectContact(c))),
        ]);
      });
}
