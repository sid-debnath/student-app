import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/announcement.dart';
import '../../widgets/async_body.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final repo = ref.watch(announcementRepositoryProvider);
    if (session == null || repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canPost = session.isAdmin || session.isTeacher;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: canPost
          ? FloatingActionButton(
              onPressed: () => _create(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<Announcement>>(
        stream: repo.watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.isInstitutionWide ? 'Institution' : 'Class'}'
                      '${item.createdAt == null ? '' : ' · ${DateFormat.yMMMd().format(item.createdAt!)}'}\n'
                      '${item.body}',
                    ),
                    isThreeLine: true,
                    trailing: canPost
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => runGuarded(context, () => repo.delete(item.id)),
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publish')),
        ],
      ),
    );
    if (saved != true) return;
    final session = ref.read(sessionProvider).valueOrNull;
    await runGuarded(context, () {
      return ref.read(announcementRepositoryProvider)!.create(
        Announcement(
          id: '',
          title: title.text.trim(),
          body: body.text.trim(),
          audience: 'all',
          classIds: session?.classIds ?? const [],
          createdBy: session?.id,
        ),
      );
    });
  }
}
