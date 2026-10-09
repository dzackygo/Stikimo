import 'package:flutter/material.dart';

Future<String?> showProjectNameDialog(
  BuildContext context, {
  String initialName = 'Stiker baru',
  String title = 'Simpan proyek',
}) => showDialog<String>(
  context: context,
  builder: (_) => _ProjectNameDialog(initialName: initialName, title: title),
);

class _ProjectNameDialog extends StatefulWidget {
  const _ProjectNameDialog({required this.initialName, required this.title});
  final String initialName;
  final String title;

  @override
  State<_ProjectNameDialog> createState() => _ProjectNameDialogState();
}

class _ProjectNameDialogState extends State<_ProjectNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nama proyek'),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Isi nama proyek.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Simpan')),
    ],
  );
}
