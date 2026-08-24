class HomeworkFile {
  const HomeworkFile({
    required this.id,
    required this.name,
    required this.kind,
    this.mime = 'image/jpeg',
    this.data,
    this.url,
  });

  final String id;
  final String name;
  final String kind; // image | video
  final String mime;
  final String? data; // base64 jpeg for Spark-safe image display
  final String? url;

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';

  factory HomeworkFile.fromMap(String id, Map<String, dynamic> data) {
    return HomeworkFile(
      id: id,
      name: data['name'] as String? ?? 'file',
      kind: data['kind'] as String? ?? 'image',
      mime: data['mime'] as String? ?? 'image/jpeg',
      data: data['data'] as String?,
      url: data['url'] as String?,
    );
  }
}
