import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/attendance.dart';
import '../../models/academic_class.dart';
import '../../models/student.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_dropdown.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _classId;
  late String _date;

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final roster = ref.watch(rosterRepositoryProvider);
    final attendance = ref.watch(attendanceRepositoryProvider);
    if (session == null || roster == null || attendance == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEdit = session.isAdmin || session.isTeacher;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_date),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
                  }
                },
              ),
              if (classId != null)
                StreamBuilder<List<Student>>(
                  stream: session.isViewer
                      ? roster.watchStudentsByIds(session.studentIds)
                      : roster.watchStudents(classId: classId),
                  builder: (context, studentSnap) {
                    final students = (studentSnap.data ?? [])
                        .where((student) => student.classId == classId)
                        .toList();
                    return StreamBuilder<AttendanceRecord?>(
                      stream: attendance.watchDay(classId, _date),
                      builder: (context, recordSnap) {
                        final marks = Map<String, AttendanceStatus>.from(
                          recordSnap.data?.marks ?? const {},
                        );
                        return Column(
                          children: [
                            for (final student in students)
                              ListTile(
                                title: Text(student.name),
                                subtitle: Text('Roll ${student.roll}'),
                                trailing: DropdownButton<AttendanceStatus>(
                                  value: marks[student.id] ?? AttendanceStatus.present,
                                  onChanged: !canEdit
                                      ? null
                                      : (status) {
                                          if (status == null) return;
                                          marks[student.id] = status;
                                          runGuarded(context, () {
                                            return attendance.save(
                                              AttendanceRecord(
                                                id: attendance.docId(classId, _date),
                                                classId: classId,
                                                date: _date,
                                                marks: {
                                                  for (final item in students)
                                                    item.id: marks[item.id] ?? AttendanceStatus.present,
                                                },
                                                takenBy: session.id,
                                              ),
                                            );
                                          });
                                        },
                                  items: [
                                    for (final status in AttendanceStatus.values)
                                      DropdownMenuItem(value: status, child: Text(status.name)),
                                  ],
                                ),
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
    );
  }
}
