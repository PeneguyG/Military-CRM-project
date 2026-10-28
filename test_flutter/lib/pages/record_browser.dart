import 'package:flutter/material.dart';

/// Mobile details are real routes; store listeners inside details keep them live.
class RecordBrowser extends StatelessWidget {
  const RecordBrowser({
    super.key,
    required this.filters,
    required this.list,
    required this.detail,
    required this.onAdd,
  });
  final Widget filters, list, detail;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                filters,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add record'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: constraints.maxWidth >= 850
                ? Row(
                    children: [
                      SizedBox(width: 320, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(child: detail),
                    ],
                  )
                : list,
          ),
        ],
      );
    },
  );
}

Future<void> openDetail(
  BuildContext context,
  Widget detail,
  String title,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: detail),
      ),
    ),
  );
}
