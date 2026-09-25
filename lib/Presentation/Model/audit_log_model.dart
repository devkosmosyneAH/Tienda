import 'dart:convert';

class AuditLogModel {
  const AuditLogModel({
    this.id,
    this.userId,
    this.userName,
    this.userEmail,
    this.userRole,
    required this.action,
    this.module,
    this.page,
    this.entity,
    this.entityId,
    this.description,
    this.oldData,
    this.newData,
    this.metadata,
    this.controller,
    this.service,
    this.platform,
    required this.createdAt,
    this.success = true,
    this.errorMessage,
    this.ipAddress,
    this.deviceInfo,
  });

  final int? id;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userRole;
  final String action;
  final String? module;
  final String? page;
  final String? entity;
  final String? entityId;
  final String? description;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final Map<String, dynamic>? metadata;
  final String? controller;
  final String? service;
  final String? platform;
  final String createdAt;
  final bool success;
  final String? errorMessage;
  final String? ipAddress;
  final String? deviceInfo;

  static Map<String, dynamic>? _decode(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    }
    return null;
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      id: (map['id'] as num?)?.toInt(),
      userId: map['user_id']?.toString(),
      userName: map['user_name']?.toString(),
      userEmail: map['user_email']?.toString(),
      userRole: map['user_role']?.toString(),
      action: map['action']?.toString() ?? 'UNKNOWN',
      module: map['module']?.toString(),
      page: map['page']?.toString(),
      entity: map['entity']?.toString(),
      entityId: map['entity_id']?.toString(),
      description: map['description']?.toString(),
      oldData: _decode(map['old_data']),
      newData: _decode(map['new_data']),
      metadata: _decode(map['metadata']),
      controller: map['controller']?.toString(),
      service: map['service']?.toString(),
      platform: map['platform']?.toString(),
      createdAt: map['created_at']?.toString() ?? '',
      success: map['success'] == 1 || map['success'] == true,
      errorMessage: map['error_message']?.toString(),
      ipAddress: map['ip_address']?.toString(),
      deviceInfo: map['device_info']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'user_role': userRole,
        'action': action,
        'module': module,
        'page': page,
        'entity': entity,
        'entity_id': entityId,
        'description': description,
        'old_data': oldData == null ? null : jsonEncode(oldData),
        'new_data': newData == null ? null : jsonEncode(newData),
        'metadata': metadata == null ? null : jsonEncode(metadata),
        'controller': controller,
        'service': service,
        'platform': platform,
        'created_at': createdAt,
        'success': success ? 1 : 0,
        'error_message': errorMessage,
        'ip_address': ipAddress,
        'device_info': deviceInfo,
      };

  factory AuditLogModel.fromJson(String source) =>
      AuditLogModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode(toMap());
}