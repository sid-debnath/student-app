class TimetablePhoto {
  const TimetablePhoto({
    required this.id,
    required this.name,
    this.mime = 'image/jpeg',
    this.data,
    this.url,
  });

  final String id;
  final String name;
  final String mime;

  /// base64-encoded JPEG stored in Firestore so photos display without a
  /// Storage bucket (Spark-safe).
  final String? data;

  /// Optional remote URL if a production build ever uploads to Storage.
  final String? url;

  factory TimetablePhoto.fromMap(String id, Map<String, dynamic> data) {
    return TimetablePhoto(
      id: id,
      name: data['name'] as String? ?? 'photo',
      mime: data['mime'] as String? ?? 'image/jpeg',
      data: data['data'] as String?,
      url: data['url'] as String?,
    );
  }
}
