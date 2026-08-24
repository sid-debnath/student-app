import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.classIds = const [],
    this.imageUrls = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  /// teachers | students | both | all (legacy)
  final String audience;
  final List<String> classIds;
  final List<String> imageUrls;
  final String? createdBy;
  final DateTime? createdAt;

  bool visibleTo({required bool isAdmin, required bool isTeacher, required bool isViewer}) {
    if (isAdmin) return true;
    switch (audience) {
      case 'teachers':
        return isTeacher;
      case 'students':
        return isViewer;
      case 'both':
      case 'all':
        return isTeacher || isViewer;
      default:
        return true;
    }
  }

  String get audienceLabel => switch (audience) {
    'teachers' => 'Teachers only',
    'students' => 'Students only',
    'both' => 'Teachers and students',
    _ => 'Everyone',
  };

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return Announcement(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      audience: data['audience'] as String? ?? 'both',
      classIds: List<String>.from(data['classIds'] as List? ?? const []),
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const []),
      createdBy: data['createdBy'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap({bool stampCreatedAt = true}) => {
    'title': title,
    'body': body,
    'audience': audience,
    'classIds': classIds,
    'imageUrls': imageUrls,
    'createdBy': createdBy,
    if (stampCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };
}
