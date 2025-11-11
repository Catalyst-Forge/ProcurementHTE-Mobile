import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net;
import '../domain/models/approval_update_result.dart';
import '../domain/models/wo_document.dart';
import '../domain/models/wo_document_list.dart';
import 'wo_document_service.dart';

final woDocumentServiceProvider = Provider<WoDocumentService>(
  (ref) => WoDocumentService(ref.read(net.dioProvider)),
);

final woDocumentRepositoryProvider = Provider<WoDocumentRepository>(
  (ref) => WoDocumentRepository(ref.read(woDocumentServiceProvider)),
);

class WoDocumentRepository {
  WoDocumentRepository(this._service);

  final WoDocumentService _service;

  Future<WoDocument> fetchByQr(String qrText) async {
    try {
      final raw = await _service.getByQr(qrText);
      final success = raw['Success'] == true;
      if (!success) {
        final message = raw['Message']?.toString();
        throw net.AppFailure(message ?? 'Dokumen tidak ditemukan.');
      }

      final data = raw['Data'];
      if (data is! Map<String, dynamic>) {
        throw net.AppFailure('Data dokumen tidak valid.');
      }
      final doc = WoDocument.fromMap(data);
      if (doc.viewUrl.isEmpty) {
        throw net.AppFailure('URL dokumen tidak tersedia.');
      }
      return doc;
    } on DioException catch (e) {
      throw net.mapDioError(e);
    }
  }

  Future<WoDocumentListResult> fetchListByQr({
    required String qrText,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final raw = await _service.listByQr(
        qrText: qrText,
        page: page,
        pageSize: pageSize,
      );
      final success = raw['Success'] == true;
      if (!success) {
        final message = raw['Message']?.toString();
        throw net.AppFailure(message ?? 'Daftar dokumen tidak ditemukan.');
      }

      final data = raw['Data'];
      final meta = raw['Meta'];

      final items = <WoDocument>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            items.add(WoDocument.fromMap(item));
          }
        }
      }
      final info = WoDocumentListMeta.fromMap(
        meta is Map<String, dynamic> ? meta : null,
      );

      return WoDocumentListResult(items: items, meta: info);
    } on DioException catch (e) {
      throw net.mapDioError(e);
    }
  }

  Future<ApprovalUpdateResult> updateApprovalStatusByDocumentId({
    required String woDocumentId,
    required ApprovalAction action,
    String? note,
  }) async {
    try {
      final raw = await _service.updateApprovalByDocumentId(
        woDocumentId: woDocumentId,
        action: action.apiValue,
        note: note,
      );
      if (raw.isEmpty) {
        throw net.AppFailure('Respon approval kosong.');
      }
      return ApprovalUpdateResult.fromMap(raw);
    } on DioException catch (e) {
      throw net.mapDioError(e);
    }
  }
}

typedef WoDocumentListQuery = ({
  String qrText,
  int page,
  int pageSize,
});

final woDocumentsByQrProvider = FutureProvider.autoDispose
    .family<WoDocumentListResult, WoDocumentListQuery>((ref, query) {
  final repo = ref.read(woDocumentRepositoryProvider);
  return repo.fetchListByQr(
    qrText: query.qrText,
    page: query.page,
    pageSize: query.pageSize,
  );
});
