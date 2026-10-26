import 'package:flutter/material.dart';

class EpgSourceDialog extends StatefulWidget {
  const EpgSourceDialog({super.key});

  @override
  State<EpgSourceDialog> createState() => _EpgSourceDialogState();
}

class _EpgSourceDialogState extends State<EpgSourceDialog> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fuente EPG XMLTV'),
      content: TextField(
        controller: _urlController,
        keyboardType: TextInputType.url,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'https://servidor/guia.xml',
          labelText: 'URL de la guía',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _urlController.text.trim()),
          child: const Text('Descargar'),
        ),
      ],
    );
  }
}
