import 'package:flutter/material.dart';

import '../models/academic_class.dart';

class ClassDropdown extends StatelessWidget {
  const ClassDropdown({
    super.key,
    required this.classes,
    required this.value,
    required this.onChanged,
  });

  final List<AcademicClass> classes;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: classes.any((item) => item.id == value) ? value : null,
      decoration: const InputDecoration(labelText: 'Class'),
      items: [
        for (final item in classes)
          DropdownMenuItem(value: item.id, child: Text(item.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class ClassPicker extends StatelessWidget {
  const ClassPicker({
    super.key,
    required this.classes,
    required this.value,
    required this.onChanged,
    this.canSwitch = true,
    this.emptyLabel = 'No class assigned.',
  });

  final List<AcademicClass> classes;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool canSwitch;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Text(emptyLabel);
    }
    if (!canSwitch || classes.length == 1) {
      final academicClass = classes.firstWhere(
        (item) => item.id == value,
        orElse: () => classes.first,
      );
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Class'),
        child: Text(academicClass.label),
      );
    }
    return ClassDropdown(
      key: ValueKey(value),
      classes: classes,
      value: value,
      onChanged: onChanged,
    );
  }
}
