import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang & privasi')),
    body: const PageBody(
      child: EmptyState(
        icon: Icons.privacy_tip_outlined,
        title: 'Dibuat di perangkatmu',
        description:
            'Stikimo tidak memakai akun, iklan, analitik, atau '
            'unggahan foto. Pemrosesan gambar dirancang berjalan lokal '
            'tanpa AI/ML.\n\n'
            'Penghapus latar klasik paling cocok untuk latar polos. '
            'Latar yang rumit memerlukan perbaikan manual.\n\n'
            'Versi pengembangan ini masih menyiapkan fitur editor, '
            'penyimpanan, dan paket WhatsApp.',
      ),
    ),
  );
}
