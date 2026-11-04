import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/crm_models.dart';
import '../phone_number.dart';

String label(String value) => value[0].toUpperCase() + value.substring(1);

String capitalizeInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

const _namePattern = r"^[\p{L}]+(?:[ '\-][\p{L}]+)*$";
const _personNameKeys = {'first_name', 'last_name', 'spouse_name', 'title'};
const _contactPhoneLabels = [
  'Mobile',
  'Home',
  'Work',
  'Office',
  'Business',
  'Fax',
  'Secondary',
  'Other',
];
const _contactEmailLabels = ['Primary', 'Work', 'Personal', 'Home', 'Other'];

int? _maxCharactersFor(String field) => switch (field) {
  'first_name' ||
  'last_name' ||
  'title' ||
  'spouse_name' ||
  'name' ||
  'industry' ||
  'email' => 35,
  _ => null,
};

List<TextInputFormatter> _formattersFor(String field) {
  if (field == 'phone') return const [UsPhoneNumberFormatter()];
  final formatters = <TextInputFormatter>[];
  if (_personNameKeys.contains(field)) {
    formatters.add(
      FilteringTextInputFormatter.allow(RegExp(r"[\p{L} '\-]", unicode: true)),
    );
  }
  final limit = _maxCharactersFor(field);
  if (limit != null) formatters.add(LengthLimitingTextInputFormatter(limit));
  return formatters;
}

bool _isPersonName(String value) =>
    RegExp(_namePattern, unicode: true).hasMatch(value);

String? _validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isNotEmpty && phoneDigits(text).length != 10) {
    return 'Enter a 10-digit phone number.';
  }
  return null;
}

String? _validateEmailAddress(String? value) {
  final text = value?.trim() ?? '';
  if (text.length > 35) return 'Use 35 characters or fewer.';
  if (text.isNotEmpty &&
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
    return 'Enter an email with one @ and a dot.';
  }
  return null;
}

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
      ContactStatus.inactive =>
        dark ? Colors.orangeAccent : Colors.orange.shade900,
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
  const RecordStatusIndicator({
    super.key,
    required this.isActive,
    this.contactStatus,
  });

  final bool isActive;
  final ContactStatus? contactStatus;

  @override
  Widget build(BuildContext context) {
    final color = switch (contactStatus) {
      ContactStatus.active => const Color(0xFF2E7D32),
      ContactStatus.inactive => Colors.orange.shade800,
      ContactStatus.archived => Colors.grey.shade700,
      null => isActive ? const Color(0xFF2E7D32) : Colors.grey.shade700,
    };
    final statusText = contactStatus == null
        ? (isActive ? 'Active' : 'Archived')
        : label(contactStatus!.name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Text(
          statusText,
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

class OrganizationLogo extends StatelessWidget {
  const OrganizationLogo(this.organization, {super.key, this.size = 56});

  final Organization organization;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logoBytes = organization.logoBytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: logoBytes == null || logoBytes.isEmpty
            ? Icon(
                Icons.business_outlined,
                size: size * 0.55,
                color: Theme.of(context).colorScheme.primary,
              )
            : Padding(
                padding: const EdgeInsets.all(4),
                child: Image.memory(
                  logoBytes,
                  width: size - 8,
                  height: size - 8,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.broken_image_outlined, size: size * 0.55),
                ),
              ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard(
    this.title,
    this.text, {
    super.key,
    this.icon,
    this.trailing,
    this.footer,
  });
  final String title, text;
  final IconData? icon;
  final Widget? trailing, footer;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(text.isEmpty ? 'None recorded' : text),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
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

String formatAttachmentSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

IconData attachmentIcon(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' || 'txt' || 'rtf' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
    'jpg' ||
    'jpeg' ||
    'png' ||
    'gif' ||
    'bmp' ||
    'webp' => Icons.image_outlined,
    _ => Icons.attach_file,
  };
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

Future<void> emailAction(BuildContext context, String email) async {
  try {
    if (await launchUrl(Uri(scheme: 'mailto', path: email))) return;
  } catch (_) {
    // Desktop devices may not have a registered email application.
  }
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email application could open this address.'),
      ),
    );
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
          key != 'logo_blob' &&
          key != 'custom_tags_json' &&
          key != 'additional_phones_json' &&
          key != 'additional_emails_json',
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
  late final List<_PhoneDraft> _additionalPhones =
      ContactPhoneNumber.decodeMany(
        widget.values['additional_phones_json'],
      ).map((phone) => _PhoneDraft(phone.label, phone.number)).toList();
  late final List<_EmailDraft> _additionalEmails =
      ContactEmailAddress.decodeMany(
        widget.values['additional_emails_json'],
      ).map((email) => _EmailDraft(email.label, email.address)).toList();
  late List<int> _selectedCustomTagIds = decodeIntList(
    widget.values['custom_tags_json'],
  ).where((id) => widget.tagDefinitions.any((tag) => tag.id == id)).toList();
  late Uint8List? _photoBytes = _readPhotoBytes(
    widget.values[widget.organizationForm ? 'logo_blob' : 'photo_blob'],
  );
  late String? _photoPath = widget.organizationForm
      ? null
      : widget.values['photo_path'] as String?;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final phone in _additionalPhones) {
      phone.dispose();
    }
    for (final email in _additionalEmails) {
      email.dispose();
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
    if (entry.key == 'photo_blob' || entry.key == 'logo_blob') {
      return _photoField(entry.value, isLogo: entry.key == 'logo_blob');
    }
    if (entry.key == 'custom_tags_json') return _customTagsField(entry.value);
    if (entry.key == 'phone' && !widget.organizationForm) {
      return _primaryPhoneField();
    }
    if (entry.key == 'additional_phones_json' && !widget.organizationForm) {
      return _additionalPhonesField(entry.value);
    }
    if (entry.key == 'email' && !widget.organizationForm) {
      return _primaryEmailField();
    }
    if (entry.key == 'additional_emails_json' && !widget.organizationForm) {
      return _additionalEmailsField(entry.value);
    }

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
      textCapitalization: switch (entry.key) {
        'email' || 'phone' => TextCapitalization.none,
        'first_name' ||
        'last_name' ||
        'spouse_name' ||
        'title' ||
        'name' ||
        'industry' => TextCapitalization.words,
        _ => TextCapitalization.sentences,
      },
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
      inputFormatters: _formattersFor(entry.key),
      validator: (value) {
        final text = value?.trim() ?? '';
        final maxCharacters = _maxCharactersFor(entry.key);
        if (maxCharacters != null && text.length > maxCharacters) {
          return 'Use $maxCharacters characters or fewer.';
        }
        if (widget.organizationForm && entry.key == 'industry') {
          if (text.isEmpty) return 'Industry is required.';
          if (text.length < 2) return 'Enter at least 2 characters.';
        }
        if (entry.key == 'phone' &&
            text.isNotEmpty &&
            phoneDigits(text).length != 10) {
          return 'Enter a 10-digit phone number.';
        }
        if (['name', 'first_name', 'last_name'].contains(entry.key) &&
            text.isEmpty) {
          return 'Required';
        }
        if (_personNameKeys.contains(entry.key) &&
            text.isNotEmpty &&
            !_isPersonName(text)) {
          return 'Use letters, spaces, hyphens, or apostrophes only.';
        }
        if (entry.key == 'email' &&
            ((widget.organizationForm && text.isEmpty) || text.isNotEmpty) &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return widget.organizationForm && text.isEmpty
              ? 'Email address is required.'
              : 'Enter an email with one @ and a dot.';
        }
        return null;
      },
    );
  }

  Widget _primaryPhoneField() {
    final selectedLabel = _dropdownValues['phone_label']?.isNotEmpty == true
        ? _dropdownValues['phone_label']!
        : 'Mobile';
    final labels = [..._contactPhoneLabels];
    if (!labels.contains(selectedLabel)) labels.add(selectedLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primary phone', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: selectedLabel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final label in labels)
                    DropdownMenuItem(value: label, child: Text(label)),
                ],
                onChanged: (value) => setState(
                  () => _dropdownValues['phone_label'] = value ?? 'Mobile',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _controllers['phone'],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: _formattersFor('phone'),
                validator: _validatePhone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _additionalPhonesField(String fieldLabel) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              fieldLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(
              () => _additionalPhones.add(_PhoneDraft('Mobile', '')),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add number'),
          ),
        ],
      ),
      if (_additionalPhones.isEmpty)
        Text(
          'No additional phone numbers',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      for (var index = 0; index < _additionalPhones.length; index++) ...[
        if (index > 0) const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _additionalPhones[index].label,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final label in _contactPhoneLabels)
                    DropdownMenuItem(value: label, child: Text(label)),
                ],
                onChanged: (value) => setState(
                  () => _additionalPhones[index].label = value ?? 'Other',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _additionalPhones[index].controller,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: _formattersFor('phone'),
                validator: _validatePhone,
              ),
            ),
            IconButton(
              tooltip: 'Remove phone number',
              onPressed: () => setState(() {
                _additionalPhones.removeAt(index).dispose();
              }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _primaryEmailField() {
    final selectedLabel = _dropdownValues['email_label']?.isNotEmpty == true
        ? _dropdownValues['email_label']!
        : 'Primary';
    final labels = [..._contactEmailLabels];
    if (!labels.contains(selectedLabel)) labels.add(selectedLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primary email', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: selectedLabel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final label in labels)
                    DropdownMenuItem(value: label, child: Text(label)),
                ],
                onChanged: (value) => setState(
                  () => _dropdownValues['email_label'] = value ?? 'Primary',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _controllers['email'],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                inputFormatters: _formattersFor('email'),
                validator: _validateEmailAddress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _additionalEmailsField(String fieldLabel) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              fieldLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                setState(() => _additionalEmails.add(_EmailDraft('Work', ''))),
            icon: const Icon(Icons.add),
            label: const Text('Add address'),
          ),
        ],
      ),
      if (_additionalEmails.isEmpty)
        Text(
          'No additional email addresses',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      for (var index = 0; index < _additionalEmails.length; index++) ...[
        if (index > 0) const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _additionalEmails[index].label,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final label in _contactEmailLabels)
                    DropdownMenuItem(value: label, child: Text(label)),
                ],
                onChanged: (value) => setState(
                  () => _additionalEmails[index].label = value ?? 'Other',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _additionalEmails[index].controller,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                inputFormatters: _formattersFor('email'),
                validator: _validateEmailAddress,
              ),
            ),
            IconButton(
              tooltip: 'Remove email address',
              onPressed: () => setState(() {
                _additionalEmails.removeAt(index).dispose();
              }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
      ],
    ],
  );

  bool _hasContactMethod() =>
      (_controllers['phone']?.text.trim().isNotEmpty ?? false) ||
      _additionalPhones.any(
        (phone) => phone.controller.text.trim().isNotEmpty,
      ) ||
      (_controllers['email']?.text.trim().isNotEmpty ?? false) ||
      _additionalEmails.any((email) => email.controller.text.trim().isNotEmpty);

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

  Widget _photoField(String title, {bool isLogo = false}) {
    final bytes = _photoBytes;
    final path = _photoPath;
    Widget preview;
    if (bytes != null && bytes.isNotEmpty) {
      preview = Image.memory(
        bytes,
        width: isLogo ? 120 : 88,
        height: isLogo ? 88 : 88,
        fit: isLogo ? BoxFit.contain : BoxFit.cover,
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
      preview = SizedBox(
        width: isLogo ? 120 : 88,
        height: 88,
        child: Icon(
          isLogo ? Icons.business_outlined : Icons.person_outline,
          size: 44,
        ),
      );
    }
    final framedPreview = isLogo
        ? Container(
            width: 120,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: preview,
            ),
          )
        : ClipOval(child: preview);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          framedPreview,
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _selectPhoto,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    isLogo
                        ? bytes == null
                              ? 'Choose logo'
                              : 'Replace logo'
                        : bytes == null
                        ? 'Choose photo'
                        : 'Replace photo',
                  ),
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
                if (!widget.organizationForm)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter at least one phone number or email address.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                  if (!widget.organizationForm && !_hasContactMethod()) {
                    setState(
                      () => _error =
                          'Enter at least one phone number or email address.',
                    );
                    return;
                  }
                  final result = Map<String, Object?>.of(widget.values);
                  for (final entry in _controllers.entries) {
                    final text = entry.value.text.trim();
                    result[entry.key] =
                        entry.key == 'email' || entry.key == 'phone'
                        ? text
                        : capitalizeInitial(text);
                  }
                  result.addAll(_dropdownValues);
                  if (!widget.organizationForm) {
                    result['organization_id'] = _organizationId;
                    result['status'] = _status.name;
                    result['additional_phones_json'] = jsonEncode([
                      for (final phone in _additionalPhones)
                        if (phone.controller.text.trim().isNotEmpty)
                          ContactPhoneNumber(
                            label: phone.label,
                            number: phone.controller.text.trim(),
                          ).toMap(),
                    ]);
                    result['additional_emails_json'] = jsonEncode([
                      for (final email in _additionalEmails)
                        if (email.controller.text.trim().isNotEmpty)
                          ContactEmailAddress(
                            label: email.label,
                            address: email.controller.text.trim(),
                          ).toMap(),
                    ]);
                    result['children_json'] = jsonEncode(
                      _children.map((child) => child.toMap()).toList(),
                    );
                    result['custom_tags_json'] = jsonEncode(
                      _selectedCustomTagIds,
                    );
                    result['photo_blob'] = _photoBytes;
                    result['photo_path'] = _photoPath;
                  } else {
                    result['logo_blob'] = _photoBytes;
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

class _PhoneDraft {
  _PhoneDraft(String label, String number)
    : label = label,
      controller = TextEditingController(text: formatPhoneForEditing(number));

  String label;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _EmailDraft {
  _EmailDraft(this.label, String address)
    : controller = TextEditingController(text: address);

  String label;
  final TextEditingController controller;

  void dispose() => controller.dispose();
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
            name: capitalizeInitial(row.name.text),
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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r"[\p{L} '\-]", unicode: true),
                  ),
                  LengthLimitingTextInputFormatter(35),
                ],
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.length > 35) {
                    return 'Use 35 characters or fewer.';
                  }
                  if (name.isNotEmpty && !_isPersonName(name)) {
                    return 'Use letters, spaces, hyphens, or apostrophes only.';
                  }
                  return null;
                },
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
  bool _showFollowUp = false;
  String? _error;
  final _key = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _followUpReason = TextEditingController();
  final _followUpDateText = TextEditingController();
  final _followUpTimeText = TextEditingController();
  final List<InteractionAttachment> _attachments = [];
  late String _type = widget.initialType;
  DateTime? _followUp;
  TimeOfDay? _followUpTime;

  @override
  void dispose() {
    _summary.dispose();
    _followUpReason.dispose();
    _followUpDateText.dispose();
    _followUpTimeText.dispose();
    super.dispose();
  }

  Future<void> _selectFollowUpDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _followUp ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 20),
    );
    if (!mounted || date == null) return;
    setState(() {
      _followUp = date;
      _followUpDateText.text = MaterialLocalizations.of(
        context,
      ).formatMediumDate(date);
      _followUpTime ??= const TimeOfDay(hour: 9, minute: 0);
      _followUpTimeText.text = _followUpTime!.format(context);
    });
  }

  Future<void> _selectFollowUpTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _followUpTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted || time == null) return;
    setState(() {
      _followUpTime = time;
      _followUpTimeText.text = time.format(context);
    });
  }

  void _toggleFollowUp() {
    setState(() {
      _showFollowUp = !_showFollowUp;
      if (_showFollowUp) {
        _followUpTime ??= const TimeOfDay(hour: 9, minute: 0);
        _followUpTimeText.text = _followUpTime!.format(context);
      } else {
        _followUp = null;
        _followUpTime = null;
        _followUpDateText.clear();
        _followUpTimeText.clear();
        _followUpReason.clear();
      }
    });
  }

  Future<void> _pickAttachments() async {
    try {
      final files = await openFiles();
      if (!mounted || files.isEmpty) return;
      final picked = <InteractionAttachment>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          picked.add(InteractionAttachment(fileName: file.name, bytes: bytes));
        }
      }
      if (!mounted) return;
      setState(() {
        _attachments.addAll(picked);
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read one or more selected files.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = math
        .max(0.0, math.min(960.0, viewport.width - 32))
        .toDouble();
    final dialogHeight = math
        .max(0.0, math.min(900.0, viewport.height - 32))
        .toDouble();

    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogHeight,
          ),
          child: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Log Interaction',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Form(
                      key: _key,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const Text(
                            'Record what happened. Opening a phone app does not confirm a completed call or sent text.',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            decoration: const InputDecoration(
                              labelText: 'Interaction type',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final type in InteractionLog.types)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _type = value ?? _type),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _summary,
                            minLines: 4,
                            maxLines: 10,
                            textCapitalization: TextCapitalization.sentences,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              labelText: 'Summary',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter a summary'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Attachments',
                              border: OutlineInputBorder(),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _saving ? null : _pickAttachments,
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Attach files'),
                                ),
                                if (_attachments.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text('No files attached.'),
                                  ),
                                for (
                                  var index = 0;
                                  index < _attachments.length;
                                  index++
                                )
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      attachmentIcon(
                                        _attachments[index].fileName,
                                      ),
                                    ),
                                    title: Text(
                                      _attachments[index].fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      formatAttachmentSize(
                                        _attachments[index].bytes.length,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Remove attachment',
                                      onPressed: _saving
                                          ? null
                                          : () => setState(
                                              () =>
                                                  _attachments.removeAt(index),
                                            ),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _toggleFollowUp,
                              icon: Icon(
                                _showFollowUp
                                    ? Icons.remove_circle_outline
                                    : Icons.add_alarm,
                              ),
                              label: Text(
                                _showFollowUp
                                    ? 'Remove follow-up'
                                    : 'Set follow-up (optional)',
                              ),
                            ),
                          ),
                          if (_showFollowUp) ...[
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final dateField = TextFormField(
                                  controller: _followUpDateText,
                                  readOnly: true,
                                  onTap: _selectFollowUpDate,
                                  decoration: const InputDecoration(
                                    labelText: 'Follow-up date',
                                    suffixIcon: Icon(Icons.calendar_month),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (_) =>
                                      _showFollowUp && _followUp == null
                                      ? 'Choose a date'
                                      : null,
                                );
                                final timeField = TextFormField(
                                  controller: _followUpTimeText,
                                  readOnly: true,
                                  onTap: _selectFollowUpTime,
                                  decoration: const InputDecoration(
                                    labelText: 'Follow-up time',
                                    suffixIcon: Icon(Icons.schedule),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (_) =>
                                      _showFollowUp && _followUpTime == null
                                      ? 'Choose a time'
                                      : null,
                                );
                                if (constraints.maxWidth < 560) {
                                  return Column(
                                    children: [
                                      dateField,
                                      const SizedBox(height: 12),
                                      timeField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: dateField),
                                    const SizedBox(width: 12),
                                    Expanded(child: timeField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _followUpReason,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                labelText: 'Reason for follow-up',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  _showFollowUp &&
                                      (value == null || value.trim().isEmpty)
                                  ? 'Enter a reason for the scheduled follow-up.'
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                if (!_key.currentState!.validate()) return;
                                final result = <String, Object?>{
                                  'type': _type,
                                  'summary': capitalizeInitial(_summary.text),
                                  'followUp': _showFollowUp ? _followUp : null,
                                  'followUpTime':
                                      !_showFollowUp || _followUpTime == null
                                      ? null
                                      : '${_followUpTime!.hour.toString().padLeft(2, '0')}:${_followUpTime!.minute.toString().padLeft(2, '0')}',
                                  'followUpReason': _showFollowUp
                                      ? capitalizeInitial(_followUpReason.text)
                                      : '',
                                  'attachments': List<InteractionAttachment>.of(
                                    _attachments,
                                  ),
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
                                  if (mounted) {
                                    setState(() {
                                      _saving = false;
                                      _error =
                                          'Save failed. Your summary and attachments are retained. Please try again.';
                                    });
                                  }
                                }
                              },
                        child: Text(_saving ? 'Saving…' : 'Save interaction'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
