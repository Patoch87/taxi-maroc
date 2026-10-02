import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api.dart';

const _motifs = {
  'refus': 'Refus de course',
  'prix_abusif': 'Prix abusif',
  'conduite_dangereuse': 'Conduite dangereuse',
  'comportement': 'Comportement',
  'objet_oublie': 'Objet oublié',
  'autre': 'Autre',
};

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key, this.taxiId});
  final String? taxiId;

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  String _motif = 'prix_abusif';
  final _text = TextEditingController();

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api().complain(taxiId: widget.taxiId, motif: _motif, message: _text.text);
      messenger.showSnackBar(SnackBar(content: Text(s.t('complaintSent'))));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.t('error'))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(s.t('complain'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RadioGroup<String>(
              groupValue: _motif,
              onChanged: (v) => setState(() => _motif = v!),
              child: Column(
                children: [
                  for (final e in _motifs.entries) RadioListTile<String>(title: Text(e.value), value: e.key),
                ],
              ),
            ),
            TextField(controller: _text, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(onPressed: _send, child: Text(s.t('send'))),
          ],
        ),
      );
}
