import 'package:flutter/material.dart';

import '../models/academic_class.dart';

class ClassChips extends StatelessWidget {
  const ClassChips({
    super.key,
    required this.classes,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<AcademicClass> classes;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const Text('Add classes on the Roster tab first.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final academicClass in classes)
          FilterChip(
            label: Text(academicClass.label),
            selected: selectedIds.contains(academicClass.id),
            onSelected: (selected) {
              final next = {...selectedIds};
              if (selected) {
                next.add(academicClass.id);
              } else {
                next.remove(academicClass.id);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}
