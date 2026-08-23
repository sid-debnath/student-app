import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/homework.dart';
import 'paths.dart';

class HomeworkRepository {
  HomeworkRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  Stream<List<Homework>> watch({String? classId}) {
    Query<Map<String, dynamic>> query = _paths.homework;
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map((snap) {
      final items = snap.docs.map((doc) => Homework.fromMap(doc.id, doc.data())).toList();
      items.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return items;
    });
  }

  Future<void> upsert(Homework homework) async {
    final id = homework.id.isEmpty ? _uuid.v4() : homework.id;
    await _paths.homework.doc(id).set(homework.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String id) => _paths.homework.doc(id).delete();
}
