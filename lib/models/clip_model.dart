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

  // From JSON
  factory ClipModel.fromJson(Map<String, dynamic> json) {
    return ClipModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(json['expiresAt'] ?? DateTime.now().toIso8601String()),
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
