class DeviceModel {
  final String deviceId;
  final String userId;
  final String deviceName;
  final String platform;
  final DateTime registeredAt;

  DeviceModel({
    required this.deviceId,
    required this.userId,
    required this.deviceName,
    required this.platform,
    required this.registeredAt,
  });

  // From JSON
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceId: json['deviceId'] ?? '',
      userId: json['userId'] ?? '',
      deviceName: json['deviceName'] ?? '',
      platform: json['platform'] ?? 'android',
      registeredAt: DateTime.parse(json['registeredAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'platform': platform,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  // Get platform icon
  String get platformIcon {
    switch (platform) {
      case 'android':
        return '🤖';
      case 'ios':
        return '📱';
      case 'pc':
        return '💻';
      default:
        return '📱';
    }
  }
}
