import 'rich_text_widgets.dart';
import '../utils/rich_text_content.dart';
import '../utils/soundex_helper.dart';
import 'package:flutter/material.dart';
import '../crm_store.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';
import 'crm_widgets.dart';
import 'record_browser.dart';
import 'responsive_dialog.dart';

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

final _militaryRanks = <String>[
  '',
  ...(<String>[
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
    'Chief Master Sergeant of the Space Force',
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
  ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
];

const _armyRankNames = <String>{
  'Private',
  'Private Second Class',
  'Private First Class',
  'Specialist',
  'Corporal',
  'Sergeant',
  'Staff Sergeant',
  'Sergeant First Class',
  'Master Sergeant',
  'First Sergeant',
  'Sergeant Major',
  'Command Sergeant Major',
  'Sergeant Major of the Army',
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
};

const _navyRankNames = <String>{
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
  'Chief Warrant Officer 2',
  'Chief Warrant Officer 3',
  'Chief Warrant Officer 4',
  'Chief Warrant Officer 5',
  'Ensign',
  'Lieutenant Junior Grade',
  'Lieutenant',
  'Lieutenant Commander',
  'Commander',
  'Captain',
  'Rear Admiral (Lower Half)',
  'Rear Admiral (Upper Half)',
  'Vice Admiral',
  'Admiral',
  'Fleet Admiral',
};

const _airForceRankNames = <String>{
  'Airman Basic',
  'Airman',
  'Airman First Class',
  'Senior Airman',
  'Staff Sergeant',
  'Technical Sergeant',
  'Master Sergeant',
  'Senior Master Sergeant',
  'First Sergeant',
  'Chief Master Sergeant',
  'Chief Master Sergeant of the Air Force',
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
};

const _marineCorpsRankNames = <String>{
  'Private',
  'Private First Class',
  'Lance Corporal',
  'Corporal',
  'Sergeant',
  'Staff Sergeant',
  'Gunnery Sergeant',
  'Master Sergeant',
  'First Sergeant',
  'Sergeant Major',
  'Sergeant Major of the Marine Corps',
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
};

final _militaryRanksByBranch = <String, List<String>>{
  '': _militaryRanks,
  'Army': _branchRanks(_armyRankNames),
  'Army National Guard': _branchRanks(_armyRankNames),
  'Navy': _branchRanks(_navyRankNames),
  'Coast Guard': _branchRanks(
    {..._navyRankNames}
      ..remove('Chief Warrant Officer 5')
      ..remove('Fleet Admiral'),
  ),
  'Air Force': _branchRanks(_airForceRankNames),
  'Air National Guard': _branchRanks(_airForceRankNames),
  'Space Force': _branchRanks(
    {..._airForceRankNames, 'Chief Master Sergeant of the Space Force'}
      ..remove('Chief Master Sergeant of the Air Force'),
  ),
  'Marine Corps': _branchRanks(_marineCorpsRankNames),
  'Other / Allied service': _militaryRanks,
};

List<String> _branchRanks(Set<String> branchRanks) => [
  '',
  ..._militaryRanks.skip(1).where(branchRanks.contains),
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
      confirmDiscardOnExit: contact == null,
      onSave: (values) {
        // Status is the contact-facing control for archiving. Keep the legacy
        // storage flag in sync so archived contacts move into Archive.
        values['is_archived'] = values['status'] == ContactStatus.archived.name
            ? 1
            : 0;
        values['contact_status'] =
            values['status'] == ContactStatus.inactive.name
            ? ContactStatus.inactive.name
            : ContactStatus.active.name;
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
        'phone_label': [
          'Mobile',
          'Home',
          'Work',
          'Office',
          'Business',
          'Fax',
          'Secondary',
          'Other',
        ],
        'email_label': ['Primary', 'Work', 'Personal', 'Home', 'Other'],
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
      dependentDropdownOptions: {'military_rank': _militaryRanksByBranch},
      dropdownDependencies: const {'military_rank': 'military_branch'},
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
        'phone': 'Primary phone',
        'additional_phones_json': 'Additional phone numbers',
        'email': 'Primary email',
        'additional_emails_json': 'Additional email addresses',
        'address': 'Address / Location',
        'latitude': 'Latitude',
        'longitude': 'Longitude',
        'spouse_name': 'Spouse name (optional)',
        'children_json': 'Children',
        'custom_tags_json': 'Profile tags',
        'notes': 'Profile notes',
        'talking_points': 'Talking points',
      },
    ),
  );
}

Future<void> showArchivedContactProfile(
  BuildContext context,
  CrmStore store,
  Contact contact, {
  ValueChanged<String>? onViewMap,
}) async {
  final contactId = contact.id;
  if (contactId == null) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final viewport = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        constraints: responsiveDialogConstraints(dialogContext),
        insetPadding: responsiveDialogInsetPadding(dialogContext),
        child: SizedBox(
          width: viewport.width * 0.9,
          height: viewport.height * 0.88,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close profile',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: ContactDetail(
                  store: store,
                  id: contactId,
                  allowArchivedView: true,
                  onViewMap: onViewMap,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.store,
    this.initialContactId,
    this.onViewMap,
  });
  final CrmStore store;
  final int? initialContactId;
  final ValueChanged<String>? onViewMap;
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String _extraText(Contact c) => [
    if (c.id != null)
      widget.store
          .notesForContact(c.id!)
          .map((n) => RichTextContent.plainText(n.text))
          .join(' '),
    widget.store.organization(c.organizationId)?.searchText ?? '',
  ].join(' ');
  String _searchText(Contact c) => '${c.searchText} ${_extraText(c)}';
  String _search = '';
  bool _activeExpanded = true;
  bool _inactiveExpanded = true;
  late int? _selected = widget.initialContactId;
  @override
  void initState() {
    super.initState();
    if (_selected != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.size != null && context.size!.width < 850) {
          openDetail(
            context,
            ContactDetail(
              store: widget.store,
              id: _selected!,
              onViewMap: widget.onViewMap,
            ),
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
          if (interaction.isFollowUpOnly) continue;
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
                      SoundexHelper.matchesQuery(
                        _search,
                        rawTargetText: _searchText(c),
                        precomputedSoundex:
                            '${c.fullSoundexIndex} ${SoundexHelper.encodePhrase(_extraText(c))}',
                      ),
                )
                .toList()
              ..sort(
                (a, b) => a.fullName.toLowerCase().compareTo(
                  b.fullName.toLowerCase(),
                ),
              );
        final selected = items.where((c) => c.id == _selected).firstOrNull;
        final activeItems = items
            .where((contact) => contact.status == ContactStatus.active)
            .toList();
        final inactiveItems = items
            .where((contact) => contact.status == ContactStatus.inactive)
            .toList();
        final visibleActiveCount = _activeExpanded ? activeItems.length : 0;
        final inactiveHeaderIndex = 1 + visibleActiveCount;
        final visibleInactiveCount = _inactiveExpanded
            ? inactiveItems.length
            : 0;

        Widget sectionHeader({
          required String title,
          required int count,
          required bool expanded,
          required IconData icon,
          required VoidCallback onTap,
        }) => Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            dense: true,
            leading: Icon(icon),
            title: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count'),
                const SizedBox(width: 8),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: onTap,
          ),
        );

        Widget contactTile(Contact contact) {
          final lastInteraction = latestInteractionByContact[contact.id];
          final lastCall = latestCallByContact[contact.id];
          final needsContact =
              lastInteraction == null ||
              lastCall == null ||
              !lastCall.isAfter(staleCutoff);
          return ListTile(
            selected: contact.id == _selected,
            leading: ContactPhoto(contact, size: 40),
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
                    contact.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                RecordStatusIndicator(
                  isActive: contact.status == ContactStatus.active,
                  contactStatus: contact.status,
                ),
              ],
            ),
            subtitle: contact.title.isEmpty ? null : Text(contact.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() => _selected = contact.id);
              if (constraints.maxWidth < 850) {
                openDetail(
                  context,
                  ContactDetail(
                    store: widget.store,
                    id: contact.id!,
                    onViewMap: widget.onViewMap,
                  ),
                  contact.fullName,
                );
              }
            },
          );
        }

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
                  itemCount: 2 + visibleActiveCount + visibleInactiveCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return sectionHeader(
                        title: 'Active accounts',
                        count: activeItems.length,
                        expanded: _activeExpanded,
                        icon: Icons.check_circle_outline,
                        onTap: () =>
                            setState(() => _activeExpanded = !_activeExpanded),
                      );
                    }
                    if (index == inactiveHeaderIndex) {
                      return sectionHeader(
                        title: 'Inactive accounts',
                        count: inactiveItems.length,
                        expanded: _inactiveExpanded,
                        icon: Icons.pause_circle_outline,
                        onTap: () => setState(
                          () => _inactiveExpanded = !_inactiveExpanded,
                        ),
                      );
                    }
                    if (index < inactiveHeaderIndex) {
                      return contactTile(activeItems[index - 1]);
                    }
                    return contactTile(
                      inactiveItems[index - inactiveHeaderIndex - 1],
                    );
                  },
                ),
          detail: selected == null
              ? const Center(child: Text('Select a contact'))
              : ContactDetail(
                  store: widget.store,
                  id: selected.id!,
                  onViewMap: widget.onViewMap,
                ),
        );
      },
    ),
  );
}

class ContactDetail extends StatefulWidget {
  const ContactDetail({
    super.key,
    required this.store,
    required this.id,
    this.onViewMap,
    this.allowArchivedView = false,
  });
  final CrmStore store;
  final int id;
  final ValueChanged<String>? onViewMap;
  final bool allowArchivedView;

  @override
  State<ContactDetail> createState() => _ContactDetailState();
}

class _ContactDetailState extends State<ContactDetail> {
  int _selectedPhoneIndex = 0;
  int _selectedEmailIndex = 0;

  CrmStore get store => widget.store;
  int get id => widget.id;

  @override
  void didUpdateWidget(covariant ContactDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      _selectedPhoneIndex = 0;
      _selectedEmailIndex = 0;
    }
  }

  Future<void> _log(
    BuildContext context,
    Contact c, {
    String type = 'Call',
    bool followUpOnly = false,
  }) async {
    await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InteractionForm(
        initialType: type,
        followUpOnly: followUpOnly,
        onSave: (result) => store.logInteraction(
          InteractionLog(
            contactId: id,
            organizationId: c.organizationId,
            date: DateTime.now(),
            type: followUpOnly ? 'Other' : result['type'] as String,
            summary: followUpOnly
                ? 'Follow-up scheduled'
                : result['summary'] as String,
            followUpDate: result['followUp'] as DateTime?,
            followUpTime: result['followUpTime'] as String?,
            followUpReason: result['followUpReason'] as String? ?? '',
            isFollowUpOnly: followUpOnly,
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
      if (c.isArchived && !widget.allowArchivedView) {
        return const Center(
          child: Text(
            'This contact is archived. Open the Archive tab to view it.',
          ),
        );
      }
      final phoneNumbers = c.phoneNumbers;
      final emailAddresses = c.emailAddresses;
      final phoneIndex = _selectedPhoneIndex < phoneNumbers.length
          ? _selectedPhoneIndex
          : 0;
      final emailIndex = _selectedEmailIndex < emailAddresses.length
          ? _selectedEmailIndex
          : 0;
      final selectedPhone = phoneNumbers.isEmpty
          ? null
          : phoneNumbers[phoneIndex];
      final selectedEmail = emailAddresses.isEmpty
          ? null
          : emailAddresses[emailIndex];
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
        if (tag.category == 'life_status' && tag.value == 'alive') {
          return false;
        }
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
      final interactionLogs = logs.where((log) => !log.isFollowUpOnly).toList();
      final contactNotes = store.notesForContact(id);
      final localizations = MaterialLocalizations.of(context);
      final titleDetails = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      );
      final actions = Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => editContact(context, store, c),
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          if (widget.onViewMap != null)
            OutlinedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                widget.onViewMap!('contact:${c.id}');
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('View on Map'),
            ),
          if (c.isArchived)
            FilledButton.tonalIcon(
              onPressed: () => runDatabaseAction(
                context,
                () => store.archiveContact(c.id!, false),
              ),
              icon: const Icon(Icons.unarchive_outlined),
              label: const Text('Restore'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => runDatabaseAction(
                context,
                () => store.archiveContact(c.id!, true),
              ),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive'),
            ),
        ],
      );
      final statusTags = SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
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
                lifeTag?.colorValue ?? lifeStatusColor(c.lifeStatus).toARGB32(),
              ),
            ),
            for (final tag in additionalTags)
              ContactProfileTag(label: tag.label, color: Color(tag.colorValue)),
          ],
        ),
      );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ContactPhoto(c, size: 96),
              RecordStatusIndicator(
                isActive: c.status == ContactStatus.active,
                contactStatus: c.status,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, _) {
              final name = Text(
                c.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: name),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: statusTags,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 560
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleDetails,
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: titleDetails),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  ),
          ),
          const SizedBox(height: 2),
          const Divider(height: 1),
          const SizedBox(height: 12),
          InfoCard(
            'Last interaction',
            interactionLogs.isEmpty
                ? 'No interactions recorded'
                : '${localizations.formatMediumDate(interactionLogs.first.date.toLocal())} · ${TimeOfDay.fromDateTime(interactionLogs.first.date.toLocal()).format(context)} · ${interactionLogs.first.type}',
            icon: Icons.history,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
            'Phone',
            phoneNumbers
                .map(
                  (phone) =>
                      '${phone.label}: ${formatPhoneForDisplay(phone.number)}',
                )
                .join('\n'),
            icon: Icons.phone_outlined,
            footerSpacing: 4,
            footerDivider: true,
            footer: phoneNumbers.isEmpty
                ? null
                : Row(
                    children: [
                      Expanded(
                        child: AnchoredDropdown<int>(
                          label: 'Choose phone number',
                          initialSelection: phoneIndex,
                          entries: [
                            for (
                              var index = 0;
                              index < phoneNumbers.length;
                              index++
                            )
                              DropdownMenuEntry(
                                value: index,
                                label:
                                    '${phoneNumbers[index].label}: ${formatPhoneForDisplay(phoneNumbers[index].number)}',
                              ),
                          ],
                          onSelected: (index) {
                            if (index != null) {
                              setState(() => _selectedPhoneIndex = index);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedPhone == null
                            ? null
                            : () async {
                                final type = await phoneAction(
                                  context,
                                  selectedPhone.number,
                                );
                                if (type != null && context.mounted) {
                                  await _log(context, c, type: type);
                                }
                              },
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Call or text'),
                      ),
                    ],
                  ),
          ),
          InfoCard(
            'Email',
            emailAddresses
                .map((email) => '${email.label}: ${email.address}')
                .join('\n'),
            icon: Icons.email_outlined,
            footerSpacing: 4,
            footerDivider: true,
            footer: emailAddresses.isEmpty
                ? null
                : Row(
                    children: [
                      Expanded(
                        child: AnchoredDropdown<int>(
                          label: 'Choose email address',
                          initialSelection: emailIndex,
                          entries: [
                            for (
                              var index = 0;
                              index < emailAddresses.length;
                              index++
                            )
                              DropdownMenuEntry(
                                value: index,
                                label:
                                    '${emailAddresses[index].label}: ${emailAddresses[index].address}',
                              ),
                          ],
                          onSelected: (index) {
                            if (index != null) {
                              setState(() => _selectedEmailIndex = index);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedEmail == null
                            ? null
                            : () => emailAction(context, selectedEmail.address),
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Compose email'),
                      ),
                    ],
                  ),
          ),
          InfoCard(
            'Address / Location',
            c.address,
            icon: Icons.location_on_outlined,
          ),
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
          if (c.talkingPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Talking points',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            RichTextView(c.talkingPoints),
          ],
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
                  if (c.notes.trim().isEmpty && contactNotes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No notes yet.'),
                    ),
                  if (c.notes.trim().isNotEmpty) RichTextView(c.notes),
                  for (final note in contactNotes) ...[
                    if (c.notes.trim().isNotEmpty || contactNotes.first != note)
                      const Divider(height: 24),
                    RichTextView(note.text),
                    const SizedBox(height: 4),
                    Text(
                      '${localizations.formatMediumDate(note.createdAt.toLocal())} · ${TimeOfDay.fromDateTime(note.createdAt.toLocal()).format(context)}',
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
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _log(context, c),
                  icon: const Icon(Icons.note_add),
                  label: const Text('Log Interaction'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _log(context, c, followUpOnly: true),
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Schedule Follow-Up'),
                ),
              ],
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
              Expanded(
                child: Text(
                  'Interaction & follow-up history · Newest first',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No interactions or follow-ups recorded'),
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
                          log.isFollowUpOnly
                              ? Icons.add_alarm
                              : Icons.forum_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${log.isFollowUpOnly ? 'Follow-up scheduled' : log.type} · ${localizations.formatMediumDate(log.date.toLocal())} ${TimeOfDay.fromDateTime(log.date.toLocal()).format(context)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    if (!log.isFollowUpOnly) ...[
                      const SizedBox(height: 8),
                      SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Summary: ',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: log.summary),
                          ],
                        ),
                      ),
                    ],
                    if (!log.isFollowUpOnly && log.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Attachments',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final attachment in log.attachments)
                        InteractionAttachmentTile(
                          key: ValueKey(
                            '${attachment.id}:${attachment.fileName}',
                          ),
                          attachment: attachment,
                        ),
                    ],
                    if (log.followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!log.isFollowUpOnly) const Divider(height: 24),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Follow-up:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text:
                                        ' ${localizations.formatMediumDate(log.followUpDate!.toLocal())} · ${formatFollowUpTime(context, log.followUpTime)}',
                                  ),
                                ],
                              ),
                            ),
                            if (log.followUpReason.trim().isNotEmpty)
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Reason:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    TextSpan(
                                      text: ' ${log.followUpReason.trim()}',
                                    ),
                                  ],
                                ),
                              ),
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
    constraints: responsiveDialogConstraints(context),
    insetPadding: responsiveDialogInsetPadding(context),
    title: const Text('Add contact note'),
    scrollable: true,
    content: SizedBox(
      width: responsiveDialogContentWidth(context),
      child: Form(
        key: _key,
        child: RichTextEditor(
          controller: _controller,
          label: 'Note',
          required: true,
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
