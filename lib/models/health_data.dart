class HealthData {
  final int? id;
  final int heartRate;
  final int oxygenSaturation; // 血氧饱和度 (%)
  final DateTime timestamp;

  HealthData({
    this.id,
    required this.heartRate,
    required this.oxygenSaturation,
    required this.timestamp, 
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'heartRate': heartRate,
      'oxygenSaturation': oxygenSaturation,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory HealthData.fromMap(Map<String, dynamic> map) {
    return HealthData(
      id: map['id'],
      heartRate: map['heartRate'],
      oxygenSaturation: map['oxygenSaturation'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}
