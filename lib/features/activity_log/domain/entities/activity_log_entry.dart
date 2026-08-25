class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String message;
  final DateTime createdAt;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
