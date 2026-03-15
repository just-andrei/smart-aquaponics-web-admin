import 'package:cloud_firestore/cloud_firestore.dart';

class UserSystem {
  final String id;
  final String systemName;
  final String hardwareUid;
  final String activeFishId;
  final String activePlantId;
  final int currentBatchNumber;
  final DateTime? ecosystemStartDate;
  final bool isSystemActive;
  final Map<String, dynamic> sensorAverages;
  final Map<String, dynamic> harvestTotals;
  final String provisionCode;

  const UserSystem({
    required this.id,
    required this.systemName,
    required this.hardwareUid,
    required this.activeFishId,
    required this.activePlantId,
    required this.currentBatchNumber,
    required this.ecosystemStartDate,
    required this.isSystemActive,
    required this.sensorAverages,
    required this.harvestTotals,
    required this.provisionCode,
  });

  factory UserSystem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final systemName = _readString(data['system_name'], fallback: '')
        .isNotEmpty
        ? _readString(data['system_name'])
        : _readString(data['systemName']);
    final startDate = _readDateTime(
      data['ecosystem_start_date'] ?? data['ecosystemStartDate'],
    );
    return UserSystem(
      id: doc.id,
      systemName: systemName,
      hardwareUid: _readString(data['hardware_uid']) != ''
          ? _readString(data['hardware_uid'])
          : _readString(data['hardwareUid']),
      activeFishId: _readString(data['active_fish_id']),
      activePlantId: _readString(data['active_plant_id']),
      currentBatchNumber: _readInt(
        data['current_batch_number'] ?? data['currentBatchNumber'],
      ),
      ecosystemStartDate: startDate,
      isSystemActive: _readBool(
        data['is_system_active'] ?? data['isSystemActive'],
      ),
      sensorAverages: _readMap(
        data['sensor_averages'] ?? data['sensorAverages'],
      ),
      harvestTotals: _readMap(
        data['harvest_totals'] ?? data['harvestTotals'],
      ),
      provisionCode: _readString(
        data['provision_code'] ?? data['provisionCode'],
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'system_name': systemName,
      'hardware_uid': hardwareUid,
      'active_fish_id': activeFishId,
      'active_plant_id': activePlantId,
      'current_batch_number': currentBatchNumber,
      if (ecosystemStartDate != null)
        'ecosystem_start_date': Timestamp.fromDate(ecosystemStartDate!),
      'is_system_active': isSystemActive,
      'sensor_averages': sensorAverages,
      'harvest_totals': harvestTotals,
      'provision_code': provisionCode,
    };
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }
}
