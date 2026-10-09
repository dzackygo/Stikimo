import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';
import '../domain/project_document.dart';
import 'project_controller.dart';
import 'project_name_dialog.dart';

class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({required this.projectId, super.key});
  final String projectId;

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() operation) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(projectErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _rename(SavedProject project) async {
    final name = await showProjectNameDialog(
      context,
      initialName: project.document.name,
      title: 'Ganti nama proyek',
    );
    if (name == null || !mounted) return;
    await _run(() async {
      await ref.read(projectActionsProvider).rename(project, name);
    });
  }

  Future<void> _duplicate() => _run(() async {
    final copy = await ref
        .read(projectActionsProvider)
        .duplicate(widget.projectId);
    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProjectScreen(projectId: copy.document.id),
        ),
      );
    }
  });

  Future<void> _delete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus proyek?'),
        content: Text(
          'Proyek “$name” dan asetnya akan dihapus dari Stikimo. Foto asli di galeri tetap ada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await ref.read(projectActionsProvider).delete(widget.projectId);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedProjectProvider(widget.projectId));
    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Proyek')),
        body: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Memuat proyek'),
          ),
          error: (error, _) => PageBody(
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'Proyek belum dapat dibuka',
              description: projectErrorMessage(error),
              action: FilledButton(
                onPressed: () => ref
                    .read(projectActionsProvider)
                    .retry(projectId: widget.projectId),
                child: const Text('Coba lagi'),
              ),
            ),
          ),
          data: (project) {
            return PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.document.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  ref
                      .watch(projectPreviewPathProvider(widget.projectId))
                      .when(
                        loading: () => const LinearProgressIndicator(
                          semanticsLabel: 'Memuat foto proyek',
                        ),
                        error: (_, _) =>
                            const Text('Foto proyek tidak dapat ditampilkan.'),
                        data: (path) => path == null
                            ? const SizedBox.shrink()
                            : Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 320,
                                  ),
                                  child: Image.file(
                                    File(path),
                                    semanticLabel: 'Foto proyek',
                                    errorBuilder: (_, _, _) => const Text(
                                      'Foto proyek tidak dapat ditampilkan.',
                                    ),
                                  ),
                                ),
                              ),
                      ),
                  const SizedBox(height: 16),
                  const Text(
                    'Proyek tersimpan di perangkat. Editor layer sedang disiapkan.',
                  ),
                  const SizedBox(height: 24),
                  if (_isBusy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Menyimpan perubahan proyek',
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isBusy ? null : () => _rename(project),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Ganti nama'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isBusy ? null : _duplicate,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Duplikasi'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isBusy
                            ? null
                            : () => _delete(project.document.name),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus proyek'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
