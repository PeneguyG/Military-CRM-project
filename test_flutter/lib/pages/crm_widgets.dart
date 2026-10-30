import 'dart:io';
import 'package:flutter/material.dart';
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
  const InfoCard(this.title, this.text, {super.key});
  final String title, text;
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
        ],
      ),
    ),
  );
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
    this.organizations,
    this.contactStatus,
    this.organizationId,
    this.onSave,
    this.organizationForm = false,
  });
  final String title;
  final Map<String, Object?> values;
  final Map<String, String> fields;
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
    for (final key in widget.fields.keys)
      key: TextEditingController(
        text: key == 'phone'
            ? formatPhoneForEditing(widget.values[key] as String? ?? '')
            : widget.values[key] as String? ?? '',
      ),
  };
  late int? _organizationId = widget.organizationId;
  late ContactStatus _status = widget.contactStatus ?? ContactStatus.active;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
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
                    child: TextFormField(
                      controller: _controllers[entry.key],
                      decoration: InputDecoration(
                        labelText: entry.value,
                        border: const OutlineInputBorder(),
                      ),
                      minLines:
                          entry.key == 'notes' || entry.key == 'talking_points'
                          ? 3
                          : 1,
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
                        if ([
                              'name',
                              'first_name',
                              'last_name',
                            ].contains(entry.key) &&
                            text.isEmpty)
                          return 'Required';
                        if (entry.key == 'email' &&
                            text.isNotEmpty &&
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(text))
                          return 'Enter a valid email address';
                        return null;
                      },
                    ),
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
                  if (!widget.organizationForm) {
                    result['organization_id'] = _organizationId;
                    result['status'] = _status.name;
                    if (result['photo_path'] == '') result['photo_path'] = null;
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
                    if (mounted && date != null)
                      setState(() => _followUp = date);
                  },
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
