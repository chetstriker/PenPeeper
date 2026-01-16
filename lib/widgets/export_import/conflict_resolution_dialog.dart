import 'package:flutter/material.dart';
import 'package:penpeeper/services/export_import/conflict_resolver.dart';

class ConflictResolutionDialog extends StatefulWidget {
  final List<ProjectConflict> conflicts;

  const ConflictResolutionDialog({super.key, required this.conflicts});

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  final Map<String, ConflictResolution> _resolutions = {};

  @override
  void initState() {
    super.initState();
    for (final conflict in widget.conflicts) {
      _resolutions[conflict.projectName] = ConflictResolution.replace;
    }
  }

  bool _canProceed() {
    return _resolutions.length == widget.conflicts.length;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve Conflicts'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following projects already exist. Choose how to proceed:'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.conflicts.length,
                itemBuilder: (context, index) {
                  final conflict = widget.conflicts[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conflict.projectName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Existing: ${conflict.existingUpdatedAt}'),
                          Text('Import: ${conflict.importUpdatedAt}'),
                          const SizedBox(height: 8),
                          RadioListTile<ConflictResolution>(
                            title: const Text('Cancel (skip)'),
                            value: ConflictResolution.cancel,
                            groupValue: _resolutions[conflict.projectName],
                            onChanged: (value) {
                              setState(() => _resolutions[conflict.projectName] = value!);
                            },
                          ),
                          RadioListTile<ConflictResolution>(
                            title: const Text('Replace existing'),
                            value: ConflictResolution.replace,
                            groupValue: _resolutions[conflict.projectName],
                            onChanged: (value) {
                              setState(() => _resolutions[conflict.projectName] = value!);
                            },
                          ),
                          RadioListTile<ConflictResolution>(
                            title: Text('Rename to "${conflict.projectName} (1)"'),
                            value: ConflictResolution.rename,
                            groupValue: _resolutions[conflict.projectName],
                            onChanged: (value) {
                              setState(() => _resolutions[conflict.projectName] = value!);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canProceed() ? () => Navigator.of(context).pop(_resolutions) : null,
          child: const Text('Proceed'),
        ),
      ],
    );
  }
}
