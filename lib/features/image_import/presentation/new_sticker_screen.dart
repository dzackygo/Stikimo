import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_body.dart';
import '../../projects/presentation/project_controller.dart';
import '../../projects/presentation/project_name_dialog.dart';
import '../../projects/presentation/project_screen.dart';
import '../domain/imported_image.dart';
import 'import_controller.dart';

class NewStickerScreen extends ConsumerStatefulWidget {
  const NewStickerScreen({super.key});

  @override
  ConsumerState<NewStickerScreen> createState() => _NewStickerScreenState();
}

class _NewStickerScreenState extends ConsumerState<NewStickerScreen> {
  bool _isSaving = false;

  Future<void> _save(ImportedImage image) async {
    final name = await showProjectNameDialog(context);
    if (name == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final saved = await ref.read(projectActionsProvider).create(image, name);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectScreen(projectId: saved.document.id),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(projectErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importControllerProvider);
    final image = state.image;
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
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
                const Text(
                  'Simpan sebagai proyek agar foto dapat dibuka kembali.',
                ),
                const SizedBox(height: 24),
              ],
              if (state.isBusy || _isSaving) ...[
                const LinearProgressIndicator(
                  semanticsLabel: 'Menyiapkan foto',
                ),
                const SizedBox(height: 12),
                Text(_isSaving ? 'Menyimpan proyek…' : 'Menyiapkan foto…'),
                const SizedBox(height: 16),
              ],
              if (state.message != null) ...[
                Semantics(liveRegion: true, child: Text(state.message!)),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: state.isBusy || _isSaving
                    ? null
                    : ref.read(importControllerProvider.notifier).pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(image == null ? 'Pilih foto' : 'Ganti foto'),
              ),
              if (image != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isBusy || _isSaving
                      ? null
                      : () => _save(image),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan proyek'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
