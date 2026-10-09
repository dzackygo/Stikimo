import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';

class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Paket stiker')),
    body: const PageBody(
      child: EmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: 'Belum ada paket',
        description:
            'Satu paket membutuhkan 3–30 stiker. '
            'Pengelolaan paket dan penambahan ke WhatsApp sedang disiapkan.',
      ),
    ),
  );
}
