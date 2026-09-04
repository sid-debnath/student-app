class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.order = 0,
  });

  final String id;
  final String name;
  final int order;

  factory Subject.fromMap(String id, Map<String, dynamic> data) {
    return Subject(
      id: id,
      name: (data['name'] as String? ?? '').trim(),
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'order': order,
  };
}
