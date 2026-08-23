import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/homework.dart';
import '../../models/school_class.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_dropdown.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final roster = ref.watch(rosterRepositoryProvider);
    final homework = ref.watch(homeworkRepositoryProvider);
    if (session == null || roster == null || homework == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEdit = session.isAdmin || session.isTeacher;

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _create(),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<SchoolClass>>(
        stream: roster.watchClasses(onlyIds: session.isTeacher ? session.classIds : null),
        builder: (context, classSnap) {
          final classes = classSnap.data ?? [];
          final classId = _classId ?? (classes.isEmpty ? null : classes.first.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!session.isViewer)
                ClassDropdown(
                  classes: classes,
                  value: classId,
                  onChanged: (value) => setState(() => _classId = value),
                ),
              StreamBuilder<List<Homework>>(
                stream: homework.watch(classId: session.isViewer ? null : classId),
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text('No homework yet.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items)
                        Card(
                          child: ListTile(
                            title: Text(item.title),
                            subtitle: Text(
                              '${item.subject} · due ${DateFormat.yMMMd().format(item.dueDate)}\n${item.body}',
                            ),
                            isThreeLine: true,
                            trailing: canEdit
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => runGuarded(context, () => homework.delete(item.id)),
                                  )
                                : null,
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

  Future<void> _create() async {
    final classId = _classId;
    if (classId == null) return;
    final title = TextEditingController();
    final subject = TextEditingController();
    final body = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New homework'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 8),
            TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'Details')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post')),
        ],
      ),
    );
    if (saved != true) return;
    await runGuarded(context, () {
      return ref.read(homeworkRepositoryProvider)!.upsert(
        Homework(
          id: '',
          classId: classId,
          subject: subject.text.trim(),
          title: title.text.trim(),
          body: body.text.trim(),
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createdBy: ref.read(sessionProvider).valueOrNull?.id,
        ),
      );
    });
  }
}
