import 'package:flutter/material.dart';

import '../main.dart';
import '../services/live.dart';
import '../theme.dart';

/// Menu : « Test réel » (relie les téléphones par le serveur) et l'adresse du serveur.
class LiveModeTile extends StatelessWidget {
  const LiveModeTile({super.key});

  Future<void> _editUrl(BuildContext context) async {
    final ctrl = TextEditingController(text: live.url);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('liveServer')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    if (url == null) return;
    live
      ..url = url
      ..enabled = url.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: live,
        builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            key: const ValueKey('liveMode'),
            secondary: const Icon(Icons.wifi_tethering, color: AppColors.moroccoGreen),
            title: Text(s.t('liveMode'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.t('liveModeDesc'), style: const TextStyle(color: AppColors.muted)),
            value: live.enabled,
            onChanged: (v) {
              if (v && live.url.isEmpty) {
                _editUrl(context);
              } else {
                live.enabled = v;
              }
            },
          ),
          if (live.enabled)
            ListTile(
              dense: true,
              leading: const SizedBox(width: 24),
              title: Text(s.t('liveServer')),
              subtitle: Text(live.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _editUrl(context),
            ),
        ]),
      );
}
