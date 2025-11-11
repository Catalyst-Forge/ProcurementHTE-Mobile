import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.visible = false});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Stack(
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: 0.3),
          dismissible: false,
        ),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
