import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/exam.dart';
import '../../models/marks.dart';
import '../../models/report_card.dart';
import '../../models/academic_class.dart';
import '../../models/student.dart';
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final roster = ref.watch(rosterRepositoryProvider);
    final marks = ref.watch(marksRepositoryProvider);
    if (session == null || roster == null || marks == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEdit = session.isAdmin || session.isTeacher;
    final studentId = session.isViewer
        ? (ref.watch(selectedStudentIdProvider) ?? session.studentIds.firstOrNull)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(session.isViewer ? 'Report card' : 'Marks')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _createExam(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: session.isViewer
          ? StreamBuilder<List<ReportCard>>(
              stream: marks.watchReportCards(studentId: studentId),
              builder: (context, snapshot) {
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
                          title: Text(card.examName),
                          subtitle: Text(
                            '${card.termId} · ${DateFormat.yMMMd().format(card.publishedAt)}\n'
                            '${card.scores.entries.map((e) => '${e.key}: ${e.value}').join(', ')}'
                            '${card.remarks == null ? '' : '\n${card.remarks}'}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                  ],
                );
              },
            )
          : StreamBuilder<List<AcademicClass>>(
              stream: roster.watchClasses(onlyIds: session.isTeacher ? session.classIds : null),
              builder: (context, classSnap) {
                final classes = classSnap.data ?? [];
                final classId = _classId ?? (classes.isEmpty ? null : classes.first.id);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClassDropdown(
                      classes: classes,
                      value: classId,
                      onChanged: (value) => setState(() {
                        _classId = value;
                        _examId = null;
                      }),
                    ),
                    if (classId != null)
                      StreamBuilder<List<Exam>>(
                        stream: marks.watchExams(classId: classId),
                        builder: (context, examSnap) {
                          final exams = examSnap.data ?? [];
                          final examId = _examId ?? (exams.isEmpty ? null : exams.first.id);
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: exams.any((exam) => exam.id == examId) ? examId : null,
                                decoration: const InputDecoration(labelText: 'Exam'),
                                items: [
                                  for (final exam in exams)
                                    DropdownMenuItem(value: exam.id, child: Text('${exam.name} (${exam.term})')),
                                ],
                                onChanged: (value) => setState(() => _examId = value),
                              ),
                              if (examId != null)
                                StreamBuilder<List<Student>>(
                                  stream: roster.watchStudents(classId: classId),
                                  builder: (context, studentSnap) {
                                    final students = studentSnap.data ?? [];
                                    return StreamBuilder<List<StudentMarks>>(
                                      stream: marks.watchMarks(examId),
                                      builder: (context, marksSnap) {
                                        final byStudent = {
                                          for (final row in marksSnap.data ?? <StudentMarks>[])
                                            row.studentId: row,
                                        };
                                        return Column(
                                          children: [
                                            for (final student in students)
                                              ListTile(
                                                title: Text(student.name),
                                                subtitle: Text(
                                                  byStudent[student.id]?.scores.entries
                                                          .map((e) => '${e.key}: ${e.value}')
                                                          .join(', ') ??
                                                      'No marks',
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  onPressed: () => _editMarks(
                                                    context,
                                                    exam: exams.firstWhere((exam) => exam.id == examId),
                                                    student: student,
                                                    existing: byStudent[student.id],
                                                  ),
                                                ),
                                              ),
                                            FilledButton(
                                              onPressed: () => _publish(context, exams.firstWhere((e) => e.id == examId), students, byStudent),
                                              child: const Text('Publish report cards'),
                                            ),
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
            ),
    );
  }

  Future<void> _createExam(BuildContext context) async {
    final classId = _classId;
    if (classId == null) return;
    final name = TextEditingController(text: 'Term exam');
    final term = TextEditingController(text: 'Term 1');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: term, decoration: const InputDecoration(labelText: 'Term')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await guard(context, () {
      return ref.read(marksRepositoryProvider)!.upsertExam(
        Exam(id: '', name: name.text.trim(), term: term.text.trim(), classId: classId),
      );
    });
  }

  Future<void> _editMarks(
    BuildContext context, {
    required Exam exam,
    required Student student,
    StudentMarks? existing,
  }) async {
    final english = TextEditingController(text: '${existing?.scores['English'] ?? ''}');
    final maths = TextEditingController(text: '${existing?.scores['Maths'] ?? ''}');
    final science = TextEditingController(text: '${existing?.scores['Science'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marks · ${student.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: english, decoration: const InputDecoration(labelText: 'English')),
            const SizedBox(height: 8),
            TextField(controller: maths, decoration: const InputDecoration(labelText: 'Maths')),
            const SizedBox(height: 8),
            TextField(controller: science, decoration: const InputDecoration(labelText: 'Science')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await guard(context, () {
      return ref.read(marksRepositoryProvider)!.upsertMarks(
        StudentMarks(
          id: existing?.id ?? '',
          examId: exam.id,
          studentId: student.id,
          classId: exam.classId,
          scores: {
            'English': double.tryParse(english.text) ?? 0,
            'Maths': double.tryParse(maths.text) ?? 0,
            'Science': double.tryParse(science.text) ?? 0,
          },
        ),
      );
    });
  }

  Future<void> _publish(
    BuildContext context,
    Exam exam,
    List<Student> students,
    Map<String, StudentMarks> byStudent,
  ) async {
    await guard(context, () async {
      final repo = ref.read(marksRepositoryProvider)!;
      for (final student in students) {
        final row = byStudent[student.id];
        if (row == null) continue;
        await repo.publishReportCard(
          ReportCard(
            id: '',
            studentId: student.id,
            termId: exam.term,
            classId: exam.classId,
            examName: exam.name,
            scores: row.scores,
            publishedAt: DateTime.now(),
          ),
        );
      }
    });
  }
}
