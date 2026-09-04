import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/ptm.dart';
import '../../widgets/async_body.dart';

class PtmScreen extends ConsumerWidget {
  const PtmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final repo = ref.watch(ptmRepositoryProvider);
    if (session == null || repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final studentId = session.isViewer
        ? (ref.watch(selectedStudentIdProvider) ?? session.studentIds.firstOrNull)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Parent-teacher meetings')),
      floatingActionButton: session.isStaff || session.isAdmin
          ? FloatingActionButton(
              onPressed: () => _addSlot(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Slots', style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder<List<PtmSlot>>(
            stream: repo.watchSlots(teacherId: session.isStaff ? session.id : null),
            builder: (context, snapshot) {
              final slots = snapshot.data ?? [];
              if (slots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No slots yet.'),
                );
              }
              return Column(
                children: [
                  for (final slot in slots)
                    ListTile(
                      title: Text(slot.teacherName),
                      subtitle: Text(
                        '${DateFormat.yMMMd().add_jm().format(slot.start)} · ${slot.bookedCount}/${slot.capacity}',
                      ),
                      trailing: session.isViewer
                          ? TextButton(
                              onPressed: slot.isFull || studentId == null
                                  ? null
                                  : () => runGuarded(
                                      context,
                                      () => repo.bookSlot(
                                        slot: slot,
                                        studentId: studentId,
                                        viewerId: session.id,
                                      ),
                                    ),
                              child: const Text('Book'),
                            )
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => runGuarded(context, () => repo.deleteSlot(slot.id)),
                            ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Meeting notes', style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder<List<PtmNote>>(
            stream: repo.watchNotes(studentId: studentId),
            builder: (context, snapshot) {
              final notes = snapshot.data ?? [];
              return Column(
                children: [
                  for (final note in notes)
                    Card(
                      child: ListTile(
                        title: Text(note.body),
                        subtitle: Text(
                          note.attachmentUrls.isEmpty
                              ? 'No attachments'
                              : '${note.attachmentUrls.length} attachment(s)',
                        ),
                      ),
                    ),
                  if (session.isStaff || session.isAdmin)
                    FilledButton(
                      onPressed: () => _addNote(context, ref, studentId),
                      child: const Text('Add note'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addSlot(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return;
    final start = DateTime.now().add(const Duration(days: 1, hours: 1));
    await runGuarded(context, () {
      return ref.read(ptmRepositoryProvider)!.upsertSlot(
        PtmSlot(
          id: '',
          teacherId: session.id,
          teacherName: session.displayName,
          start: start,
          end: start.add(const Duration(minutes: 20)),
        ),
      );
    });
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref, String? studentId) async {
    if (studentId == null) return;
    final body = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meeting note'),
        content: TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final files = await FilePicker.pickFiles();
    final file = files.firstOrNull;
    final session = ref.read(sessionProvider).valueOrNull;
    if (!context.mounted) return;
    await runGuarded(context, () async {
      return ref.read(ptmRepositoryProvider)!.addNote(
        note: PtmNote(
          id: '',
          bookingId: '',
          studentId: studentId,
          body: body.text.trim(),
          createdBy: session?.id,
        ),
        fileBytes: file == null ? null : await file.xFile.readAsBytes(),
        fileName: file?.name,
      );
    });
  }
}
