import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/academic_class.dart';
import '../../widgets/async_body.dart';

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final roster = ref.watch(rosterRepositoryProvider);
    if (roster == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEditClasses = session?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Roster')),
      floatingActionButton: canEditClasses
          ? FloatingActionButton.extended(
              onPressed: () => _editClass(),
              icon: const Icon(Icons.add),
              label: const Text('Add class'),
            )
          : null,
      body: StreamBuilder<List<AcademicClass>>(
        stream: roster.watchClasses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(formatAppError(snapshot.error!)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final classes = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('Classes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Add and edit classes here. Add students from Invite users.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (!canEditClasses)
                const Text('Only an admin can add or edit classes.')
              else if (classes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No classes yet.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _editClass(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add class'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                for (final academicClass in classes)
                  Card(
                    child: ListTile(
                      title: Text(academicClass.label),
                      subtitle: Text('Year ${academicClass.year}'),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _editClass(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add another class'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editClass({AcademicClass? existing}) async {
    final result = await showDialog<_ClassDraft>(
      context: context,
      builder: (context) => _ClassFormDialog(existing: existing),
    );
    if (!mounted || result == null) return;
    await runGuarded(context, () async {
      await ref.read(rosterRepositoryProvider)!.upsertClass(
        AcademicClass(
          id: existing?.id ?? '',
          name: result.name,
          section: result.section,
          year: result.year,
          teacherIds: existing?.teacherIds ?? const [],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Class ${result.label} added.' : 'Class ${result.label} updated.',
          ),
        ),
      );
    });
  }
}

class _ClassDraft {
  const _ClassDraft({required this.name, required this.section, required this.year});

  final String name;
  final String section;
  final int year;

  String get label => section.isEmpty ? name : '$name-$section';
}

class _ClassFormDialog extends StatefulWidget {
  const _ClassFormDialog({this.existing});

  final AcademicClass? existing;

  @override
  State<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<_ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _section;
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _section = TextEditingController(text: widget.existing?.section ?? '');
    _year = TextEditingController(text: '${widget.existing?.year ?? DateTime.now().year}');
  }

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _year.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _ClassDraft(
        name: _name.text.trim(),
        section: _section.text.trim(),
        year: int.tryParse(_year.text) ?? DateTime.now().year,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New class' : 'Edit class'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Class name',
                  hintText: '10-A',
                  helperText: 'What everyone will see, for example 10-A or Grade 5.',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a class name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _section,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  hintText: 'A',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Year'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
