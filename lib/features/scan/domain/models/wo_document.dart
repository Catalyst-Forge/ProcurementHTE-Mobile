class WoDocument {
  WoDocument({
    required this.viewUrl,
    required this.woDocumentId,
    required this.workOrderId,
    required this.fileName,
    required this.status,
    required this.qrText,
    required this.objectKey,
    required this.createdByUserId,
    required this.createdByUserName,
    this.description,
    this.createdAt,
  });

  final String viewUrl;
  final String woDocumentId;
  final String workOrderId;
  final String fileName;
  final String status;
  final String qrText;
  final String objectKey;
  final String? description;
  final DateTime? createdAt;
  final String createdByUserId;
  final String createdByUserName;

  factory WoDocument.fromMap(Map<String, dynamic> map) {
    DateTime? created;
    final createdRaw = map['CreatedAt'];
    if (createdRaw is String && createdRaw.isNotEmpty) {
      try {
        created = DateTime.parse(createdRaw);
      } catch (_) {
        created = null;
      }
    }

    return WoDocument(
      viewUrl: (map['ViewUrl'] ?? '').toString(),
      woDocumentId: (map['WoDocumentId'] ?? '').toString(),
      workOrderId: (map['WorkOrderId'] ?? '').toString(),
      fileName: (map['FileName'] ?? '').toString(),
      status: (map['Status'] ?? '').toString(),
      qrText: (map['QrText'] ?? '').toString(),
      objectKey: (map['ObjectKey'] ?? '').toString(),
      description: map['Description']?.toString(),
      createdByUserId: (map['CreatedByUserId'] ?? '').toString(),
      createdByUserName: (map['CreatedByUserName'] ?? '').toString(),
      createdAt: created,
    );
  }
}
