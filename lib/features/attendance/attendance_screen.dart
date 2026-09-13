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
  bool _showHistory = false;

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
    final canEdit = session.isAdmin || session.isStaff;
    // Only admins and floor in-charges may delete attendance history.
    final canDelete = session.isAdmin || session.isFloorIncharge;

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
              if (!session.isViewer)
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
                      setState(
                        () => _date = DateFormat('yyyy-MM-dd').format(picked),
                      );
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
                    return StreamBuilder<List<AttendanceRecord>>(
                      stream: attendance.watchForClass(classId),
                      builder: (context, historySnap) {
                        final records =
                            historySnap.data ?? const <AttendanceRecord>[];
                        final percentages = <String, double?>{
                          for (final student in students)
                            student.id: attendancePercentageFor(
                              records,
                              student.id,
                            ),
                        };
                        return Column(
                          children: [
                            if (!session.isViewer) ...[
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Mark'),
                                    icon: Icon(Icons.edit_note),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('History'),
                                    icon: Icon(Icons.history),
                                  ),
                                ],
                                selected: {_showHistory},
                                onSelectionChanged: (selection) => setState(
                                  () => _showHistory = selection.first,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (session.isViewer || _showHistory)
                              _StudentAttendanceTable(
                                students: students,
                                records: records,
                                onDeleteMark: !session.isViewer && canDelete
                                    ? _confirmDeleteMark
                                    : null,
                              )
                            else
                              StreamBuilder<AttendanceRecord?>(
                                stream: attendance.watchDay(classId, _date),
                                builder: (context, recordSnap) {
                                  final marks =
                                      Map<String, AttendanceStatus>.from(
                                        recordSnap.data?.marks ?? const {},
                                      );
                                  return Column(
                                    children: [
                                      for (final student in students)
                                        ListTile(
                                          title: Text(student.name),
                                          subtitle: Text(
                                            _studentSubtitle(
                                              student,
                                              percentages[student.id],
                                            ),
                                          ),
                                          trailing: DropdownButton<AttendanceStatus>(
                                            value:
                                                marks[student.id] ??
                                                AttendanceStatus.neutral,
                                            onChanged: !canEdit
                                                ? null
                                                : (status) {
                                                    if (status == null) return;
                                                    marks[student.id] = status;
                                                    runGuarded(context, () {
                                                      return attendance.save(
                                                        AttendanceRecord(
                                                          id: attendance.docId(
                                                            classId,
                                                            _date,
                                                          ),
                                                          classId: classId,
                                                          date: _date,
                                                          marks: {
                                                            for (final item
                                                                in students)
                                                              item.id:
                                                                  marks[item
                                                                      .id] ??
                                                                  AttendanceStatus
                                                                      .neutral,
                                                          },
                                                          takenBy: session.id,
                                                        ),
                                                      );
                                                    });
                                                  },
                                            items: [
                                              for (final status
                                                  in AttendanceStatus.values)
                                                DropdownMenuItem(
                                                  value: status,
                                                  child: Text(status.label),
                                                ),
                                            ],
                                          ),
                                        ),
                                      if (recordSnap.data != null && canDelete)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _confirmDeleteDay(classId),
                                            icon: const Icon(Icons.delete_outline),
                                            label: const Text(
                                              "Delete this day's attendance",
                                            ),
                                          ),
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
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteMark(
    Student student,
    AttendanceRecord record,
  ) async {
    final attendance = ref.read(attendanceRepositoryProvider);
    if (attendance == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete attendance record?'),
        content: Text(
          'Remove ${_formatDate(record.date)} attendance for '
          '${student.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runGuarded(context, () async {
      await attendance.deleteMark(record.classId, record.date, student.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${_formatDate(record.date)} attendance for '
            '${student.name}.',
          ),
        ),
      );
    });
  }

  Future<void> _confirmDeleteDay(String classId) async {
    final attendance = ref.read(attendanceRepositoryProvider);
    if (attendance == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete day attendance?'),
        content: Text(
          'Delete the whole attendance record for ${_formatDate(_date)}? '
          'This removes marks for every student and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runGuarded(context, () async {
      await attendance.deleteDay(classId, _date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted attendance for ${_formatDate(_date)}.')),
      );
    });
  }
}

String _studentSubtitle(Student student, double? percentage) {
  final roll = student.roll.isEmpty ? '' : 'Roll ${student.roll}';
  final percent = percentage == null
      ? null
      : '${percentage.toStringAsFixed(0)}% attendance';
  return [if (roll.isNotEmpty) roll, ?percent].join(' · ');
}

String _formatPercent(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(0)}%';

Color _percentColor(double? value) {
  if (value == null) return Colors.grey;
  if (value >= 75) return Colors.green;
  if (value >= 50) return Colors.orange;
  return Colors.red;
}

class _StudentAttendanceTable extends StatelessWidget {
  const _StudentAttendanceTable({
    required this.students,
    required this.records,
    this.onDeleteMark,
  });

  final List<Student> students;
  final List<AttendanceRecord> records;
  final void Function(Student student, AttendanceRecord record)? onDeleteMark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final student in students)
          _AttendanceTableCard(
            student: student,
            records: records,
            onDeleteMark: onDeleteMark,
          ),
      ],
    );
  }
}

class _AttendanceTableCard extends StatelessWidget {
  const _AttendanceTableCard({
    required this.student,
    required this.records,
    this.onDeleteMark,
  });

  final Student student;
  final List<AttendanceRecord> records;
  final void Function(Student student, AttendanceRecord record)? onDeleteMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = attendanceStatsFor(records, student.id);
    final rows = [
      for (final record in records)
        if (record.marks.containsKey(student.id)) record,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Working days: ${stats.workingDays} / ${stats.totalDays} '
              '(${_formatPercent(stats.percentage)})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _percentColor(stats.percentage),
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('No attendance recorded yet.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: [
                    const DataColumn(label: Text('Date')),
                    const DataColumn(label: Text('Time marked')),
                    const DataColumn(label: Text('Status')),
                    if (onDeleteMark != null) const DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final record in rows)
                      DataRow(
                        cells: [
                          DataCell(Text(_formatDate(record.date))),
                          DataCell(Text(_formatMarkedAt(record.markedAt))),
                          DataCell(Text(record.marks[student.id]!.label)),
                          if (onDeleteMark != null)
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Delete this record',
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => onDeleteMark!(student, record),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : DateFormat('dd MMM yyyy').format(parsed);
}

String _formatMarkedAt(DateTime? value) => value == null
    ? '—'
    : DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
