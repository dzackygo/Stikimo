import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../image_import/presentation/new_sticker_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proyek saya')),
    body: PageBody(
      child: EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Belum ada proyek',
        description:
            'Proyek yang disimpan akan muncul di sini. '
            'Penyimpanan proyek sedang disiapkan.',
        action: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NewStickerScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Buat stiker'),
        ),
      ),
    ),
  );
}
