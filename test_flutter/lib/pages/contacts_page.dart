import 'package:flutter/material.dart';
import '../crm_store.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';
import 'crm_widgets.dart';
import 'record_browser.dart';

const _contactPrefixes = <String>[
  '',
  'Ms.',
  'Mr.',
  'Mrs.',
  'Mx.',
  'Dr.',
  'Prof.',
  'Rev.',
  'Pvt.',
  'PFC',
  'LCpl.',
  'Cpl.',
  'Sgt.',
  'SSgt.',
  'GySgt.',
  'MSgt.',
  '1st Sgt.',
  'Sgt. Maj.',
  'WO1',
  'CWO2',
  'CWO3',
  'CWO4',
  'CWO5',
  '2nd Lt.',
  '1st Lt.',
  'Capt.',
  'Maj.',
  'Lt. Col.',
  'Col.',
  'Brig. Gen.',
  'Maj. Gen.',
  'Lt. Gen.',
  'Gen.',
  'Ensign',
  'Lt. (j.g.)',
  'Lt.',
  'Lt. Cmdr.',
  'Cmdr.',
  'Chief Petty Officer',
  'Master Chief',
  'Rear Adm.',
  'Vice Adm.',
  'Adm.',
  'Fleet Adm.',
];

const _contactSuffixes = <String>[
  '',
  'Jr.',
  'Sr.',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'PhD',
  'MD',
  'DO',
  'JD',
  'Esq.',
  'DDS',
  'DVM',
  'Ret.',
];

const _militaryBranches = <String>[
  '',
  'Army',
  'Navy',
  'Air Force',
  'Marine Corps',
  'Space Force',
  'Coast Guard',
  'Army National Guard',
  'Air National Guard',
  'Other / Allied service',
];

const _militaryRanks = <String>[
  '',
  'Private',
  'Private Second Class',
  'Private First Class',
  'Specialist',
  'Lance Corporal',
  'Corporal',
  'Sergeant',
  'Staff Sergeant',
  'Sergeant First Class',
  'Technical Sergeant',
  'Gunnery Sergeant',
  'Master Sergeant',
  'Senior Master Sergeant',
  'First Sergeant',
  'Sergeant Major',
  'Command Sergeant Major',
  'Sergeant Major of the Army',
  'Sergeant Major of the Marine Corps',
  'Seaman Recruit',
  'Seaman Apprentice',
  'Seaman',
  'Petty Officer Third Class',
  'Petty Officer Second Class',
  'Petty Officer First Class',
  'Chief Petty Officer',
  'Senior Chief Petty Officer',
  'Master Chief Petty Officer',
  'Master Chief Petty Officer of the Navy',
  'Airman Basic',
  'Airman',
  'Airman First Class',
  'Senior Airman',
  'Chief Master Sergeant',
  'Chief Master Sergeant of the Air Force',
  'Warrant Officer 1',
  'Chief Warrant Officer 2',
  'Chief Warrant Officer 3',
  'Chief Warrant Officer 4',
  'Chief Warrant Officer 5',
  'Second Lieutenant',
  'First Lieutenant',
  'Captain',
  'Major',
  'Lieutenant Colonel',
  'Colonel',
  'Brigadier General',
  'Major General',
  'Lieutenant General',
  'General',
  'General of the Army',
  'Ensign',
  'Lieutenant Junior Grade',
  'Lieutenant',
  'Lieutenant Commander',
  'Commander',
  'Rear Admiral (Lower Half)',
  'Rear Admiral (Upper Half)',
  'Vice Admiral',
  'Admiral',
  'Fleet Admiral',
];

Future<void> editContact(
  BuildContext context,
  CrmStore store, [
  Contact? contact,
]) async {
  final original = contact ?? const Contact(firstName: '', lastName: '');
  await showDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecordForm(
      title: contact == null ? 'Add contact' : 'Edit contact',
      values: original.toMap(),
      onSave: (values) {
        // Status is the contact-facing control for archiving. Keep the legacy
        // storage flag in sync so archived contacts move into Archive.
        values['is_archived'] = values['status'] == ContactStatus.archived.name
            ? 1
            : 0;
        return store.saveContact(Contact.fromMap(values));
      },
      organizations: store.organizations,
      organizationId: original.organizationId,
      contactStatus: original.status,
      dropdownFields: const {
        'prefix': _contactPrefixes,
        'suffix': _contactSuffixes,
        'military_branch': _militaryBranches,
        'military_rank': _militaryRanks,
      },
      fields: const {
        'prefix': 'Prefix',
        'first_name': 'First name *',
        'last_name': 'Last name *',
        'suffix': 'Suffix',
        'military_branch': 'Military branch',
        'military_rank': 'Military rank',
        'title': 'Professional / civilian title',
        'phone': 'Phone',
        'email': 'Email',
        'address': 'Address / Location',
        'spouse_name': 'Spouse name (optional)',
        'children_json': 'Children',
        'photo_blob': 'Profile photo',
        'notes': 'Notes',
      },
    ),
  );
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
            'Contact dossier',
          );
        }
      });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final items =
            widget.store.contacts
                .where(
                  (c) =>
                      !c.isArchived &&
                      [
                        c.fullName,
                        c.title,
                        c.militaryBranch,
                        c.militaryRank,
                        c.address,
                        c.notes,
                        c.talkingPoints,
                        widget.store.organization(c.organizationId)?.name ?? '',
                      ].join(' ').toLowerCase().contains(_search),
                )
                .toList()
              ..sort(
                (a, b) => a.fullName.toLowerCase().compareTo(
                  b.fullName.toLowerCase(),
                ),
              );
        final selected = items.where((c) => c.id == _selected).firstOrNull;
        return RecordBrowser(
          onAdd: () => editContact(context, widget.store),
          filters: TextField(
            decoration: const InputDecoration(
              labelText: 'Search contacts',
              hintText: 'Name, branch, rank, organization, location or notes',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
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
                      subtitle: Text(
                        [
                          if (c.militaryRank.isNotEmpty) c.militaryRank,
                          if (c.militaryBranch.isNotEmpty) c.militaryBranch,
                          if (c.title.isNotEmpty) c.title,
                          label(c.status.name),
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        setState(() => _selected = c.id);
                        if (constraints.maxWidth < 850)
                          openDetail(
                            context,
                            ContactDetail(store: widget.store, id: c.id!),
                            c.fullName,
                          );
                      },
                    );
                  },
                ),
          detail: selected == null
              ? const Center(child: Text('Select a contact'))
              : ContactDetail(store: widget.store, id: selected.id!),
        );
      },
    ),
  );
}

class ContactDetail extends StatelessWidget {
  const ContactDetail({super.key, required this.store, required this.id});
  final CrmStore store;
  final int id;
  Future<void> _log(
    BuildContext context,
    Contact c, [
    String type = 'Call',
  ]) async {
    await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InteractionForm(
        initialType: type,
        onSave: (result) => store.logInteraction(
          InteractionLog(
            contactId: id,
            organizationId: c.organizationId,
            date: DateTime.now(),
            type: result['type'] as String,
            summary: result['summary'] as String,
            followUpDate: result['followUp'] as DateTime?,
            followUpReason: result['followUpReason'] as String? ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final c = store.contact(id);
      if (c == null) return const Center(child: Text('Contact unavailable'));
      if (c.isArchived) {
        return const Center(
          child: Text(
            'This contact is archived. Open the Archive tab to view it.',
          ),
        );
      }
      final organization = store.organization(c.organizationId);
      final logs = store.interactions.where((i) => i.contactId == id).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final localizations = MaterialLocalizations.of(context);
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ContactPhoto(c, size: 96),
          ),
          const SizedBox(height: 12),
          Text(c.fullName, style: Theme.of(context).textTheme.headlineMedium),
          if (c.militaryRank.isNotEmpty || c.militaryBranch.isNotEmpty)
            Text(
              [
                if (c.militaryRank.isNotEmpty) c.militaryRank,
                if (c.militaryBranch.isNotEmpty) c.militaryBranch,
              ].join(' · '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (c.title.isNotEmpty)
            Text(c.title, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            organization == null
                ? 'No organization'
                : organization.isArchived
                ? 'Archived organization (see Archive tab)'
                : organization.name,
          ),
          Wrap(spacing: 8, children: [StatusBadge(c.status)]),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => editContact(context, store, c),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () => runDatabaseAction(
                  context,
                  () => store.archiveContact(c.id!, true),
                ),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
            ],
          ),
          InfoCard('Address / Location', c.address),
          if (c.phone.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone),
              title: Text(formatPhoneForDisplay(c.phone)),
              subtitle: const Text('Call or text'),
              onTap: () async {
                final type = await phoneAction(context, c.phone);
                if (type != null && context.mounted)
                  await _log(context, c, type);
              },
            ),
          InfoCard('Email', c.email),
          if (c.spouseName.isNotEmpty) InfoCard('Spouse', c.spouseName),
          if (c.children.isNotEmpty)
            InfoCard(
              'Children',
              c.children
                  .map(
                    (child) =>
                        '${child.name}${child.age == null ? '' : ' · Age ${child.age}'}',
                  )
                  .join('\n'),
            )
          else if (c.childrenInfo.isNotEmpty)
            InfoCard('Children', c.childrenInfo),
          InfoCard('Talking Points', c.talkingPoints),
          InfoCard('Notes', c.notes),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _log(context, c),
              icon: const Icon(Icons.note_add),
              label: const Text('Log Interaction / Follow-Up'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Interaction history · newest first',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No interactions recorded'),
            ),
          for (final log in logs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.type} · ${localizations.formatMediumDate(log.date.toLocal())} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(log.date.toLocal()))}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(log.summary),
                    if (log.followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow-up: ${localizations.formatMediumDate(log.followUpDate!.toLocal())}',
                            ),
                            if (log.followUpReason.trim().isNotEmpty)
                              Text('Reason: ${log.followUpReason.trim()}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
