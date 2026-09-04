import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/providers.dart';
import '../../models/exam.dart';
import '../../models/marks.dart';
import '../../models/report_card.dart';
import '../../models/academic_class.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_dropdown.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen> {
  String? _classId;
  String? _examId;
  final _examTypeInput = TextEditingController();
  final Map<String, Map<String, TextEditingController>> _scoreControllers = {};
  final Map<String, String?> _pendingImageUrls = {};
  final Map<String, Uint8List?> _pendingImageBytes = {};
  final Map<String, String?> _pendingImageNames = {};
  var _busy = false;

  @override
  void dispose() {
    _examTypeInput.dispose();
    _disposeScoreControllers();
    super.dispose();
  }

  void _disposeScoreControllers() {
    for (final bySubject in _scoreControllers.values) {
      for (final controller in bySubject.values) {
        controller.dispose();
      }
    }
    _scoreControllers.clear();
  }

  TextEditingController _controllerFor({
    required String studentId,
    required String subjectId,
    String initial = '',
  }) {
    final bySubject = _scoreControllers.putIfAbsent(studentId, () => {});
    return bySubject.putIfAbsent(
      subjectId,
      () => TextEditingController(text: initial),
    );
  }

  void _ensureControllers({
    required List<Student> students,
    required List<Subject> subjects,
    required Map<String, StudentMarks> byStudent,
  }) {
    for (final student in students) {
      final existing = byStudent[student.id];
      for (final subject in subjects) {
        final bySubject = _scoreControllers.putIfAbsent(student.id, () => {});
        if (bySubject.containsKey(subject.id)) continue;
        bySubject[subject.id] = TextEditingController(
          text: existing == null ? '' : _scoreText(existing.scores, subject),
        );
      }
    }
  }

  String _scoreText(Map<String, MarkScore> scores, Subject subject) {
    final byId = scores[subject.id];
    if (byId != null) {
  return byId.obtained == byId.obtained.roundToDouble()
      ? '${byId.obtained.round()}'
      : byId.obtained.toString();
}
    final byName = scores[subject.name];
    if (byName != null) {
  return byName.obtained == byName.obtained.roundToDouble()
      ? '${byName.obtained.round()}'
      : byName.obtained.toString();
}
    return '';
  }

  
    

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final roster = ref.watch(rosterRepositoryProvider);
    final marks = ref.watch(marksRepositoryProvider);
    if (session == null || roster == null || marks == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEdit = session.isAdmin || session.isStaff;
    final selectedStudentId = ref.watch(selectedStudentIdProvider);
    final studentId = session.isViewer
        ? (session.studentIds.contains(selectedStudentId)
            ? selectedStudentId
            : session.studentIds.firstOrNull)
        : null;
        debugPrint('Viewer studentIds: ${session.studentIds}');
debugPrint('Selected studentId: $studentId');

    return Scaffold(
      appBar: AppBar(
        title: Text(session.isViewer ? 'Report card' : 'Marks'),
      ),
      body: session.isViewer
          ? _ViewerReportCards(studentId: studentId)
          : StreamBuilder<List<AcademicClass>>(
              stream: roster.watchClasses(),
              builder: (context, classSnap) {
                final classes = classSnap.data ?? [];
                final classId = classes.any((item) => item.id == _classId)
                    ? _classId
                    : (classes.isEmpty ? null : classes.first.id);
                return StreamBuilder<List<Subject>>(
                  stream: marks.watchSubjects(),
                  builder: (context, subjectSnap) {
                    final subjects = subjectSnap.data ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (session.isAdmin) ...[
                          _SubjectsAdminSection(
                            subjects: subjects,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                        ],
                        ClassDropdown(
                          classes: classes,
                          value: classId,
                          onChanged: (value) => setState(() {
                            _classId = value;
                            _examId = null;
                            _examTypeInput.clear();
                            _disposeScoreControllers();
                            _pendingImageUrls.clear();
                            _pendingImageBytes.clear();
                            _pendingImageNames.clear();
                          }),
                        ),
                        if (classId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Text('Add a class on Roster first.'),
                          )
                        else if (subjects.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Text(
                              'An admin must add subjects before marks can be entered.',
                            ),
                          )
                        else
                          StreamBuilder<List<Exam>>(
                            stream: marks.watchExams(classId: classId),
                            builder: (context, examSnap) {
                              final exams = examSnap.data ?? [];
                              final selectedExam = exams
                                  .where((exam) => exam.id == _examId)
                                  .firstOrNull;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  if (exams.isNotEmpty) ...[
                                    DropdownButtonFormField<String>(
                                      key: ValueKey('exam-$_examId-${exams.length}'),
                                      initialValue: selectedExam?.id,
                                      decoration: const InputDecoration(
                                        labelText: 'Exam Type',
                                      ),
                                      items: [
                                        for (final exam in exams)
                                          DropdownMenuItem(
                                            value: exam.id,
                                            child: Text(exam.examType),
                                          ),
                                      ],
                                      onChanged: canEdit
                                          ? (value) => setState(() {
                                                _examId = value;
                                                final exam = exams
                                                    .where((e) => e.id == value)
                                                    .firstOrNull;
                                                _examTypeInput.text =
                                                    exam?.examType ?? '';
                                                _disposeScoreControllers();
                                                _pendingImageUrls.clear();
                                                _pendingImageBytes.clear();
                                                _pendingImageNames.clear();
                                              })
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (canEdit) ...[
                                    TextField(
                                      controller: _examTypeInput,
                                      decoration: const InputDecoration(
                                        labelText: 'Exam Type',
                                        hintText: 'e.g. UT-1',
                                        helperText:
                                            'Select an existing type above or enter a new one.',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.tonal(
                                        onPressed: _busy
                                            ? null
                                            : () => _openExamType(
                                                  classId: classId,
                                                ),
                                        child: const Text('Open exam type'),
                                      ),
                                    ),
                                  ],
                                  if (selectedExam != null)
                                    StreamBuilder<List<Student>>(
                                      stream: roster.watchStudents(
                                        classId: classId,
                                      ),
                                      builder: (context, studentSnap) {
                                        final students =
                                            studentSnap.data ?? [];
                                        return StreamBuilder<List<StudentMarks>>(
                                          stream: marks.watchMarks(
                                            selectedExam.id,
                                          ),
                                          builder: (context, marksSnap) {
                                            final byStudent = {
                                              for (final row
                                                  in marksSnap.data ??
                                                      <StudentMarks>[])
                                                row.studentId: row,
                                            };
                                            _ensureControllers(
                                              students: students,
                                              subjects: subjects,
                                              byStudent: byStudent,
                                            );
                                            if (students.isEmpty) {
                                              return const Padding(
                                                padding: EdgeInsets.only(
                                                  top: 24,
                                                ),
                                                child: Text(
                                                  'No students enrolled in this class.',
                                                ),
                                              );
                                            }
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Marks · ${selectedExam.examType}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                                const SizedBox(height: 8),
                                                _MarksGrid(
                                                  students: students,
                                                  subjects: subjects,
                                                  byStudent: byStudent,
                                                  canEdit: canEdit,
                                                  controllerFor: _controllerFor,
                                                  imageUrlFor: (student) =>
                                                      _pendingImageUrls[
                                                          student.id] ??
                                                      byStudent[student.id]
                                                          ?.reportImageUrl,
                                                  onPickImage: canEdit
                                                      ? (student) =>
                                                          _pickReportImage(
                                                            student,
                                                          )
                                                      : null,
                                                ),
                                                if (canEdit) ...[
                                                  const SizedBox(height: 16),
                                                  FilledButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _saveMarks(
                                                              exam:
                                                                  selectedExam,
                                                              students:
                                                                  students,
                                                              subjects:
                                                                  subjects,
                                                              byStudent:
                                                                  byStudent,
                                                            ),
                                                    child: Text(
                                                      _busy
                                                          ? 'Saving…'
                                                          : 'Save marks',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  OutlinedButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _publish(
                                                              exam:
                                                                  selectedExam,
                                                              students:
                                                                  students,
                                                              subjects:
                                                                  subjects,
                                                              byStudent:
                                                                  byStudent,
                                                            ),
                                                    child: const Text(
                                                      'Publish report cards',
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _openExamType({required String classId}) async {
    final label = _examTypeInput.text.trim();
    if (label.isEmpty) {
      showError(context, 'Enter an exam type (e.g. UT-1).');
      return;
    }
    setState(() => _busy = true);
    try {
      final exam = await ref.read(marksRepositoryProvider)!.ensureExamType(
            classId: classId,
            examType: label,
          );
      if (!mounted) return;
      setState(() {
        _examId = exam.id;
        _examTypeInput.text = exam.examType;
        _disposeScoreControllers();
        _pendingImageUrls.clear();
        _pendingImageBytes.clear();
        _pendingImageNames.clear();
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickReportImage(Student student) async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final file = picked.first;
    final bytes = await file.xFile.readAsBytes();
    if (bytes.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _pendingImageBytes[student.id] = bytes;
      _pendingImageNames[student.id] = file.name;
      _pendingImageUrls[student.id] = null;
    });
    if (!AppConfig.useStorage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image selected. Upload runs when Storage is enabled (production). '
            'Marks still save without the image on Spark.',
          ),
        ),
      );
    }
  }

  Future<void> _saveMarks({
    required Exam exam,
    required List<Student> students,
    required List<Subject> subjects,
    required Map<String, StudentMarks> byStudent,
    bool showSnackBar = true,
  }) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(marksRepositoryProvider)!;
      final rows = <StudentMarks>[];
      final profile = ref.read(sessionProvider).value;
if (profile == null) {
  throw StateError('Admin profile not available.');
}
      for (final student in students) {
        final scores = <String, MarkScore>{};
        for (final subject in subjects) {
          final text = _controllerFor(
            studentId: student.id,
            subjectId: subject.id,
          ).text.trim();
          if (text.isEmpty) continue;
          final value = double.tryParse(text);
          if (value == null) {
            throw StateError(
              'Invalid mark for ${student.name} · ${subject.name}.',
            );
          }
          scores[subject.id] = MarkScore(
  obtained: value,
  maximum: 100,
);
        }
        var imageUrl = _pendingImageUrls[student.id] ??
            byStudent[student.id]?.reportImageUrl;
        final bytes = _pendingImageBytes[student.id];
        final fileName = _pendingImageNames[student.id];
        if (bytes != null && fileName != null) {
          final uploaded = await repo.uploadReportImage(
            studentId: student.id,
            examId: exam.id,
            bytes: bytes,
            fileName: fileName,
          );
          if (uploaded != null) {
            imageUrl = uploaded;
            _pendingImageUrls[student.id] = uploaded;
          }
          _pendingImageBytes.remove(student.id);
          _pendingImageNames.remove(student.id);
        }
        rows.add(
          StudentMarks(
            id: byStudent[student.id]?.id ?? '',
            examId: exam.id,
            studentId: student.id,
            classId: exam.classId,
            examType: exam.examType,
            scores: scores,
            reportImageUrl: imageUrl,
          ),
        );
      }
      await repo.saveClassMarks(exam: exam, rows: rows);
      if (!mounted) return;
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marks saved')),
        );
      }
      setState(() {});
    } catch (error) {
      if (mounted) showError(context, error);
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish({
    required Exam exam,
    required List<Student> students,
    required List<Subject> subjects,
    required Map<String, StudentMarks> byStudent,
  }) async {
    try {
      await _saveMarks(
        exam: exam,
        students: students,
        subjects: subjects,
        byStudent: byStudent,
        showSnackBar: false,
      );
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await guard(context, () async {
      final repo = ref.read(marksRepositoryProvider)!;
      final latest = {
        for (final row in await repo.watchMarks(exam.id).first)
          row.studentId: row,
      };
      final subjectNames = {for (final s in subjects) s.id: s.name};

final profile = ref.read(sessionProvider).value;
if (profile == null) {
  throw StateError('Admin profile not available.');
}

      for (final student in students) {
        final row = latest[student.id];
        if (row == null || row.scores.isEmpty) continue;
        final namedScores = <String, double>{
          for (final entry in row.scores.entries)
           subjectNames[entry.key] ?? entry.key: entry.value.obtained,
        };
        await repo.publishReportCard(
          ReportCard(
            id: '',
            studentId: student.id,
            classId: exam.classId,
            examType: exam.examType,
            scores: namedScores,
            publishedAt: DateTime.now(),
            imageUrl: row.reportImageUrl,
          ),
        );
        final firebaseUser = ref.read(authRepositoryProvider).auth.currentUser;

if (firebaseUser != null) {
  final idToken = await firebaseUser.getIdToken();

  if (idToken != null) {
    await http.post(
      Uri.parse(
        'https://iloqcnjehbstqrcjszyk.supabase.co/functions/v1/send-report-notification',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
  'studentId': student.id,
  'examType': exam.examType,
  'institutionId': profile.institutionId,
}),
    );
  }
}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report cards published')),
      );
    });
  }
}

class _ViewerReportCards extends ConsumerWidget {
  const _ViewerReportCards({required this.studentId});

  final String? studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(marksRepositoryProvider);
    if (marks == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (studentId == null || studentId!.isEmpty) {
      return const Center(child: Text('No linked student found.'));
    }
    return StreamBuilder<List<ReportCard>>(
      stream: marks.watchReportCards(studentId: studentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
  return Center(
    child: Text('Error: ${snapshot.error}'),
  );
}
        final cards = snapshot.data ?? [];
        if (cards.isEmpty) {
          return const Center(child: Text('No published report cards yet.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final card in cards)
              Card(
                child: ListTile(
                  title: Text(card.examType),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(card.publishedAt)}\n'
                    '${card.scores.entries.map((e) => '${e.key}: ${e.value}').join(', ')}'
                    '${card.remarks == null ? '' : '\n${card.remarks}'}',
                  ),
                  isThreeLine: true,
                  trailing: card.imageUrl == null || card.imageUrl!.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Open report image',
                          icon: const Icon(Icons.image_outlined),
                          onPressed: () async {
                            final uri = Uri.tryParse(card.imageUrl!);
                            if (uri != null) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubjectsAdminSection extends ConsumerStatefulWidget {
  const _SubjectsAdminSection({
    required this.subjects,
    required this.onChanged,
  });

  final List<Subject> subjects;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SubjectsAdminSection> createState() =>
      _SubjectsAdminSectionState();
}

class _SubjectsAdminSectionState extends ConsumerState<_SubjectsAdminSection> {
  final _name = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showError(context, 'Subject name is required.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(marksRepositoryProvider)!.upsertSubject(
            Subject(id: '', name: name),
          );
      _name.clear();
      widget.onChanged();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Subject subject) async {
    setState(() => _busy = true);
    try {
      await ref.read(marksRepositoryProvider)!.deleteSubject(subject.id);
      widget.onChanged();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Configure subjects for marks entry (add or remove).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Subject name',
                  hintText: 'e.g. English',
                ),
                onSubmitted: (_) => _busy ? null : _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _add,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.subjects.isEmpty)
          const Text('No subjects yet.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in widget.subjects)
                InputChip(
                  label: Text(subject.name),
                  onDeleted: _busy ? null : () => _delete(subject),
                ),
            ],
          ),
      ],
    );
  }
}

class _MarksGrid extends StatelessWidget {
  const _MarksGrid({
    required this.students,
    required this.subjects,
    required this.byStudent,
    required this.canEdit,
    required this.controllerFor,
    required this.imageUrlFor,
    this.onPickImage,
  });

  final List<Student> students;
  final List<Subject> subjects;
  final Map<String, StudentMarks> byStudent;
  final bool canEdit;
  final TextEditingController Function({
    required String studentId,
    required String subjectId,
    String initial,
  }) controllerFor;
  final String? Function(Student student) imageUrlFor;
  final Future<void> Function(Student student)? onPickImage;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Student')),
          for (final subject in subjects)
            DataColumn(label: Text(subject.name)),
          const DataColumn(label: Text('Report image')),
        ],
        rows: [
          for (final student in students)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    student.roll.isEmpty
                        ? student.name
                        : '${student.name} (${student.roll})',
                  ),
                ),
                for (final subject in subjects)
                  DataCell(
                    SizedBox(
                      width: 72,
                      child: canEdit
                          ? TextField(
                              controller: controllerFor(
                                studentId: student.id,
                                subjectId: subject.id,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            )
                          : Text(
                              _displayScore(
                                byStudent[student.id]?.scores,
                                subject,
                              ),
                            ),
                    ),
                  ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (imageUrlFor(student)?.isNotEmpty == true)
                        const Icon(Icons.image_outlined, size: 18),
                      if (canEdit && onPickImage != null)
                        TextButton(
                          onPressed: () => onPickImage!(student),
                          child: Text(
                            imageUrlFor(student)?.isNotEmpty == true ||
                                    byStudent[student.id]?.reportImageUrl !=
                                        null
                                ? 'Replace'
                                : 'Upload',
                          ),
                        )
                      else if (imageUrlFor(student)?.isNotEmpty != true)
                        const Text('—'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _displayScore(Map<String, MarkScore>? scores, Subject subject) {
    if (scores == null) return '—';
    final byId = scores[subject.id];
    if (byId != null) {
      return byId.obtained == byId.obtained.roundToDouble()
    ? '${byId.obtained.round()}'
    : byId.obtained.toString();
    }
    final byName = scores[subject.name];
    if (byName != null) {
      return byName.obtained == byName.obtained.roundToDouble()
    ? '${byName.obtained.round()}'
    : byName.obtained.toString();
    }
    return '—';
  }
}
