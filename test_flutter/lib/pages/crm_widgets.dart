import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';

String label(String value) => value[0].toUpperCase() + value.substring(1);

Future<void> runDatabaseAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save or refresh records. Check database access and try again.',
          ),
        ),
      );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final ContactStatus status;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (status) {
      ContactStatus.active => dark ? Colors.greenAccent : Colors.green.shade800,
      ContactStatus.archived =>
        dark ? Colors.grey.shade300 : Colors.grey.shade700,
    };
    return Chip(
      label: Text(label(status.name), style: TextStyle(color: color)),
      avatar: Icon(
        Icons.circle,
        size: 12,
        color: status == ContactStatus.archived ? Colors.grey : color,
      ),
    );
  }
}

class RecordStatusIndicator extends StatelessWidget {
  const RecordStatusIndicator({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF2E7D32) : Colors.grey.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Text(
          isActive ? 'Active' : 'Archived',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ContactPhoto extends StatelessWidget {
  const ContactPhoto(this.contact, {super.key, this.size = 56});
  final Contact contact;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      child: Icon(Icons.person, size: size / 2),
    );
    final photoBytes = contact.photoBytes;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          photoBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    final path = contact.photoPath;
    if (path == null || path.trim().isEmpty) return fallback;
    return ClipOval(
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard(this.title, this.text, {super.key, this.footer});
  final String title, text;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(text.isEmpty ? 'None recorded' : text),
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    ),
  );
}

Color preferredContactColor(String method) => switch (method.toLowerCase()) {
  'call' => const Color(0xFF1565C0),
  'text' => const Color(0xFF6A1B9A),
  'email' => const Color(0xFF00796B),
  'in person' => const Color(0xFFB45309),
  _ => const Color(0xFF616161),
};

Color lifeStatusColor(String status) =>
    status == 'deceased' ? const Color(0xFF616161) : const Color(0xFF2E7D32);

class ContactProfileTag extends StatelessWidget {
  const ContactProfileTag({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ),
  );
}

String formatFollowUpTime(BuildContext context, String? value) {
  if (value == null) return 'Time not set';
  final parts = value.split(':');
  if (parts.length != 2) return 'Time not set';
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return 'Time not set';
  }
  return TimeOfDay(hour: hour, minute: minute).format(context);
}

Future<String?> phoneAction(BuildContext context, String phone) async {
  final type = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(formatPhoneForDisplay(phone))),
          ListTile(
            leading: const Icon(Icons.call),
            title: const Text('Call'),
            onTap: () => Navigator.pop(context, 'Call'),
          ),
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('Text'),
            onTap: () => Navigator.pop(context, 'Text'),
          ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return null;
  try {
    final launched = await launchUrl(
      Uri(scheme: type == 'Call' ? 'tel' : 'sms', path: phoneDigits(phone)),
    );
    if (launched) return type;
  } catch (_) {
    // Desktop devices may have no registered telephone or SMS application.
  }
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No application could open this phone action. You can still log an interaction manually.',
        ),
      ),
    );
  return null;
}

class RecordForm extends StatefulWidget {
  const RecordForm({
    super.key,
    required this.title,
    required this.values,
    required this.fields,
    this.dropdownFields = const {},
    this.tagDefinitions = const [],
    this.organizations,
    this.contactStatus,
    this.organizationId,
    this.onSave,
    this.organizationForm = false,
  });
  final String title;
  final Map<String, Object?> values;
  final Map<String, String> fields;
  final Map<String, List<String>> dropdownFields;
  final List<ProfileTagDefinition> tagDefinitions;
  final List<Organization>? organizations;
  final ContactStatus? contactStatus;
  final int? organizationId;
  final bool organizationForm;
  final Future<void> Function(Map<String, Object?>)? onSave;
  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  bool _saving = false;
  String? _error;
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final key in widget.fields.keys.where(
      (key) =>
          !widget.dropdownFields.containsKey(key) &&
          key != 'children_json' &&
          key != 'photo_blob' &&
          key != 'custom_tags_json',
    ))
      key: TextEditingController(
        text: key == 'phone'
            ? formatPhoneForEditing(widget.values[key] as String? ?? '')
            : widget.values[key] as String? ?? '',
      ),
  };
  late final Map<String, String> _dropdownValues = {
    for (final entry in widget.dropdownFields.entries)
      entry.key: widget.values[entry.key] as String? ?? '',
  };
  late int? _organizationId = widget.organizationId;
  late ContactStatus _status = widget.contactStatus ?? ContactStatus.active;
  late List<ChildRecord> _children = ChildRecord.decodeMany(
    widget.values['children_json'],
  );
  late List<int> _selectedCustomTagIds = decodeIntList(
    widget.values['custom_tags_json'],
  ).where((id) => widget.tagDefinitions.any((tag) => tag.id == id)).toList();
  late Uint8List? _photoBytes = _readPhotoBytes(widget.values['photo_blob']);
  late String? _photoPath = widget.values['photo_path'] as String?;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _recordField(MapEntry<String, String> entry) {
    if (entry.key == 'children_json') {
      return ChildrenEditor(
        initialChildren: _children,
        onChanged: (children) => _children = children,
      );
    }
    if (entry.key == 'photo_blob') return _photoField(entry.value);
    if (entry.key == 'custom_tags_json') return _customTagsField(entry.value);

    final options = widget.dropdownFields[entry.key];
    if (options != null) {
      final selectedValue = _dropdownValues[entry.key] ?? '';
      final availableOptions = [...options];
      if (!availableOptions.contains(selectedValue)) {
        availableOptions.add(selectedValue);
      }

      return DropdownButtonFormField<String>(
        initialValue: selectedValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: entry.value,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in availableOptions)
            DropdownMenuItem(
              value: option,
              child: Text(
                _dropdownOptionLabel(entry.key, option),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) => setState(() {
          _dropdownValues[entry.key] = value ?? '';
        }),
      );
    }

    return TextFormField(
      controller: _controllers[entry.key],
      decoration: InputDecoration(
        labelText: entry.value,
        border: const OutlineInputBorder(),
      ),
      minLines: entry.key == 'notes' || entry.key == 'talking_points' ? 3 : 1,
      maxLines:
          entry.key == 'notes' ||
              entry.key == 'talking_points' ||
              entry.key == 'children_info'
          ? 5
          : 1,
      keyboardType: entry.key == 'phone'
          ? TextInputType.phone
          : entry.key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      inputFormatters: entry.key == 'phone'
          ? const [UsPhoneNumberFormatter()]
          : null,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (entry.key == 'phone' &&
            text.isNotEmpty &&
            phoneDigits(text).length != 10) {
          return 'Enter a 10-digit phone number.';
        }
        if (['name', 'first_name', 'last_name'].contains(entry.key) &&
            text.isEmpty) {
          return 'Required';
        }
        if (entry.key == 'email' &&
            text.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Enter a valid email address';
        }
        return null;
      },
    );
  }

  String _dropdownOptionLabel(String field, String value) {
    final category = switch (field) {
      'preferred_contact_method' => 'preferred_contact',
      'life_status' => 'life_status',
      _ => null,
    };
    if (category != null) {
      final definition = widget.tagDefinitions
          .where((tag) => tag.category == category && tag.value == value)
          .firstOrNull;
      if (definition != null) return definition.label;
      if (field == 'life_status' && value == 'alive') return 'Alive';
      if (field == 'life_status' && value == 'deceased') return 'Deceased';
    }
    return value.isEmpty ? 'None' : value;
  }

  Widget _customTagsField(String title) {
    final availableTags = widget.tagDefinitions
        .where((tag) => tag.id != null)
        .toList();
    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      child: availableTags.isEmpty
          ? const Text('No tags have been configured in Settings.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in availableTags)
                  FilterChip(
                    label: Text(tag.label),
                    selected: _selectedCustomTagIds.contains(tag.id),
                    selectedColor: Color(tag.colorValue).withValues(alpha: 0.2),
                    checkmarkColor: Color(tag.colorValue),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedCustomTagIds.add(tag.id!);
                      } else {
                        _selectedCustomTagIds.remove(tag.id);
                      }
                    }),
                  ),
              ],
            ),
    );
  }

  Widget _photoField(String title) {
    final bytes = _photoBytes;
    final path = _photoPath;
    Widget preview;
    if (bytes != null && bytes.isNotEmpty) {
      preview = Image.memory(
        bytes,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    } else if (path != null && path.trim().isNotEmpty) {
      preview = Image.file(
        File(path),
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.person_outline),
      );
    } else {
      preview = const SizedBox(
        width: 88,
        height: 88,
        child: Icon(Icons.person_outline, size: 44),
      );
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          ClipOval(child: preview),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _selectPhoto,
                  icon: const Icon(Icons.upload_file),
                  label: Text(bytes == null ? 'Choose photo' : 'Replace photo'),
                ),
                if (bytes != null || (path?.trim().isNotEmpty ?? false))
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _photoBytes = null;
                            _photoPath = null;
                          }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        setState(() => _error = 'The selected image is empty.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoPath = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load that image. Please try another file.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                for (final entry in widget.fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _recordField(entry),
                  ),
                if (!widget.organizationForm) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _organizationId ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Organization',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('No organization'),
                      ),
                      for (final o in widget.organizations ?? <Organization>[])
                        DropdownMenuItem(
                          value: o.id,
                          child: Text(
                            '${o.name}${o.isArchived ? ' (Archived)' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _organizationId = v == -1 ? null : v),
                  ),
                  DropdownButtonFormField<ContactStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final s in ContactStatus.values)
                        DropdownMenuItem(value: s, child: Text(label(s.name))),
                    ],
                    onChanged: (s) => setState(() => _status = s!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_key.currentState!.validate()) return;
                  final result = Map<String, Object?>.of(widget.values);
                  for (final entry in _controllers.entries) {
                    result[entry.key] = entry.value.text.trim();
                  }
                  result.addAll(_dropdownValues);
                  if (!widget.organizationForm) {
                    result['organization_id'] = _organizationId;
                    result['status'] = _status.name;
                    result['children_json'] = jsonEncode(
                      _children.map((child) => child.toMap()).toList(),
                    );
                    result['custom_tags_json'] = jsonEncode(
                      _selectedCustomTagIds,
                    );
                    result['photo_blob'] = _photoBytes;
                    result['photo_path'] = _photoPath;
                  }
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await widget.onSave?.call(result);
                    if (context.mounted) {
                      setState(() => _saving = false);
                      Navigator.pop(context, result);
                    }
                  } catch (_) {
                    if (mounted)
                      setState(() {
                        _saving = false;
                        _error =
                            'Save failed. Your entries are retained. Check database access and try again.';
                      });
                  }
                },
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

class _ChildDraft {
  _ChildDraft({String name = '', String age = ''})
    : name = TextEditingController(text: name),
      age = TextEditingController(text: age);

  final TextEditingController name;
  final TextEditingController age;

  void dispose() {
    name.dispose();
    age.dispose();
  }
}

class ChildrenEditor extends StatefulWidget {
  const ChildrenEditor({
    super.key,
    required this.initialChildren,
    required this.onChanged,
  });

  final List<ChildRecord> initialChildren;
  final ValueChanged<List<ChildRecord>> onChanged;

  @override
  State<ChildrenEditor> createState() => _ChildrenEditorState();
}

class _ChildrenEditorState extends State<ChildrenEditor> {
  late final List<_ChildDraft> _rows = [
    for (final child in widget.initialChildren)
      _ChildDraft(name: child.name, age: child.age?.toString() ?? ''),
  ];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged([
      for (final row in _rows)
        if (row.name.text.trim().isNotEmpty)
          ChildRecord(
            name: row.name.text.trim(),
            age: int.tryParse(row.age.text.trim()),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_rows.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('No children added.'),
        ),
      for (var index = 0; index < _rows.length; index++) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _rows[index].name,
                decoration: InputDecoration(
                  labelText: 'Child ${index + 1} name',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _notifyChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _rows[index].age,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _notifyChanged(),
              ),
            ),
            IconButton(
              tooltip: 'Remove child',
              onPressed: () {
                final removed = _rows.removeAt(index);
                removed.dispose();
                setState(_notifyChanged);
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            _rows.add(_ChildDraft());
            _notifyChanged();
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add child'),
        ),
      ),
    ],
  );
}

Uint8List? _readPhotoBytes(Object? value) {
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  return null;
}

class InteractionForm extends StatefulWidget {
  const InteractionForm({super.key, this.initialType = 'Call', this.onSave});
  final String initialType;
  final Future<void> Function(Map<String, Object?>)? onSave;
  @override
  State<InteractionForm> createState() => _InteractionFormState();
}

class _InteractionFormState extends State<InteractionForm> {
  bool _saving = false;
  String? _error;
  final _key = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _followUpReason = TextEditingController();
  late String _type = widget.initialType;
  DateTime? _followUp;
  TimeOfDay? _followUpTime;
  @override
  void dispose() {
    _summary.dispose();
    _followUpReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Log Interaction / Follow-Up'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Text(
                  'Record what happened. Opening a phone app does not confirm a completed call or sent text.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: [
                    for (final t in InteractionLog.types)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                TextFormField(
                  controller: _summary,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Summary'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a summary' : null,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        _followUp == null
                            ? 'Set optional follow-up date'
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_followUp!),
                      ),
                      onPressed: () async {
                        final now = DateUtils.dateOnly(DateTime.now());
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _followUp ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 20),
                        );
                        if (mounted && date != null) {
                          setState(() {
                            _followUp = date;
                            _followUpTime ??= const TimeOfDay(
                              hour: 9,
                              minute: 0,
                            );
                          });
                        }
                      },
                    ),
                    if (_followUp != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(_followUpTime!.format(context)),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _followUpTime!,
                          );
                          if (mounted && time != null) {
                            setState(() => _followUpTime = time);
                          }
                        },
                      ),
                  ],
                ),
                if (_followUp != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Follow-up details',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _followUpReason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason for follow-up',
                      hintText: 'What should you discuss or check on?',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a reason for the scheduled follow-up.'
                        : null,
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _followUp = null;
                      _followUpTime = null;
                      _followUpReason.clear();
                    }),
                    child: const Text('Clear follow-up'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_key.currentState!.validate()) return;
                  final result = <String, Object?>{
                    'type': _type,
                    'summary': _summary.text.trim(),
                    'followUp': _followUp,
                    'followUpTime': _followUp == null
                        ? null
                        : '${_followUpTime!.hour.toString().padLeft(2, '0')}:${_followUpTime!.minute.toString().padLeft(2, '0')}',
                    'followUpReason': _followUp == null
                        ? ''
                        : _followUpReason.text.trim(),
                  };
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await widget.onSave?.call(result);
                    if (context.mounted) {
                      setState(() => _saving = false);
                      Navigator.pop(context, result);
                    }
                  } catch (_) {
                    if (mounted)
                      setState(() {
                        _saving = false;
                        _error =
                            'Save failed. Your summary is retained. Please try again.';
                      });
                  }
                },
          child: Text(_saving ? 'Saving…' : 'Save interaction'),
        ),
      ],
    ),
  );
}
