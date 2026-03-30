class ClipModel {
  final String id;
  final String userId;
  final String content;
  final String type;
  final DateTime timestamp;
  final DateTime expiresAt;

  ClipModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.expiresAt,
  });

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'] ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return DateTime.now();
  }

  // From JSON
  factory ClipModel.fromJson(Map<String, dynamic> json) {
    return ClipModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      timestamp: _parseTimestamp(json['timestamp']),
      expiresAt: _parseTimestamp(json['expiresAt']),
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
