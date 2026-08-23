import 'package:flutter/material.dart';

import '../../models/academic_class.dart';

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
