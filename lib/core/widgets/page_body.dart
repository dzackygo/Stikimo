import 'package:flutter/material.dart';

/// Konten halaman sederhana tetap terbaca pada layar kecil dan teks diperbesar.
class PageBody extends StatelessWidget {
  const PageBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    ),
  );
}
