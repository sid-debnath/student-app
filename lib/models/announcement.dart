import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.classIds = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final List<String> classIds;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isSchoolWide => audience == 'all';

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return Announcement(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      audience: data['audience'] as String? ?? 'all',
      classIds: List<String>.from(data['classIds'] as List? ?? const []),
      createdBy: data['createdBy'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'audience': audience,
    'classIds': classIds,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
