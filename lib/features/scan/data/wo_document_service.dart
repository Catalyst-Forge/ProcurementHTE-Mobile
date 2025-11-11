import 'package:dio/dio.dart';

class WoDocumentService {
  WoDocumentService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getByQr(String qrText) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/documents/resolve-qr',
      data: {'qrText': qrText},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listByQr({
    required String qrText,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/documents/by-qr',
      data: {'qrText': qrText, 'page': page, 'pageSize': pageSize},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateApprovalByDocumentId({
    required String woDocumentId,
    required String action,
    String? note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/approval/update-status-by-document-id',
      data: {
        'WoDocumentId': woDocumentId,
        'Action': action,
        'Note': note ?? '',
      },
    );
    return response.data ?? <String, dynamic>{};
  }
}
