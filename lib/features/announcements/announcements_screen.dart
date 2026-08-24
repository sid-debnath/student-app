import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
    final canManage = session.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _edit(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<Announcement>>(
        stream: repo.watch(),
        builder: (context, snapshot) {
          final items = (snapshot.data ?? []).where((item) {
            return item.visibleTo(
              isAdmin: session.isAdmin,
              isTeacher: session.isTeacher,
              isViewer: session.isViewer,
            );
          }).toList();
          if (items.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
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
                          '${item.audienceLabel}'
                          '${item.createdAt == null ? '' : ' · ${DateFormat.yMMMd().format(item.createdAt!)}'}\n'
                          '${item.body}',
                        ),
                        isThreeLine: true,
                        trailing: canManage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _edit(context, ref, existing: item),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => runGuarded(context, () => repo.delete(item.id)),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      for (final url in item.imageUrls)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _AnnouncementImage(url: url),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {Announcement? existing}) async {
    final draft = await showDialog<_AnnouncementDraft>(
      context: context,
      builder: (context) => _AnnouncementFormDialog(existing: existing),
    );
    if (draft == null || !context.mounted) return;
    final session = ref.read(sessionProvider).valueOrNull;
    await runGuarded(context, () {
      return ref.read(announcementRepositoryProvider)!.save(
        Announcement(
          id: existing?.id ?? '',
          title: draft.title,
          body: draft.body,
          audience: draft.audience,
          classIds: existing?.classIds ?? session?.classIds ?? const [],
          imageUrls: existing?.imageUrls ?? const [],
          createdBy: existing?.createdBy ?? session?.id,
        ),
        imageBytes: draft.imageBytes,
        imageName: draft.imageName,
      );
    });
  }
}

class _AnnouncementImage extends StatelessWidget {
  const _AnnouncementImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma < 0) return const SizedBox.shrink();
      try {
        final bytes = base64Decode(url.substring(comma + 1));
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url, fit: BoxFit.cover),
    );
  }
}

class _AnnouncementDraft {
  const _AnnouncementDraft({
    required this.title,
    required this.body,
    required this.audience,
    this.imageBytes,
    this.imageName,
  });

  final String title;
  final String body;
  final String audience;
  final Uint8List? imageBytes;
  final String? imageName;
}

class _AnnouncementFormDialog extends StatefulWidget {
  const _AnnouncementFormDialog({this.existing});

  final Announcement? existing;

  @override
  State<_AnnouncementFormDialog> createState() => _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _audience = 'both';
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _body.text = existing.body;
      _audience = existing.audience == 'all' ? 'both' : existing.audience;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final file = files.firstOrNull;
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
    });
  }

  void _publish() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _AnnouncementDraft(
        title: _title.text.trim(),
        body: _body.text.trim(),
        audience: _audience,
        imageBytes: _imageBytes,
        imageName: _imageName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit announcement' : 'New announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 16),
            Text('Audience', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'teachers', label: Text('Teachers')),
                ButtonSegment(value: 'students', label: Text('Students')),
                ButtonSegment(value: 'both', label: Text('Both')),
              ],
              selected: {_audience},
              onSelectionChanged: (value) {
                setState(() => _audience = value.first);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_imageName == null ? 'Upload image' : 'Change image'),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_imageBytes!, height: 120, fit: BoxFit.cover),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _publish, child: Text(isEdit ? 'Save' : 'Publish')),
      ],
    );
  }
}

