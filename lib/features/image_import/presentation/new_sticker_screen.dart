import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';

class NewStickerScreen extends StatelessWidget {
  const NewStickerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buat stiker')),
    body: const PageBody(
      child: EmptyState(
        icon: Icons.add_photo_alternate_outlined,
        title: 'Mulai dari foto',
        description:
            'Pemilihan foto sedang disiapkan. '
            'Nantinya kamu dapat memilih foto lokal untuk membuat stiker.',
      ),
    ),
  );
}
