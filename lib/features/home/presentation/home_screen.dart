import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../image_import/presentation/import_controller.dart';
import '../../image_import/presentation/new_sticker_screen.dart';
import '../../projects/presentation/projects_screen.dart';
import '../../whatsapp_packs/presentation/packs_screen.dart';
import 'about_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Recovery dimulai satu kali di awal aplikasi, di luar fase build.
    Future.microtask(() {
      if (mounted) ref.read(importControllerProvider.notifier).recover();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final importState = ref.watch(importControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stikimo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.auto_awesome_motion_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ruang untuk\nide kecilmu.',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Foto pribadi, tetap di perangkat.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Editor stiker sedang disiapkan.'),
                  if (importState.message != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(importState.message!),
                    ),
                  ],
                  if (importState.image != null) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _open(context, const NewStickerScreen()),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Lanjutkan foto pilihan'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _open(context, const NewStickerScreen()),
                    icon: const Icon(Icons.add),
                    label: const Text('Buat stiker'),
                  ),
                  const SizedBox(height: 16),
                  _Destination(
                    icon: Icons.folder_open_outlined,
                    label: 'Proyek saya',
                    onTap: () => _open(context, const ProjectsScreen()),
                  ),
                  _Destination(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'Paket stiker',
                    onTap: () => _open(context, const PacksScreen()),
                  ),
                  _Destination(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Tentang & privasi',
                    onTap: () => _open(context, const AboutScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
