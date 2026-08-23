import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/timetable_period.dart';
import 'paths.dart';

class TimetableRepository {
  TimetableRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  Stream<List<TimetablePeriod>> watch(String classId) {
    return _paths.periods(classId).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => TimetablePeriod.fromMap(doc.id, {...doc.data(), 'classId': classId}))
          .toList();
      items.sort((a, b) {
        final day = a.weekday.compareTo(b.weekday);
        return day != 0 ? day : a.start.compareTo(b.start);
      });
      return items;
    });
  }

  Future<void> upsert(TimetablePeriod period) async {
    final id = period.id.isEmpty ? _uuid.v4() : period.id;
    await _paths.periods(period.classId).doc(id).set(period.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String classId, String periodId) {
    return _paths.periods(classId).doc(periodId).delete();
  }
}
