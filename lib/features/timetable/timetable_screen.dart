import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/academic_class.dart';
import '../../models/timetable_period.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_dropdown.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final roster = ref.watch(rosterRepositoryProvider);
    final timetable = ref.watch(timetableRepositoryProvider);
    if (session == null || roster == null || timetable == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEdit = session.isAdmin || session.isTeacher;

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _add(),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<AcademicClass>>(
        stream: roster.watchVisibleClasses(session),
        builder: (context, classSnap) {
          final classes = classSnap.data ?? [];
          final classId = classes.any((item) => item.id == _classId)
              ? _classId
              : (classes.isEmpty ? null : classes.first.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClassPicker(
                classes: classes,
                value: classId,
                emptyLabel: session.isViewer
                    ? 'No class is linked to this student account.'
                    : 'No classes yet.',
                onChanged: (value) => setState(() => _classId = value),
              ),
              const SizedBox(height: 12),
              if (classId != null)
                StreamBuilder<List<TimetablePeriod>>(
                  stream: timetable.watch(classId),
                  builder: (context, snap) {
                    final periods = snap.data ?? [];
                    if (periods.isEmpty) return const Text('No periods yet.');
                    return Column(
                      children: [
                        for (final period in periods)
                          ListTile(
                            title: Text(period.subject),
                            subtitle: Text(
                              '${weekdayLabels[period.weekday]} · ${period.start}–${period.end}'
                              '${period.teacherName == null ? '' : ' · ${period.teacherName}'}',
                            ),
                            trailing: canEdit
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => runGuarded(
                                      context,
                                      () => timetable.delete(classId, period.id),
                                    ),
                                  )
                                : null,
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

  Future<void> _add() async {
    final classId = await ref.read(rosterRepositoryProvider)?.selectedOrFirstClassId(_classId);
    if (!mounted || classId == null) return;
    final subject = TextEditingController();
    final start = TextEditingController(text: '09:00');
    final end = TextEditingController(text: '09:45');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 8),
            TextField(controller: start, decoration: const InputDecoration(labelText: 'Start (HH:mm)')),
            const SizedBox(height: 8),
            TextField(controller: end, decoration: const InputDecoration(labelText: 'End (HH:mm)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted || saved != true) return;
    final session = ref.read(sessionProvider).valueOrNull;
    await runGuarded(context, () {
      return ref.read(timetableRepositoryProvider)!.upsert(
        TimetablePeriod(
          id: '',
          classId: classId,
          weekday: DateTime.now().weekday,
          start: start.text.trim(),
          end: end.text.trim(),
          subject: subject.text.trim(),
          teacherId: session?.id,
          teacherName: session?.displayName,
        ),
      );
    });
  }
}
