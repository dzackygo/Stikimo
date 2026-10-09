import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_body.dart';
import 'import_controller.dart';

class NewStickerScreen extends ConsumerWidget {
  const NewStickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    final image = state.image;
    return Scaffold(
      appBar: AppBar(title: const Text('Buat stiker')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Mulai dari foto',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Pilih JPEG atau PNG dari perangkatmu. Maksimal 32 MB, '
              '16 megapiksel, dan sisi 8192 piksel. Foto asli tetap utuh.',
            ),
            const SizedBox(height: 24),
            if (image != null) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Image.file(
                    File(image.previewPath),
                    semanticLabel: 'Preview foto pilihan',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text(
                      'Preview tidak dapat dibuka. Pilih ulang foto.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Foto siap · ${image.width} × ${image.height} piksel'),
              const Text('Editor dan penyimpanan proyek sedang disiapkan.'),
              const SizedBox(height: 24),
            ],
            if (state.isBusy) ...[
              const LinearProgressIndicator(semanticsLabel: 'Menyiapkan foto'),
              const SizedBox(height: 12),
              const Text('Menyiapkan foto…'),
              const SizedBox(height: 16),
            ],
            if (state.message != null) ...[
              Semantics(liveRegion: true, child: Text(state.message!)),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: state.isBusy
                  ? null
                  : ref.read(importControllerProvider.notifier).pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(image == null ? 'Pilih foto' : 'Ganti foto'),
            ),
          ],
        ),
      ),
    );
  }
}
