import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net;

class DocumentViewerPage extends ConsumerStatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.url,
    required this.fileName,
  });

  final String url;
  final String fileName;

  @override
  ConsumerState<DocumentViewerPage> createState() =>
      _DocumentViewerPageState();
}

class _DocumentViewerPageState
    extends ConsumerState<DocumentViewerPage> {
  String? _localPath;
  String? _error;
  bool _downloading = true;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfController;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'wo-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';
      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
          connectTimeout: const Duration(seconds: 20),
          followRedirects: true,
        ),
      );
      final response = await dio.get<List<int>>(
        widget.url,
        options: Options(
          headers: const {'Accept': 'application/pdf'},
        ),
      );
      final bytes = response.data;
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw net.AppFailure(
          status == 400
              ? 'Link dokumen sudah tidak berlaku. Mohon scan ulang.'
              : 'Gagal mengunduh dokumen (status $status).',
        );
      }
      if (bytes == null || bytes.isEmpty) {
        throw net.AppFailure('File dokumen kosong.');
      }
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _localPath = file.path;
        _downloading = false;
      });
    } on DioException catch (e) {
      final mapped = net.mapDioError(e);
      if (!mounted) return;
      setState(() {
        _error = mapped.message;
        _downloading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is net.AppFailure ? e.message : e.toString();
        _downloading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.fileName.isEmpty ? 'Dokumen' : widget.fileName;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1}/$_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_downloading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _download,
      );
    }
    final path = _localPath;
    if (path == null) {
      return _ErrorView(
        message: 'Lokasi file tidak ditemukan.',
        onRetry: _download,
      );
    }

    return PDFView(
      filePath: path,
      autoSpacing: true,
      enableSwipe: true,
      swipeHorizontal: false,
      pageFling: true,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onViewCreated: (controller) {
        _pdfController = controller;
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? _totalPages;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString();
        });
      },
      onPageError: (page, error) {
        if (!mounted) return;
        setState(() {
          _error = 'Gagal memuat halaman ${page ?? '-'}: $error';
        });
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 16),
          Text(
            'Tidak dapat membuka dokumen',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
