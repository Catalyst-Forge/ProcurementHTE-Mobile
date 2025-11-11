enum ApprovalAction { approve, reject }

extension ApprovalActionX on ApprovalAction {
  String get label =>
      this == ApprovalAction.approve ? 'Approve' : 'Reject';
  String get apiValue =>
      this == ApprovalAction.approve ? 'Approve' : 'Reject';
  String get pastTense =>
      this == ApprovalAction.approve ? 'di-approve' : 'di-reject';

  static ApprovalAction? fromString(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    return {
      'approve': ApprovalAction.approve,
      'approved': ApprovalAction.approve,
      'reject': ApprovalAction.reject,
      'rejected': ApprovalAction.reject,
    }[normalized];
  }
}

class ApprovalRoleInfo {
  const ApprovalRoleInfo({
    required this.roleId,
    required this.roleName,
    required this.woDocumentApprovalId,
    this.level,
    this.sequenceOrder,
  });

  final String roleId;
  final String roleName;
  final String woDocumentApprovalId;
  final int? level;
  final int? sequenceOrder;

  factory ApprovalRoleInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ApprovalRoleInfo(
        roleId: '',
        roleName: '',
        woDocumentApprovalId: '',
      );
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return ApprovalRoleInfo(
      roleId: (map['RoleId'] ?? '').toString(),
      roleName: (map['RoleName'] ?? '').toString(),
      woDocumentApprovalId:
          (map['WoDocumentApprovalId'] ?? '').toString(),
      level: parseInt(map['Level']),
      sequenceOrder: parseInt(map['SequenceOrder']),
    );
  }
}

class ApprovalUpdateResult {
  ApprovalUpdateResult({
    required this.ok,
    required this.reason,
    required this.message,
    required this.action,
    required this.approvalId,
    required this.workOrderId,
    required this.woDocumentId,
    required this.docStatus,
    required this.currentGateLevel,
    required this.currentGateSequence,
    required this.requiredRoles,
    required this.yourRoles,
    required this.alreadyApprovedByYou,
    required this.yourLastApprovalLevel,
    required this.yourLastApprovalSequence,
    required this.yourLastApprovalAt,
    required this.rejectedByUserId,
    required this.rejectedByUserName,
    required this.rejectedByFullName,
    required this.rejectedAt,
    required this.rejectNote,
    required this.when,
  });

  final bool ok;
  final String? reason;
  final String? message;
  final String? action;
  final String? approvalId;
  final String? workOrderId;
  final String? woDocumentId;
  final String? docStatus;
  final int? currentGateLevel;
  final int? currentGateSequence;
  final List<ApprovalRoleInfo> requiredRoles;
  final List<String> yourRoles;
  final bool? alreadyApprovedByYou;
  final int? yourLastApprovalLevel;
  final int? yourLastApprovalSequence;
  final DateTime? yourLastApprovalAt;
  final String? rejectedByUserId;
  final String? rejectedByUserName;
  final String? rejectedByFullName;
  final DateTime? rejectedAt;
  final String? rejectNote;
  final DateTime? when;

  ApprovalAction? get parsedAction => ApprovalActionX.fromString(action);

  bool get hasRoleDetail => requiredRoles.isNotEmpty || yourRoles.isNotEmpty;

  factory ApprovalUpdateResult.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final requiredRoles = <ApprovalRoleInfo>[];
    final rawRoles = map['RequiredRoles'];
    if (rawRoles is Iterable) {
      for (final item in rawRoles) {
        if (item is Map) {
          requiredRoles.add(
            ApprovalRoleInfo.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final yourRoles = <String>[];
    final rawYourRoles = map['YourRoles'];
    if (rawYourRoles is Iterable) {
      for (final item in rawYourRoles) {
        final value = item?.toString() ?? '';
        if (value.isNotEmpty) {
          yourRoles.add(value);
        }
      }
    }

    return ApprovalUpdateResult(
      ok: parseBool(map['Ok']),
      reason: map['Reason']?.toString(),
      message: map['Message']?.toString(),
      action: map['Action']?.toString(),
      approvalId: map['ApprovalId']?.toString(),
      workOrderId: map['WorkOrderId']?.toString(),
      woDocumentId: map['WoDocumentId']?.toString(),
      docStatus: map['DocStatus']?.toString(),
      currentGateLevel: parseInt(map['CurrentGateLevel']),
      currentGateSequence: parseInt(map['CurrentGateSequence']),
      requiredRoles: requiredRoles,
      yourRoles: yourRoles,
      alreadyApprovedByYou: map.containsKey('AlreadyApprovedByYou')
          ? (map['AlreadyApprovedByYou'] == null
              ? null
              : parseBool(map['AlreadyApprovedByYou']))
          : null,
      yourLastApprovalLevel: parseInt(map['YourLastApprovalLevel']),
      yourLastApprovalSequence: parseInt(map['YourLastApprovalSequence']),
      yourLastApprovalAt: parseDate(map['YourLastApprovalAt']),
      rejectedByUserId: map['RejectedByUserId']?.toString(),
      rejectedByUserName: map['RejectedByUserName']?.toString(),
      rejectedByFullName: map['RejectedByFullName']?.toString(),
      rejectedAt: parseDate(map['RejectedAt']),
      rejectNote: map['RejectNote']?.toString(),
      when: parseDate(map['When']),
    );
  }

  String buildHeadline() {
    if (ok) {
      final act = parsedAction;
      final actionText =
          act == ApprovalAction.approve ? 'Approve' : 'Reject';
      return '$actionText berhasil';
    }
    if (message != null && message!.isNotEmpty) return message!;
    if (reason != null && reason!.isNotEmpty) return reason!;
    return 'Approval gagal';
  }

  List<MapEntry<String, String>> buildDetails() {
    String? formatDate(DateTime? dt) {
      if (dt == null) return null;
      return dt.toLocal().toString();
    }

    final entries = <MapEntry<String, String>>[];
    if (docStatus != null && docStatus!.isNotEmpty) {
      entries.add(MapEntry('Status Dokumen', docStatus!));
    }
    if (requiredRoles.isNotEmpty) {
      final buffer = StringBuffer();
      for (var i = 0; i < requiredRoles.length; i++) {
        final role = requiredRoles[i];
        final label = role.roleName.isNotEmpty
            ? role.roleName
            : 'Role ${i + 1}';
        buffer.writeln('${i + 1}. $label');
      }
      entries.add(
        MapEntry('Role yang Diminta', buffer.toString().trim()),
      );
    }
    if (yourRoles.isNotEmpty) {
      entries.add(MapEntry('Role Anda', yourRoles.join(', ')));
    }
    if (alreadyApprovedByYou == true) {
      entries.add(
        MapEntry('Status Anda', 'Anda sudah approve dokumen ini.'),
      );
    }
    if (yourLastApprovalAt != null) {
      entries.add(MapEntry(
        'Approval Terakhir Anda',
        formatDate(yourLastApprovalAt!)!,
      ));
    }
    if (rejectedByFullName != null && rejectedByFullName!.isNotEmpty) {
      final rejectedTime = formatDate(rejectedAt);
      final by = rejectedTime == null
          ? rejectedByFullName!
          : '${rejectedByFullName!} ($rejectedTime)';
      entries.add(MapEntry('Ditolak Oleh', by));
    }
    if (rejectNote != null && rejectNote!.isNotEmpty) {
      entries.add(MapEntry('Catatan Penolakan', rejectNote!));
    }
    if (when != null) {
      entries.add(MapEntry('Dicatat Pada', formatDate(when!)!));
    }
    return entries;
  }
}
