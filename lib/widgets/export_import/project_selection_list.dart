import 'package:flutter/material.dart';

class ProjectSelectionList extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final Set<int> selectedIds;
  final Function(int, bool) onSelectionChanged;

  const ProjectSelectionList({
    super.key,
    required this.projects,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final id = project['id'] as int;
        final isSelected = selectedIds.contains(id);

        return CheckboxListTile(
          title: Text(project['name'] as String),
          subtitle: Text('Updated: ${project['updated_at']}'),
          value: isSelected,
          onChanged: (value) => onSelectionChanged(id, value ?? false),
        );
      },
    );
  }
}
