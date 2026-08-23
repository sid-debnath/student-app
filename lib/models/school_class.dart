class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.section,
    required this.year,
    this.teacherIds = const [],
  });

  final String id;
  final String name;
  final String section;
  final int year;
  final List<String> teacherIds;

  String get label => '$name-$section';

  factory SchoolClass.fromMap(String id, Map<String, dynamic> data) {
    return SchoolClass(
      id: id,
      name: data['name'] as String? ?? '',
      section: data['section'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      teacherIds: List<String>.from(data['teacherIds'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'section': section,
    'year': year,
    'teacherIds': teacherIds,
  };
}
