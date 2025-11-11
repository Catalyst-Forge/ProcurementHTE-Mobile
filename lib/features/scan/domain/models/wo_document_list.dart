import 'wo_document.dart';

class WoDocumentListResult {
  WoDocumentListResult({
    required this.items,
    required this.meta,
  });

  final List<WoDocument> items;
  final WoDocumentListMeta meta;
}

class WoDocumentListMeta {
  WoDocumentListMeta({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  factory WoDocumentListMeta.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return WoDocumentListMeta(
        page: 1,
        pageSize: 0,
        totalItems: 0,
        totalPages: 1,
      );
    }
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    int ensurePositive(int value, {int fallback = 1}) =>
        value <= 0 ? fallback : value;

    return WoDocumentListMeta(
      page: ensurePositive(parseInt(map['Page'])),
      pageSize: ensurePositive(parseInt(map['PageSize']), fallback: 0),
      totalItems: ensurePositive(parseInt(map['TotalItems']), fallback: 0),
      totalPages: ensurePositive(parseInt(map['TotalPages'])),
    );
  }
}
