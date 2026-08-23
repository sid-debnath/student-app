import 'package:cloud_firestore/cloud_firestore.dart';

class Homework {
  const Homework({
    required this.id,
    required this.classId,
    required this.subject,
    required this.title,
    required this.body,
    required this.dueDate,
    this.attachmentUrls = const [],
    this.createdBy,
  });

  final String id;
  final String classId;
  final String subject;
  final String title;
  final String body;
  final DateTime dueDate;
  final List<String> attachmentUrls;
  final String? createdBy;

  factory Homework.fromMap(String id, Map<String, dynamic> data) {
    final due = data['dueDate'];
    return Homework(
      id: id,
      classId: data['classId'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      dueDate: due is Timestamp ? due.toDate() : DateTime.tryParse('$due') ?? DateTime.now(),
      attachmentUrls: List<String>.from(data['attachmentUrls'] as List? ?? const []),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'classId': classId,
    'subject': subject,
    'title': title,
    'body': body,
    'dueDate': Timestamp.fromDate(dueDate),
    'attachmentUrls': attachmentUrls,
    'createdBy': createdBy,
  };
}
