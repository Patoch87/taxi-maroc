import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';

/// Contacts de confiance (comme sur Uber) : jusqu'à 5 proches, appelés en un geste depuis la sécurité,
/// et prévenus automatiquement des trajets (toujours, la nuit ou jamais).
class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _add() {
    if (settings.addContact(TrustedContact(_name.text, _phone.text))) {
      _name.clear();
      _phone.clear();
      FocusScope.of(context).unfocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final contacts = settings.contacts;
    final canAdd = settings.canAddContact;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('trustedContacts'), style: const TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: const Zellige(opacity: .06),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(s.t('trustedDesc'), style: const TextStyle(color: AppColors.muted, fontSize: 15)),
          const SizedBox(height: 14),
          if (contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _card(),
              child: Row(children: [
                const Icon(Icons.people_outline, color: AppColors.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(s.t('noContacts'), style: const TextStyle(color: AppColors.muted))),
              ]),
            ),
          for (final c in contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _cardMaterial(ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.moroccoGreen,
                  child:
                      Text(c.name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(c.phone, style: const TextStyle(color: AppColors.muted)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: '${s.t('call')} ${c.name}',
                    color: AppColors.moroccoGreen,
                    icon: const Icon(Icons.call),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: c.phone)).catchError((_) => false),
                  ),
                  IconButton(
                    tooltip: '${s.t('remove')} ${c.name}',
                    color: AppColors.taxiRed,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => settings.removeContact(c)),
                  ),
                ]),
              )),
            ),
          const SizedBox(height: 12),
          // Ajout d'un contact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(canAdd ? s.t('addContact') : s.t('maxContacts'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (canAdd) ...[
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('contactName'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: _input(s.t('name'), Icons.person_outline),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('contactPhone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: _input(s.t('phone'), Icons.phone_outlined),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _name.text.trim().isEmpty || _phone.text.trim().isEmpty ? null : _add,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(s.t('add')),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          Text(s.t('autoShare'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _cardMaterial(
            RadioGroup<AutoShare>(
              groupValue: settings.autoShare,
              onChanged: (v) => setState(() => settings.autoShare = v ?? settings.autoShare),
              child: Column(children: [
                for (final (mode, key, icon) in [
                  (AutoShare.always, 'autoAlways', Icons.all_inclusive),
                  (AutoShare.night, 'autoNight', Icons.nightlight_round),
                  (AutoShare.never, 'autoNever', Icons.block),
                ])
                  RadioListTile<AutoShare>(
                    value: mode,
                    activeColor: AppColors.moroccoGreen,
                    secondary: Icon(icon, color: AppColors.muted),
                    title: Text(s.t(key), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte blanche arrondie qui porte elle-même l'effet d'appui des lignes de liste.
  Widget _cardMaterial(Widget child) => Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        child: child,
      );

  BoxDecoration _card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.5),
      );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.sand,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}
