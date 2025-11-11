import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Menyimpan QR terakhir yang berhasil dipindai agar dapat digunakan
/// kembali dari halaman lain (mis: daftar dokumen).
class LastScannedQrNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setQr(String? value) => state = value;
}

final lastScannedQrProvider =
    NotifierProvider<LastScannedQrNotifier, String?>(
  LastScannedQrNotifier.new,
);
