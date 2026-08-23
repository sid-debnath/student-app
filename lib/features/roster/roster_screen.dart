import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/school_class.dart';
import '../../models/student.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_dropdown.dart';

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterRepositoryProvider);
    if (roster == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roster'),
        actions: [
          IconButton(
            tooltip: 'Add class',
            onPressed: () => _editClass(),
            icon: const Icon(Icons.class_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _classId == null ? null : _editStudent,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: StreamBuilder<List<SchoolClass>>(
        stream: roster.watchClasses(),
        builder: (context, snapshot) {
          final classes = snapshot.data ?? [];
          final classId = _classId ?? (classes.isEmpty ? null : classes.first.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClassDropdown(
                classes: classes,
                value: classId,
                onChanged: (value) => setState(() => _classId = value),
              ),
              const SizedBox(height: 16),
              if (classId == null)
                const Text('Create a class to add students.')
              else
                StreamBuilder<List<Student>>(
                  stream: roster.watchStudents(classId: classId),
                  builder: (context, studentSnap) {
                    final students = studentSnap.data ?? [];
                    if (students.isEmpty) {
                      return const Text('No students in this class yet.');
                    }
                    return Column(
                      children: [
                        for (final student in students)
                          ListTile(
                            title: Text(student.name),
                            subtitle: Text('Roll ${student.roll}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => runGuarded(
                                context,
                                () => roster.deleteStudent(student.id),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editClass() async {
    final name = TextEditingController();
    final section = TextEditingController(text: 'A');
    final year = TextEditingController(text: '${DateTime.now().year}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: section, decoration: const InputDecoration(labelText: 'Section')),
            const SizedBox(height: 8),
            TextField(controller: year, decoration: const InputDecoration(labelText: 'Year')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await runGuarded(context, () {
      return ref.read(rosterRepositoryProvider)!.upsertClass(
        SchoolClass(
          id: '',
          name: name.text.trim(),
          section: section.text.trim(),
          year: int.tryParse(year.text) ?? DateTime.now().year,
        ),
      );
    });
  }

  Future<void> _editStudent() async {
    final classId = _classId;
    if (classId == null) return;
    final name = TextEditingController();
    final roll = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: roll, decoration: const InputDecoration(labelText: 'Roll')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await runGuarded(context, () {
      return ref.read(rosterRepositoryProvider)!.upsertStudent(
        Student(id: '', name: name.text.trim(), classId: classId, roll: roll.text.trim()),
      );
    });
  }
}
