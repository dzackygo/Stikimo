import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../image_import/presentation/new_sticker_screen.dart';
import 'project_controller.dart';
import 'project_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Proyek saya')),
    body: ref
        .watch(projectListProvider)
        .when(
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Memuat proyek'),
          ),
          error: (error, _) => PageBody(
            child: EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Proyek belum dapat dibuka',
              description: projectErrorMessage(error),
              action: FilledButton(
                onPressed: () => ref.read(projectActionsProvider).retry(),
                child: const Text('Coba lagi'),
              ),
            ),
          ),
          data: (projects) {
            if (projects.isEmpty) {
              return PageBody(
                child: EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Belum ada proyek',
                  description: 'Simpan foto pertamamu sebagai proyek agar bisa dibuka kembali.',
                  action: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NewStickerScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Buat stiker'),
                  ),
                ),
              );
            }
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final date = MaterialLocalizations.of(context)
                          .formatMediumDate(project.updatedAt.toLocal());
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.layers_outlined),
                          title: Text(project.name),
                          subtitle: Text('Disimpan $date'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProjectScreen(projectId: project.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
  );
}
