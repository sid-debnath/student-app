import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/academic_class.dart';
import '../../models/student.dart';
import '../../models/student_pagination.dart';
import '../../widgets/async_body.dart';

const _allClassesValue = '__all__';

/// Lists every student in the institution, filterable by class.
///
/// The list is paginated at [studentsPerPage] students per page; the
/// Previous/Next controls only appear once a class (or the whole roster) has
/// more than one page.
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  /// Selected class id, or null for every class.
  String? _classId;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterRepositoryProvider);
    if (roster == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: StreamBuilder<List<AcademicClass>>(
        stream: roster.watchClasses(),
        builder: (context, classSnap) {
          final classes = classSnap.data ?? const <AcademicClass>[];
          return StreamBuilder<List<Student>>(
            stream: roster.watchStudents(classId: _classId),
            builder: (context, studentSnap) {
              if (studentSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(formatAppError(studentSnap.error!)),
                  ),
                );
              }
              if (!studentSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildList(context, classes, studentSnap.data!);
            },
          );
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<AcademicClass> classes,
    List<Student> students,
  ) {
    final theme = Theme.of(context);
    // Keep the filter valid if the selected class was deleted.
    final selectedClassId = classes.any((c) => c.id == _classId) ? _classId : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(selectedClassId ?? _allClassesValue),
          initialValue: selectedClassId ?? _allClassesValue,
          decoration: const InputDecoration(labelText: 'Class'),
          items: [
            const DropdownMenuItem(
              value: _allClassesValue,
              child: Text('All classes'),
            ),
            for (final academicClass in classes)
              DropdownMenuItem(
                value: academicClass.id,
                child: Text(academicClass.label),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _classId = (value == null || value == _allClassesValue)
                  ? null
                  : value;
              _page = 0;
            });
          },
        ),
        const SizedBox(height: 12),
        if (students.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              selectedClassId == null
                  ? 'No students in the roster yet.'
                  : 'No students in this class.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._buildStudentSections(context, classes, students),
      ],
    );
  }

  List<Widget> _buildStudentSections(
    BuildContext context,
    List<AcademicClass> classes,
    List<Student> students,
  ) {
    final theme = Theme.of(context);
    final pageCount = studentPageCount(students);
    final currentPage = _page.clamp(0, pageCount - 1).toInt();
    final visible = studentsForPage(students, currentPage);
    final first = currentPage * studentsPerPage + 1;
    final last = first + visible.length - 1;

    return [
      Text(
        '${students.length} students',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      for (final student in visible)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(student.name),
          subtitle: Text(_studentSubtitle(student, classes)),
        ),
      if (pageCount > 1) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing $first–$last of ${students.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: currentPage == 0
                  ? null
                  : () => setState(() => _page = currentPage - 1),
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: currentPage >= pageCount - 1
                  ? null
                  : () => setState(() => _page = currentPage + 1),
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    ];
  }
}

String _studentSubtitle(Student student, List<AcademicClass> classes) {
  final classLabel = classes
      .where((c) => c.id == student.classId)
      .map((c) => c.label)
      .firstOrNull;
  final roll = student.roll.isEmpty ? '' : ' · Roll ${student.roll}';
  return '${classLabel ?? 'No class'}$roll';
}

