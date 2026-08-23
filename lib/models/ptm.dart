import 'package:cloud_firestore/cloud_firestore.dart';

class PtmSlot {
  const PtmSlot({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.start,
    required this.end,
    this.capacity = 1,
    this.bookedCount = 0,
  });

  final String id;
  final String teacherId;
  final String teacherName;
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int bookedCount;

  bool get isFull => bookedCount >= capacity;

  factory PtmSlot.fromMap(String id, Map<String, dynamic> data) {
    return PtmSlot(
      id: id,
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      start: (data['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (data['end'] as Timestamp?)?.toDate() ?? DateTime.now(),
      capacity: (data['capacity'] as num?)?.toInt() ?? 1,
      bookedCount: (data['bookedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'teacherId': teacherId,
    'teacherName': teacherName,
    'start': Timestamp.fromDate(start),
    'end': Timestamp.fromDate(end),
    'capacity': capacity,
    'bookedCount': bookedCount,
  };
}

class PtmBooking {
  const PtmBooking({
    required this.id,
    required this.slotId,
    required this.studentId,
    required this.viewerId,
    this.teacherId,
    this.notes,
  });

  final String id;
  final String slotId;
  final String studentId;
  final String viewerId;
  final String? teacherId;
  final String? notes;

  factory PtmBooking.fromMap(String id, Map<String, dynamic> data) {
    return PtmBooking(
      id: id,
      slotId: data['slotId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      viewerId: data['viewerId'] as String? ?? '',
      teacherId: data['teacherId'] as String?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'slotId': slotId,
    'studentId': studentId,
    'viewerId': viewerId,
    'teacherId': teacherId,
    'notes': notes,
  };
}

class PtmNote {
  const PtmNote({
    required this.id,
    required this.bookingId,
    required this.studentId,
    required this.body,
    this.attachmentUrls = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String bookingId;
  final String studentId;
  final String body;
  final List<String> attachmentUrls;
  final String? createdBy;
  final DateTime? createdAt;

  factory PtmNote.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return PtmNote(
      id: id,
      bookingId: data['bookingId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      body: data['body'] as String? ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] as List? ?? const []),
      createdBy: data['createdBy'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'bookingId': bookingId,
    'studentId': studentId,
    'body': body,
    'attachmentUrls': attachmentUrls,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };

  PtmNote copyWith({String? id, List<String>? attachmentUrls}) {
    return PtmNote(
      id: id ?? this.id,
      bookingId: bookingId,
      studentId: studentId,
      body: body,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
