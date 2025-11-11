import 'package:flutter_riverpod/flutter_riverpod.dart';

final splashVisibleProvider = NotifierProvider<SplashController, bool>(
  SplashController.new,
);

class SplashController extends Notifier<bool> {
  @override
  bool build() => false; // awalnya tidak terlihat, lalu ditrigger visible

  void show() => state = true;
}
