import 'package:cloud_firestore/cloud_firestore.dart';

class InstitutionPaths {
  InstitutionPaths(this.institutionId);

  final String institutionId;

  DocumentReference<Map<String, dynamic>> get institution =>
      FirebaseFirestore.instance.collection('institutions').doc(institutionId);

  CollectionReference<Map<String, dynamic>> col(String name) =>
      institution.collection(name);

  CollectionReference<Map<String, dynamic>> get users => col('users');
  CollectionReference<Map<String, dynamic>> get classes => col('classes');
  CollectionReference<Map<String, dynamic>> get students => col('students');
  CollectionReference<Map<String, dynamic>> get attendance => col('attendance');
  CollectionReference<Map<String, dynamic>> get homework => col('homework');
  CollectionReference<Map<String, dynamic>> get exams => col('exams');
  CollectionReference<Map<String, dynamic>> get marks => col('marks');
  CollectionReference<Map<String, dynamic>> get reportCards => col('reportCards');
  CollectionReference<Map<String, dynamic>> get announcements => col('announcements');
  CollectionReference<Map<String, dynamic>> get ptmSlots => col('ptmSlots');
  CollectionReference<Map<String, dynamic>> get ptmBookings => col('ptmBookings');
  CollectionReference<Map<String, dynamic>> get ptmNotes => col('ptmNotes');

  CollectionReference<Map<String, dynamic>> periods(String classId) =>
      col('timetable').doc(classId).collection('periods');
}
