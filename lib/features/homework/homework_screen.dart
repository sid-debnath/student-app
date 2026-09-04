import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../data/homework_repository.dart';
import '../../models/homework.dart';
import '../../models/homework_file.dart';
import '../../models/academic_class.dart';
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
    final canEdit = session.isAdmin || session.isStaff;

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _edit(),
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
                    : 'No classes yet. Ask an admin to add one on Roster.',
                onChanged: (value) => setState(() => _classId = value),
              ),
              if (classId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    session.isViewer
                        ? 'Homework will show here after an admin enrolls you in a class.'
                        : 'No classes yet. Ask an admin to add one on Roster.',
                  ),
                )
              else
                StreamBuilder<List<Homework>>(
                  stream: homework.watch(classId: classId),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(formatAppError(snap.error!)),
                      );
                    }
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
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(item.title),
                                  subtitle: Text(
                                    '${item.subject} · due ${DateFormat.yMMMd().format(item.dueDate)}\n${item.body}',
                                  ),
                                  isThreeLine: true,
                                  trailing: canEdit
                                      ? PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _edit(existing: item);
                                            } else if (value == 'delete') {
                                              runGuarded(context, () => homework.delete(item.id));
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                                          ],
                                        )
                                      : null,
                                ),
                                StreamBuilder<List<HomeworkFile>>(
                                  stream: homework.watchFiles(item.id),
                                  builder: (context, fileSnap) {
                                    if (fileSnap.hasError) {
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Text(formatAppError(fileSnap.error!)),
                                      );
                                    }
                                    final files = fileSnap.data ?? [];
                                    final urls = item.attachmentUrls;
                                    if (files.isEmpty && urls.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Column(
                                        children: [
                                          for (final file in files)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: _HomeworkFileView(
                                                file: file,
                                                onDelete: canEdit
                                                    ? () => runGuarded(
                                                          context,
                                                          () => homework.deleteFile(item.id, file.id),
                                                        )
                                                    : null,
                                              ),
                                            ),
                                          for (final url in urls)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: _LegacyMedia(url: url),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
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

  Future<void> _edit({Homework? existing}) async {
    final classId = existing?.classId ??
        await ref.read(rosterRepositoryProvider)?.selectedOrFirstClassId(_classId);
    if (!mounted || classId == null) return;
    final draft = await showDialog<_HomeworkDraft>(
      context: context,
      builder: (context) => _HomeworkFormDialog(existing: existing),
    );
    if (!mounted || draft == null) return;
    await runGuarded(context, () async {
      final skipped = await ref.read(homeworkRepositoryProvider)!.upsert(
        Homework(
          id: existing?.id ?? '',
          classId: classId,
          subject: draft.subject,
          title: draft.title,
          body: draft.body,
          dueDate: draft.dueDate,
          attachmentUrls: existing?.attachmentUrls ?? const [],
          createdBy: existing?.createdBy ?? ref.read(sessionProvider).valueOrNull?.id,
        ),
        files: draft.files,
      );
      if (!mounted) return;
      if (skipped.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Homework posted.' : 'Homework updated.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved, but these files could not be attached: ${skipped.join(', ')}',
          ),
        ),
      );
    });
  }
}

class _HomeworkFileView extends StatelessWidget {
  const _HomeworkFileView({required this.file, this.onDelete});

  final HomeworkFile file;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget child = const SizedBox.shrink();
    if (file.isImage && file.data != null && file.data!.isNotEmpty) {
      try {
        final bytes = base64Decode(file.data!);
        child = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const Text('Could not show image'),
          ),
        );
      } catch (_) {
        child = const Text('Could not show image');
      }
    } else if (file.url != null && file.url!.isNotEmpty) {
      if (file.isImage) {
        child = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            file.url!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const Text('Could not show image'),
          ),
        );
      } else {
        child = OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(file.url!), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Open video'),
        );
      }
    }
    if (onDelete == null) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove file',
          ),
        ),
      ],
    );
  }
}

class _LegacyMedia extends StatelessWidget {
  const _LegacyMedia({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma < 0) return const SizedBox.shrink();
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(url.substring(comma + 1)),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    final lower = url.toLowerCase();
    final isImage = lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.gif') ||
        lower.contains('.webp');
    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(url, height: 220, width: double.infinity, fit: BoxFit.cover),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.play_circle_outline),
      label: const Text('Open video'),
    );
  }
}

class _HomeworkDraft {
  const _HomeworkDraft({
    required this.title,
    required this.subject,
    required this.body,
    required this.dueDate,
    required this.files,
  });

  final String title;
  final String subject;
  final String body;
  final DateTime dueDate;
  final List<HomeworkAttachment> files;
}

class _HomeworkFormDialog extends StatefulWidget {
  const _HomeworkFormDialog({this.existing});

  final Homework? existing;

  @override
  State<_HomeworkFormDialog> createState() => _HomeworkFormDialogState();
}

class _HomeworkFormDialogState extends State<_HomeworkFormDialog> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _files = <HomeworkAttachment>[];
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _subject.text = existing.subject;
      _body.text = existing.body;
      _dueDate = existing.dueDate;
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'webm', 'm4v'],
    );
    if (picked.isEmpty) return;
    final next = <HomeworkAttachment>[];
    for (final file in picked) {
      next.add(
        HomeworkAttachment(bytes: await file.xFile.readAsBytes(), fileName: file.name),
      );
    }
    if (!mounted) return;
    setState(() => _files.addAll(next));
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _HomeworkDraft(
        title: _title.text.trim(),
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        dueDate: _dueDate,
        files: List.of(_files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit homework' : 'New homework'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Due ${DateFormat.yMMMd().format(_dueDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.attach_file),
              label: Text(isEdit ? 'Add images or videos' : 'Add images or videos'),
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final file in _files)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    file.fileName.toLowerCase().endsWith('.mp4') ||
                            file.fileName.toLowerCase().endsWith('.mov') ||
                            file.fileName.toLowerCase().endsWith('.webm')
                        ? Icons.videocam_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(file.fileName, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _files.remove(file)),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(isEdit ? 'Save' : 'Post')),
      ],
    );
  }
}
