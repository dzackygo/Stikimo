import 'package:flutter/material.dart';

/// Fallback tidak bergantung pada theme/router yang mungkin gagal dibangun.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF8FAF7),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tampilan tidak dapat dimuat',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF26332E), fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
