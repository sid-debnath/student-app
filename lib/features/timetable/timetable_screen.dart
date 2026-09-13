import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/timetable_repository.dart';
import '../../models/academic_class.dart';
import '../../models/timetable_period.dart';
import '../../models/timetable_photo.dart';
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
    final canEdit = session.isAdmin || session.isStaff;
    // Only admins and floor in-charges upload/remove timetable photos.
    final canUpload = session.isAdmin || session.isFloorIncharge;

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
                          _PeriodTile(
                            period: period,
                            classId: classId,
                            timetable: timetable,
                            canUpload: canUpload,
                            canManagePeriod: canEdit,
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

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.period,
    required this.classId,
    required this.timetable,
    required this.canUpload,
    required this.canManagePeriod,
  });

  final TimetablePeriod period;
  final String classId;
  final TimetableRepository timetable;
  final bool canUpload;
  final bool canManagePeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(period.subject, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${weekdayLabels[period.weekday]} · '
                        '${period.start}–${period.end}'
                        '${period.teacherName == null ? '' : ' · ${period.teacherName}'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canUpload)
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Add photo',
                    onPressed: () => _addPhoto(context),
                  ),
                if (canManagePeriod)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete period',
                    onPressed: () => runGuarded(
                      context,
                      () => timetable.delete(classId, period.id),
                    ),
                  ),
              ],
            ),
            StreamBuilder<List<TimetablePhoto>>(
              stream: timetable.watchPhotos(classId, period.id),
              builder: (context, snap) {
                final photos = snap.data ?? [];
                if (photos.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final photo in photos)
                        _PhotoThumb(
                          photo: photo,
                          onDelete: canUpload
                              ? () => _deletePhoto(context, photo)
                              : null,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context) async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final skipped = <String>[];
    for (final file in picked) {
      try {
        final saved = await timetable.savePhoto(
          classId: classId,
          periodId: period.id,
          bytes: await file.xFile.readAsBytes(),
          fileName: file.name,
        );
        if (!saved) skipped.add(file.name);
      } catch (_) {
        skipped.add(file.name);
      }
    }
    if (!context.mounted) return;
    if (skipped.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not attach: ${skipped.join(', ')}'),
        ),
      );
    }
  }

  Future<void> _deletePhoto(BuildContext context, TimetablePhoto photo) {
    return runGuarded(
      context,
      () => timetable.deletePhoto(classId, period.id, photo.id),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, this.onDelete});

  final TimetablePhoto photo;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final image = _image(96, 96);
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: onDelete == null
          ? image
          : Stack(
              children: [
                image,
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove photo',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _image(double width, double height) {
    Widget fallback() => Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: const Icon(Icons.broken_image_outlined),
    );
    if (photo.data != null && photo.data!.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(photo.data!),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => fallback(),
          ),
        );
      } catch (_) {
        return fallback();
      }
    }
    if (photo.url != null && photo.url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photo.url!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => fallback(),
        ),
      );
    }
    return fallback();
  }

  void _showFullScreen(BuildContext context) {
    Widget full;
    if (photo.data != null && photo.data!.isNotEmpty) {
      try {
        full = Image.memory(base64Decode(photo.data!), fit: BoxFit.contain);
      } catch (_) {
        full = const Icon(Icons.broken_image_outlined, size: 64);
      }
    } else if (photo.url != null && photo.url!.isNotEmpty) {
      full = Image.network(photo.url!, fit: BoxFit.contain);
    } else {
      full = const Icon(Icons.broken_image_outlined, size: 64);
    }
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SizedBox(width: double.maxFinite, height: 420, child: full),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
