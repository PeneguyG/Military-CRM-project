import 'package:flutter/material.dart';
import '../crm_store.dart';
import '../models/crm_models.dart';
import 'crm_widgets.dart';
import 'record_browser.dart';

Future<void> editContact(BuildContext context, CrmStore store,
    [Contact? contact]) async {
  final original = contact ?? const Contact(firstName: '', lastName: '');
  final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => RecordForm(
              title: contact == null ? 'Add contact' : 'Edit contact',
              values: original.toMap(),
              organizations: store.organizations,
              organizationId: original.organizationId,
              contactStatus: original.status,
              fields: const {
                'first_name': 'First name *',
                'last_name': 'Last name *',
                'title': 'Military rank / Title',
                'phone': 'Phone',
                'email': 'Email',
                'address': 'Address / Location',
                'spouse_name': 'Spouse name (optional)',
                'children_info': 'Children information (optional)',
                'photo_path': 'Local photo path (optional)',
                'talking_points': 'Talking Points',
                'notes': 'Notes'
              }));
  if (result != null) store.saveContact(Contact.fromMap(result));
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.store, this.initialContactId});
  final CrmStore store;
  final int? initialContactId;
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String _search = '';
  late bool _archived =
      widget.store.contact(widget.initialContactId)?.isArchived ?? false;
  ContactStatus? _status;
  late int? _selected = widget.initialContactId;
  @override
  void initState() {
    super.initState();
    if (_selected != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.size != null && context.size!.width < 850) {
          openDetail(
              context,
              ContactDetail(store: widget.store, id: _selected!),
              'Contact dossier');
        }
      });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
            final items = widget.store.contacts
                .where((c) =>
                    c.isArchived == _archived &&
                    (_status == null || c.status == _status) &&
                    [
                      c.fullName,
                      c.title,
                      c.address,
                      c.notes,
                      c.talkingPoints,
                      widget.store.organization(c.organizationId)?.name ?? ''
                    ].join(' ').toLowerCase().contains(_search))
                .toList()
              ..sort((a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
            final selected = items.where((c) => c.id == _selected).firstOrNull;
            return RecordBrowser(
                onAdd: () => editContact(context, widget.store),
                filters: Column(children: [
                  TextField(
                      decoration: const InputDecoration(
                          labelText: 'Search contacts',
                          hintText:
                              'Name, rank, organization, location or notes',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (v) =>
                          setState(() => _search = v.trim().toLowerCase())),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _status?.name ?? 'all',
                            decoration: const InputDecoration(
                                labelText: 'Contact status'),
                            items: [
                              const DropdownMenuItem(
                                  value: 'all', child: Text('All')),
                              for (final s in ContactStatus.values)
                                DropdownMenuItem(
                                    value: s.name, child: Text(label(s.name)))
                            ],
                            onChanged: (v) => setState(() => _status =
                                v == 'all'
                                    ? null
                                    : ContactStatus.values.byName(v!)))),
                    FilterChip(
                        label: Text(
                            _archived ? 'Archived records' : 'Active records'),
                        selected: _archived,
                        onSelected: (v) => setState(() {
                              _archived = v;
                              _selected = null;
                            }))
                  ])
                ]),
                list: items.isEmpty
                    ? const Center(child: Text('No matching contacts'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final c = items[index];
                          return ListTile(
                              selected: c.id == _selected,
                              leading: ContactPhoto(c, size: 40),
                              title: Text(c.fullName),
                              subtitle:
                                  Text('${c.title}\n${label(c.status.name)}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                setState(() => _selected = c.id);
                                if (constraints.maxWidth < 850)
                                  openDetail(
                                      context,
                                      ContactDetail(
                                          store: widget.store, id: c.id!),
                                      c.fullName);
                              });
                        }),
                detail: selected == null
                    ? const Center(child: Text('Select a contact'))
                    : ContactDetail(store: widget.store, id: selected.id!));
          }));
}

class ContactDetail extends StatelessWidget {
  const ContactDetail({super.key, required this.store, required this.id});
  final CrmStore store;
  final int id;
  Future<void> _log(BuildContext context, Contact c,
      [String type = 'Call']) async {
    final result = await showDialog<Map<String, Object?>>(
        context: context, builder: (_) => InteractionForm(initialType: type));
    if (result != null)
      store.logInteraction(InteractionLog(
          contactId: id,
          organizationId: c.organizationId,
          date: DateTime.now(),
          type: result['type'] as String,
          summary: result['summary'] as String,
          followUpDate: result['followUp'] as DateTime?));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final c = store.contact(id);
        if (c == null) return const Center(child: Text('Contact unavailable'));
        final organization = store.organization(c.organizationId);
        final logs = store.interactions.where((i) => i.contactId == id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final localizations = MaterialLocalizations.of(context);
        return ListView(padding: const EdgeInsets.all(20), children: [
          Align(
              alignment: Alignment.centerLeft,
              child: ContactPhoto(c, size: 96)),
          const SizedBox(height: 12),
          Text(c.title, style: Theme.of(context).textTheme.titleMedium),
          Text(c.fullName, style: Theme.of(context).textTheme.headlineMedium),
          Text(organization == null
              ? 'No organization'
              : '${organization.name}${organization.isArchived ? ' (Archived)' : ''}'),
          Wrap(spacing: 8, children: [
            StatusBadge(c.status),
            if (c.isArchived) const Chip(label: Text('Archived'))
          ]),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: () => editContact(context, store, c),
                icon: const Icon(Icons.edit),
                label: const Text('Edit')),
            OutlinedButton.icon(
                onPressed: () =>
                    store.saveContact(c.copyWith(isArchived: !c.isArchived)),
                icon: Icon(
                    c.isArchived ? Icons.unarchive : Icons.archive_outlined),
                label: Text(c.isArchived ? 'Restore' : 'Archive'))
          ]),
          InfoCard('Address / Location', c.address),
          if (c.phone.isNotEmpty)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone),
                title: Text(c.phone),
                subtitle: const Text('Call or text'),
                onTap: () async {
                  final type = await phoneAction(context, c.phone);
                  if (type != null && context.mounted)
                    await _log(context, c, type);
                }),
          InfoCard('Email', c.email),
          if (c.spouseName.isNotEmpty) InfoCard('Spouse', c.spouseName),
          if (c.childrenInfo.isNotEmpty) InfoCard('Children', c.childrenInfo),
          InfoCard('Talking Points', c.talkingPoints),
          InfoCard('Notes', c.notes),
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                  onPressed: () => _log(context, c),
                  icon: const Icon(Icons.note_add),
                  label: const Text('Log Interaction / Follow-Up'))),
          const SizedBox(height: 20),
          Text('Interaction history · newest first',
              style: Theme.of(context).textTheme.titleLarge),
          if (logs.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No interactions recorded')),
          for (final log in logs)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${log.type} · ${localizations.formatMediumDate(log.date.toLocal())} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(log.date.toLocal()))}',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          SelectableText(log.summary),
                          if (log.followUpDate != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    'Follow-up: ${localizations.formatMediumDate(log.followUpDate!.toLocal())}')),
                        ]))),
        ]);
      });
}
