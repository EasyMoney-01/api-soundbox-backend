class DeviceModel {
  final String id;
  final String ip;
  final int port;
  final String? vendor;
  final bool isOnline;
  final DateTime discoveredAt;

  const DeviceModel({
    required this.id,
    required this.ip,
    required this.port,
    this.vendor,
    required this.isOnline,
    required this.discoveredAt,
  });

  String get address => '$ip:$port';

  DeviceModel copyWith({bool? isOnline, String? vendor}) {
    return DeviceModel(
      id: id,
      ip: ip,
      port: port,
      vendor: vendor ?? this.vendor,
      isOnline: isOnline ?? this.isOnline,
      discoveredAt: discoveredAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ip': ip,
        'port': port,
        'vendor': vendor,
        'isOnline': isOnline ? 1 : 0,
        'discoveredAt': discoveredAt.toIso8601String(),
      };

  factory DeviceModel.fromMap(Map<String, dynamic> map) => DeviceModel(
        id: map['id'],
        ip: map['ip'],
        port: map['port'],
        vendor: map['vendor'],
        isOnline: map['isOnline'] == 1,
        discoveredAt: DateTime.parse(map['discoveredAt']),
      );
}
