import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../Model/audit_log_model.dart';
import 'database_service.dart';
import 'session_service.dart';

enum AuditAction {
  createCustomer,
  updateCustomer,
  deleteCustomer,
  createProduct,
  updateProduct,
  deleteProduct,
  createSupplier,
  updateSupplier,
  deleteSupplier,
  createPurchase,
  createSale,
  cancelSale,
  stockIn,
  stockOut,
  stockAdjustment,
  stockTransfer,
  createUser,
  updateUser,
  deleteUser,
  changeRole,
  changePermission,
  cashOpen,
  cashClose,
  cashIncome,
  cashExpense,
  loginSuccess,
  loginFailed,
  logout,
}

extension AuditActionName on AuditAction {
  String get value => name.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)}',
      ).toUpperCase();
}

class AuditDataSanitizer {
  static const _sensitive = {
    'password',
    'password_hash',
    'token',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'secret',
    'secret_key',
    'apikey',
    'api_key',
    'cardnumber',
    'card_number',
    'cvv',
  };

  static dynamic sanitize(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (!_sensitive.contains(entry.key.toString().toLowerCase()))
            entry.key.toString(): sanitize(entry.value),
      };
    }
    if (value is Iterable) return value.map(sanitize).toList();
    if (value is DateTime) return value.toIso8601String();
    return value;
  }

  static Map<String, dynamic>? map(dynamic value) {
    final result = sanitize(value);
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }
}

class AuditService {
  static Future<void> log({
    required Object action,
    String? module,
    String? page,
    String? entity,
    Object? entityId,
    String? description,
    dynamic oldData,
    dynamic newData,
    dynamic metadata,
    String? controller,
    String? service,
    bool success = true,
    Object? error,
  }) async {
    try {
      final session = await SessionService.getCurrentUserSession();
      final model = AuditLogModel(
        userId: session?['uid']?.toString() ?? session?['id']?.toString(),
        userName: session?['name']?.toString(),
        userEmail: session?['email']?.toString(),
        userRole: session?['role']?.toString(),
        action: action is AuditAction ? action.value : action.toString(),
        module: module,
        page: page,
        entity: entity,
        entityId: entityId?.toString(),
        description: description,
        oldData: AuditDataSanitizer.map(oldData),
        newData: AuditDataSanitizer.map(newData),
        metadata: AuditDataSanitizer.map(metadata),
        controller: controller,
        service: service ?? 'DatabaseService',
        platform: _platformName,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        success: success,
        errorMessage: success ? null : _safeError(error),
      );
      await DatabaseService.insertAuditLog(model.toMap());
    } catch (_) {
      // La auditoría nunca debe romper la operación principal.
    }
  }

  static Future<List<AuditLogModel>> query({
    String? search,
    String? userId,
    String? action,
    String? module,
    String? entity,
    DateTime? from,
    DateTime? to,
    bool? success,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await DatabaseService.getAuditLogs(
      search: search,
      userId: userId,
      action: action,
      module: module,
      entity: entity,
      from: from,
      to: to,
      success: success,
      limit: limit,
      offset: offset,
    );
    return rows.map(AuditLogModel.fromMap).toList();
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static String? _safeError(Object? error) {
    if (error == null) return null;
    final sanitized = AuditDataSanitizer.sanitize(error.toString());
    return jsonEncode(sanitized).replaceAll(RegExp(r'"'), '');
  }
}