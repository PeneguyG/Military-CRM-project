import 'package:flutter/material.dart';

import '../crm_store.dart';
import '../models/crm_models.dart';
import 'crm_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.isDarkMode,
    required this.automaticTheme,
    required this.onToggleTheme,
    required this.onAutomaticThemeChanged,
    required this.use24HourFormat,
    required this.onTimeFormatChanged,
    required this.onDatabaseLocation,
  });

  final CrmStore store;
  final bool isDarkMode;
  final bool automaticTheme;
  final VoidCallback onToggleTheme;
  final ValueChanged<bool> onAutomaticThemeChanged;
  final bool? use24HourFormat;
  final ValueChanged<bool?> onTimeFormatChanged;
  final VoidCallback onDatabaseLocation;

  Future<void> _addTag(BuildContext context) async {
    final draft = await showDialog<ProfileTagDefinition>(
      context: context,
      builder: (_) => const _CreateTagDialog(),
    );
    if (draft == null || !context.mounted) return;
    await runDatabaseAction(context, () => store.saveProfileTag(draft));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                value: isDarkMode,
                onChanged: (_) => onToggleTheme(),
              ),
              SwitchListTile(
                title: const Text('Follow device appearance'),
                subtitle: const Text('Match the device light or dark theme.'),
                value: automaticTheme,
                onChanged: onAutomaticThemeChanged,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: use24HourFormat == null
                      ? 'device'
                      : use24HourFormat!
                      ? '24'
                      : '12',
                  decoration: const InputDecoration(labelText: 'Time format'),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'device',
                      child: Text('Use device preference'),
                    ),
                    DropdownMenuItem(value: '12', child: Text('12-hour time')),
                    DropdownMenuItem(value: '24', child: Text('24-hour time')),
                  ],
                  onChanged: (value) => onTimeFormatChanged(switch (value) {
                    '12' => false,
                    '24' => true,
                    _ => null,
                  }),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dates and times use this device’s local timezone.',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Database location'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onDatabaseLocation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SoundexSamplesCard(store: store),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile tags',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create extra tags and choose the colors used on contact profiles.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _addTag(context),
              icon: const Icon(Icons.add),
              label: const Text('New tag'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (store.profileTags.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No profile tags have been configured.'),
            ),
          ),
        for (final tag in store.profileTags)
          _ProfileTagSetting(tag: tag, store: store),
      ],
    ),
  );
}

class _TagColorChoice {
  const _TagColorChoice(this.name, this.value);
  final String name;
  final int value;
}

const _tagColors = <_TagColorChoice>[
  _TagColorChoice('Blue', 0xFF1565C0),
  _TagColorChoice('Purple', 0xFF6A1B9A),
  _TagColorChoice('Teal', 0xFF00796B),
  _TagColorChoice('Orange', 0xFFB45309),
  _TagColorChoice('Green', 0xFF2E7D32),
  _TagColorChoice('Red', 0xFFC62828),
  _TagColorChoice('Gray', 0xFF616161),
];

class _ProfileTagSetting extends StatelessWidget {
  const _ProfileTagSetting({required this.tag, required this.store});

  final ProfileTagDefinition tag;
  final CrmStore store;

  String get _categoryLabel => switch (tag.category) {
    'preferred_contact' => 'Preferred contact',
    'life_status' => 'Life status',
    _ => 'Custom tag',
  };

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = ContactProfileTag(
            label: tag.label,
            color: Color(tag.colorValue),
          );
          final colorPicker = DropdownButtonFormField<int>(
            initialValue:
                _tagColors.any((color) => color.value == tag.colorValue)
                ? tag.colorValue
                : _tagColors.last.value,
            decoration: const InputDecoration(
              labelText: 'Tag color',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final color in _tagColors)
                DropdownMenuItem(
                  value: color.value,
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(color.value), size: 18),
                      const SizedBox(width: 8),
                      Text(color.name),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              runDatabaseAction(
                context,
                () => store.saveProfileTag(tag.copyWith(colorValue: value)),
              );
            },
          );
          final remove = tag.category == 'custom' && tag.id != null
              ? IconButton(
                  tooltip: 'Delete tag',
                  onPressed: () => runDatabaseAction(
                    context,
                    () => store.deleteProfileTag(tag.id!),
                  ),
                  icon: const Icon(Icons.delete_outline),
                )
              : const SizedBox.shrink();

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _categoryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    remove,
                  ],
                ),
                const SizedBox(height: 12),
                colorPicker,
                const SizedBox(height: 8),
                preview,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _categoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(flex: 2, child: colorPicker),
              const SizedBox(width: 12),
              SizedBox(
                width: 168,
                child: Align(alignment: Alignment.topLeft, child: preview),
              ),
              SizedBox(width: 48, child: remove),
            ],
          );
        },
      ),
    ),
  );
}

class _CreateTagDialog extends StatefulWidget {
  const _CreateTagDialog();

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  final _key = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  int _colorValue = _tagColors[0].value;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create profile tag'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _labelController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tag name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a tag name'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _colorValue,
              decoration: const InputDecoration(
                labelText: 'Tag color',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final color in _tagColors)
                  DropdownMenuItem(
                    value: color.value,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Color(color.value), size: 18),
                        const SizedBox(width: 8),
                        Text(color.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _colorValue = value ?? _colorValue),
            ),
          ],
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
          final now = DateTime.now().microsecondsSinceEpoch;
          Navigator.pop(
            context,
            ProfileTagDefinition(
              category: 'custom',
              value: 'custom-$now',
              label: _labelController.text.trim(),
              colorValue: _colorValue,
            ),
          );
        },
        child: const Text('Create tag'),
      ),
    ],
  );
}

class _SoundexSamplesCard extends StatefulWidget {
  const _SoundexSamplesCard({required this.store});
  final CrmStore store;
  @override
  State<_SoundexSamplesCard> createState() => _SoundexSamplesCardState();
}

class _SoundexSamplesCardState extends State<_SoundexSamplesCard> {
  bool _loading = false;
  String? _message;
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.store.loadSoundexSamples();
      if (mounted)
        setState(
          () => _message =
              'Sample data is ready. Repeated loads do not duplicate records.',
        );
    } catch (error) {
      if (mounted)
        setState(() => _message = 'Could not load sample data: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sample data?'),
        content: const Text(
          'This removes the demo organizations and contacts, along with their notes, interactions, and attachments. Any other contacts assigned to a demo organization will become unassigned. Your other records will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete sample data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.store.deleteSoundexSamples();
      if (mounted) {
        setState(() => _message = 'Sample data cleanup completed.');
      }
    } catch (error) {
      if (mounted)
        setState(() => _message = 'Could not delete sample data: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soundex sample data',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add 3 fictional organizations and 6 complete contact profiles, with family details, rich-text notes, and follow-ups. Existing records are preserved.',
          ),
          const SizedBox(height: 8),
          const SelectableText(
            'Try: Smyth → Smith · Ashcroft → Ashcraft · Fister → Pfister · Jaxon → Jackson · Rupert → Robert',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.science_outlined),
                label: Text(_loading ? 'Loading…' : 'Load sample data'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _delete,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Delete sample data'),
              ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!),
            ),
        ],
      ),
    ),
  );
}
