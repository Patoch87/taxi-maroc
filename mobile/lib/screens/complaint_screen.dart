import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api.dart';
import '../theme.dart';

const _motifs = {
  'refus': ('motifRefus', Icons.block),
  'prix_abusif': ('motifPrix', Icons.money_off),
  'conduite_dangereuse': ('motifConduite', Icons.speed),
  'comportement': ('motifComportement', Icons.sentiment_dissatisfied),
  'objet_oublie': ('motifObjet', Icons.work_outline),
  'autre': ('motifAutre', Icons.more_horiz),
};

/// Réclamation sur une course : motif, description, envoi.
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(s.t('complain'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.taxiId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(widget.taxiId!, style: const TextStyle(color: AppColors.muted)),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _motifs.entries)
                ChoiceChip(
                  avatar: Icon(e.value.$2, size: 18, color: _motif == e.key ? Colors.white : AppColors.ink),
                  label: Text(s.t(e.value.$1)),
                  selected: _motif == e.key,
                  showCheckmark: false,
                  selectedColor: AppColors.ink,
                  labelStyle:
                      TextStyle(color: _motif == e.key ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _motif = e.key),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: s.t('describe'),
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _send, child: Text(s.t('send'))),
          ],
        ),
      );
}
