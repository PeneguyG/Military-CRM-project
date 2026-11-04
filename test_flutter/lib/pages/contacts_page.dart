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
      tagDefinitions: store.profileTags,
      dropdownFields: {
        'prefix': _contactPrefixes,
        'suffix': _contactSuffixes,
        'military_branch': _militaryBranches,
        'military_rank': _militaryRanks,
        'preferred_contact_method': [
          '',
          ...store.profileTags
              .where((tag) => tag.category == 'preferred_contact')
              .map((tag) => tag.value),
        ],
        'life_status': store.profileTags
            .where((tag) => tag.category == 'life_status')
            .map((tag) => tag.value)
            .toList(),
      },
      fields: const {
        'photo_blob': 'Profile photo',
        'prefix': 'Prefix',
        'first_name': 'First name *',
        'last_name': 'Last name *',
        'suffix': 'Suffix',
        'military_branch': 'Military branch',
        'military_rank': 'Military rank',
        'preferred_contact_method': 'Preferred contact',
        'life_status': 'Life status',
        'title': 'Professional / civilian title',
        'phone': 'Phone',
        'email': 'Email',
        'address': 'Address / Location',
        'spouse_name': 'Spouse name (optional)',
        'children_json': 'Children',
        'custom_tags_json': 'Profile tags',
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
        final staleCutoff = DateTime.now().subtract(const Duration(days: 30));
        final latestInteractionByContact = <int, DateTime>{};
        final latestCallByContact = <int, DateTime>{};
        for (final interaction in widget.store.interactions) {
          final contactId = interaction.contactId;
          final previous = latestInteractionByContact[contactId];
          if (previous == null || interaction.date.isAfter(previous)) {
            latestInteractionByContact[contactId] = interaction.date;
          }
          if (interaction.type.toLowerCase() == 'call') {
            final previousCall = latestCallByContact[contactId];
            if (previousCall == null ||
                interaction.date.isAfter(previousCall)) {
              latestCallByContact[contactId] = interaction.date;
            }
          }
        }
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
                    final lastInteraction = latestInteractionByContact[c.id];
                    final lastCall = latestCallByContact[c.id];
                    final needsContact =
                        lastInteraction == null ||
                        lastCall == null ||
                        !lastCall.isAfter(staleCutoff);
                    return ListTile(
                      selected: c.id == _selected,
                      leading: ContactPhoto(c, size: 40),
                      title: Row(
                        children: [
                          if (needsContact) ...[
                            Tooltip(
                              message: lastInteraction == null
                                  ? 'No interactions recorded'
                                  : lastCall == null
                                  ? 'No call recorded'
                                  : 'No call in the last 30 days',
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.deepOrange,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              c.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RecordStatusIndicator(isActive: !c.isArchived),
                        ],
                      ),
                      subtitle: Text(
                        [
                          if (c.militaryRank.isNotEmpty) c.militaryRank,
                          if (c.militaryBranch.isNotEmpty) c.militaryBranch,
                          if (c.title.isNotEmpty) c.title,
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
            followUpTime: result['followUpTime'] as String?,
            followUpReason: result['followUpReason'] as String? ?? '',
            attachments:
                (result['attachments'] as List<InteractionAttachment>?) ??
                const [],
          ),
        ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, Contact contact) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _AddContactNoteDialog(),
    );
    if (text == null || !context.mounted) return;
    await runDatabaseAction(
      context,
      () => store.addContactNote(
        ContactNote(
          contactId: contact.id!,
          text: text,
          createdAt: DateTime.now(),
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
      final preferredTag = store.profileTags
          .where(
            (tag) =>
                tag.category == 'preferred_contact' &&
                tag.value == c.preferredContactMethod,
          )
          .firstOrNull;
      final lifeTag = store.profileTags
          .where(
            (tag) => tag.category == 'life_status' && tag.value == c.lifeStatus,
          )
          .firstOrNull;
      final assignedTags = [
        for (final id in c.customTagIds)
          ...store.profileTags.where((tag) => tag.id == id),
      ];
      final additionalTags = assignedTags.where((tag) {
        if (tag.category == 'preferred_contact' &&
            tag.value == c.preferredContactMethod) {
          return false;
        }
        if (tag.category == 'life_status' && tag.value == c.lifeStatus) {
          return false;
        }
        return true;
      });
      final logs = store.interactions.where((i) => i.contactId == id).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final contactNotes = store.notesForContact(id);
      final localizations = MaterialLocalizations.of(context);
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ContactPhoto(c, size: 96),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  c.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: 12),
              RecordStatusIndicator(isActive: !c.isArchived),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (c.preferredContactMethod.isNotEmpty)
                ContactProfileTag(
                  label:
                      'Preferred contact: ${preferredTag?.label ?? c.preferredContactMethod}',
                  color: Color(
                    preferredTag?.colorValue ??
                        preferredContactColor(
                          c.preferredContactMethod,
                        ).toARGB32(),
                  ),
                ),
              ContactProfileTag(
                label:
                    lifeTag?.label ??
                    (c.lifeStatus == 'deceased' ? 'Deceased' : 'Alive'),
                color: Color(
                  lifeTag?.colorValue ??
                      lifeStatusColor(c.lifeStatus).toARGB32(),
                ),
              ),
              for (final tag in additionalTags)
                ContactProfileTag(
                  label: tag.label,
                  color: Color(tag.colorValue),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
          const Divider(height: 24),
          InfoCard(
            'Organization',
            organization == null
                ? 'No organization'
                : organization.isArchived
                ? 'Archived organization (see Archive tab)'
                : organization.name,
            icon: Icons.business_outlined,
          ),
          InfoCard(
            'Last interaction',
            logs.isEmpty
                ? 'No interactions recorded'
                : '${localizations.formatMediumDate(logs.first.date.toLocal())} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(logs.first.date.toLocal()))} · ${logs.first.type}',
            icon: Icons.history,
          ),
          if (c.phone.isNotEmpty)
            InfoCard(
              'Phone',
              formatPhoneForDisplay(c.phone),
              icon: Icons.phone_outlined,
              trailing: OutlinedButton.icon(
                onPressed: () async {
                  final type = await phoneAction(context, c.phone);
                  if (type != null && context.mounted) {
                    await _log(context, c, type);
                  }
                },
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Call or text'),
              ),
            ),
          InfoCard(
            'Address / Location',
            c.address,
            icon: Icons.location_on_outlined,
          ),
          InfoCard('Email', c.email, icon: Icons.email_outlined),
          if (c.spouseName.isNotEmpty)
            InfoCard('Spouse', c.spouseName, icon: Icons.people_alt_outlined),
          if (c.children.isNotEmpty)
            InfoCard(
              'Children',
              c.children
                  .map(
                    (child) =>
                        '${child.name}${child.age == null ? '' : ' · Age ${child.age}'}',
                  )
                  .join('\n'),
              icon: Icons.child_care_outlined,
            )
          else if (c.childrenInfo.isNotEmpty)
            InfoCard(
              'Children',
              c.childrenInfo,
              icon: Icons.child_care_outlined,
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _addNote(context, c),
              icon: const Icon(Icons.add),
              label: const Text('Add note'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
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
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (contactNotes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No notes yet.'),
                    ),
                  for (final note in contactNotes) ...[
                    if (contactNotes.first != note) const Divider(height: 24),
                    SelectableText(note.text),
                    const SizedBox(height: 4),
                    Text(
                      '${localizations.formatMediumDate(note.createdAt.toLocal())} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(note.createdAt.toLocal()))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
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
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Interaction history · newest first',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
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
                    Row(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${log.type} · ${localizations.formatMediumDate(log.date.toLocal())} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(log.date.toLocal()))}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(log.summary),
                    if (log.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Attachments',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final attachment in log.attachments)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(attachmentIcon(attachment.fileName)),
                          title: Text(attachment.fileName),
                          subtitle: Text(
                            formatAttachmentSize(attachment.bytes.length),
                          ),
                        ),
                    ],
                    if (log.followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow-up: ${localizations.formatMediumDate(log.followUpDate!.toLocal())} · ${formatFollowUpTime(context, log.followUpTime)}',
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

class _AddContactNoteDialog extends StatefulWidget {
  const _AddContactNoteDialog();

  @override
  State<_AddContactNoteDialog> createState() => _AddContactNoteDialogState();
}

class _AddContactNoteDialogState extends State<_AddContactNoteDialog> {
  final _key = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add contact note'),
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
            hintText: 'Add a note to this contact’s profile',
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
