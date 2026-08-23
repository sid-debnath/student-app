import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/ptm.dart';
import 'paths.dart';

class PtmRepository {
  PtmRepository(this.schoolId) : _paths = SchoolPaths(schoolId);

  final String schoolId;
  final SchoolPaths _paths;
  final _uuid = const Uuid();

  Stream<List<PtmSlot>> watchSlots({String? teacherId}) {
    Query<Map<String, dynamic>> query = _paths.ptmSlots;
    if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    return query.snapshots().map((snap) {
      final items = snap.docs.map((doc) => PtmSlot.fromMap(doc.id, doc.data())).toList();
      items.sort((a, b) => a.start.compareTo(b.start));
      return items;
    });
  }

  Future<void> upsertSlot(PtmSlot slot) async {
    final id = slot.id.isEmpty ? _uuid.v4() : slot.id;
    await _paths.ptmSlots.doc(id).set(slot.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteSlot(String id) => _paths.ptmSlots.doc(id).delete();

  Stream<List<PtmBooking>> watchBookings({String? studentId, String? teacherId}) {
    Query<Map<String, dynamic>> query = _paths.ptmBookings;
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    } else if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => PtmBooking.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> bookSlot({
    required PtmSlot slot,
    required String studentId,
    required String viewerId,
  }) async {
    if (slot.isFull) {
      throw StateError('This slot is already full.');
    }
    final bookingId = _uuid.v4();
    await _paths.ptmBookings.doc(bookingId).set(
      PtmBooking(
        id: bookingId,
        slotId: slot.id,
        studentId: studentId,
        viewerId: viewerId,
        teacherId: slot.teacherId,
      ).toMap(),
    );
    await _paths.ptmSlots.doc(slot.id).set({
      'bookedCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Stream<List<PtmNote>> watchNotes({String? studentId}) {
    Query<Map<String, dynamic>> query = _paths.ptmNotes;
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => PtmNote.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> addNote({
    required PtmNote note,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final id = note.id.isEmpty ? _uuid.v4() : note.id;
    var urls = [...note.attachmentUrls];
    if (fileBytes != null && fileName != null) {
      final ref = FirebaseStorage.instance.ref(
        'schools/$schoolId/ptm/$id/$fileName',
      );
      await ref.putData(fileBytes);
      urls = [...urls, await ref.getDownloadURL()];
    }
    await _paths.ptmNotes.doc(id).set(
      note.copyWith(id: id, attachmentUrls: urls).toMap(),
    );
  }
}

