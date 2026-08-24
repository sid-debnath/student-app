import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/academic_class.dart';
import '../../models/student.dart';
import '../../widgets/async_body.dart';

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
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _editStudent,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: StreamBuilder<List<AcademicClass>>(
        stream: roster.watchClasses(),
        builder: (context, snapshot) {
          final classes = snapshot.data ?? [];
          final classId = classes.any((item) => item.id == _classId)
              ? _classId
              : (classes.isEmpty ? null : classes.first.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Classes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Teachers and parents see every class you add here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (classes.isEmpty)
                const Text('No classes yet. Tap + to add one (for example 10-A).')
              else
                ...[
                  for (final academicClass in classes)
                    Card(
                      color: academicClass.id == classId
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        title: Text(academicClass.label),
                        subtitle: Text('Year ${academicClass.year}'),
                        selected: academicClass.id == classId,
                        onTap: () => setState(() => _classId = academicClass.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit class',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editClass(existing: academicClass),
                            ),
                            IconButton(
                              tooltip: 'Delete class',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => runGuarded(
                                context,
                                () => roster.deleteClass(academicClass.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              const SizedBox(height: 24),
              Text(
                'Students',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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

  Future<void> _editClass({AcademicClass? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final section = TextEditingController(text: existing?.section ?? 'A');
    final year = TextEditingController(
      text: '${existing?.year ?? DateTime.now().year}',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New class' : 'Edit class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: '10',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: section,
              decoration: const InputDecoration(
                labelText: 'Section',
                hintText: 'A',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final className = name.text.trim();
    final classSection = section.text.trim();
    final classYear = int.tryParse(year.text) ?? DateTime.now().year;
    name.dispose();
    section.dispose();
    year.dispose();
    if (!mounted || saved != true || className.isEmpty) return;
    await runGuarded(context, () {
      return ref.read(rosterRepositoryProvider)!.upsertClass(
        AcademicClass(
          id: existing?.id ?? '',
          name: className,
          section: classSection,
          year: classYear,
          teacherIds: existing?.teacherIds ?? const [],
        ),
      );
    });
  }

  Future<void> _editStudent() async {
    final classId = await ref.read(rosterRepositoryProvider)?.selectedOrFirstClassId(_classId);
    if (!mounted || classId == null) return;
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
    final studentName = name.text.trim();
    final studentRoll = roll.text.trim();
    name.dispose();
    roll.dispose();
    if (!mounted || saved != true || studentName.isEmpty) return;
    await runGuarded(context, () {
      return ref.read(rosterRepositoryProvider)!.upsertStudent(
        Student(id: '', name: studentName, classId: classId, roll: studentRoll),
      );
    });
  }
}
