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
  final String kind; // image | video | document
  final String mime;
  final String? data; // base64 payload for Spark-safe inline files (images & small documents)
  final String? url;

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isDocument => kind == 'document';

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
