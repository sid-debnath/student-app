import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.audiences = const [],
    this.classIds = const [],
    this.imageUrls = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;

  /// Selected target roles for the announcement. Each entry is one of
  /// 'teachers', 'floorIncharge', or 'students'. An empty list means everyone.
  final List<String> audiences;
  final List<String> classIds;
  final List<String> imageUrls;
  final String? createdBy;
  final DateTime? createdAt;

  bool visibleTo({
    required bool isAdmin,
    required bool isTeacher,
    required bool isFloorIncharge,
    required bool isViewer,
  }) {
    if (isAdmin) return true;
    // Empty audiences (including legacy unknown values) reaches everyone.
    if (audiences.isEmpty) return true;
    return audiences.any(
      (role) => switch (role) {
        'teachers' => isTeacher,
        'floorIncharge' => isFloorIncharge,
        'students' => isViewer,
        _ => false,
      },
    );
  }

  String get audienceLabel {
    if (audiences.isEmpty) return 'Everyone';
    final labels = <String>[
      if (audiences.contains('teachers')) 'Teachers',
      if (audiences.contains('floorIncharge')) 'Floor In-Charges',
      if (audiences.contains('students')) 'Students',
    ];
    if (labels.isEmpty || labels.length >= 3) return 'Everyone';
    if (labels.length == 1) return '${labels.first} only';
    return labels.join(' and ');
  }

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final stored = List<String>.from(data['audiences'] as List? ?? const []);
    return Announcement(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      audiences: stored.isNotEmpty
          ? stored
          : _legacyAudienceRoles(data['audience'] as String?),
      classIds: List<String>.from(data['classIds'] as List? ?? const []),
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const []),
      createdBy: data['createdBy'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap({bool stampCreatedAt = true}) => {
    'title': title,
    'body': body,
    'audiences': audiences,
    'classIds': classIds,
    'imageUrls': imageUrls,
    'createdBy': createdBy,
    if (stampCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };

  static List<String> _legacyAudienceRoles(String? audience) => switch (audience) {
    'teachers' => const ['teachers'],
    'floorIncharge' => const ['floorIncharge'],
    'students' => const ['students'],
    'both' || 'all' => const ['teachers', 'floorIncharge', 'students'],
    _ => const [],
  };
}
