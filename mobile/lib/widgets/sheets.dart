import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../screens/complaint_screen.dart';
import '../screens/trusted_contacts_screen.dart';
import '../services/settings.dart';
import '../theme.dart';

/// Poignée et titre communs aux panneaux qui montent du bas.
Widget sheetHeader(String title, {IconData? icon, Color? color}) => Column(children: [
      Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
      ),
      Row(children: [
        if (icon != null) ...[Icon(icon, color: color ?? AppColors.ink), const SizedBox(width: 10)],
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
        ),
      ]),
      const SizedBox(height: 14),
    ]);

/// Sécurité et réclamations, accessibles pendant la commande et la course.
Future<void> showSafetySheet(BuildContext context, {String? taxiId, required VoidCallback onShare}) {
  Future<void> call(String n) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: n));
    } catch (_) {}
  }

  final contacts = settings.contacts;
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.sand,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          sheetHeader(s.t('safety'), icon: Icons.shield_rounded, color: AppColors.moroccoGreen),
          // Gros bouton SOS
          Material(
            color: AppColors.taxiRed,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                onShare();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AppColors.taxiRed,
                  content: Text(s.t('sosSent'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text('SOS', style: TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.t('sos'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(s.t('sosDesc'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Contacts de confiance : un geste pour appeler.
          Row(children: [
            Expanded(
              child: Text(s.t('trustedContacts'),
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TrustedContactsScreen()));
              },
              child: Text(contacts.isEmpty ? s.t('addContact') : s.t('manage'),
                  style: const TextStyle(color: AppColors.moroccoGreen, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (contacts.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final c in contacts)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Semantics(
                      button: true,
                      label: '${s.t('call')} ${c.name}',
                      excludeSemantics: true,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.line, width: 1.5)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => call(c.phone),
                          child: SizedBox(
                            width: 96,
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Stack(clipBehavior: Clip.none, children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.greenSoft,
                                  foregroundColor: AppColors.moroccoGreen,
                                  child: Text(c.name.characters.first.toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                const PositionedDirectional(
                                  end: -4,
                                  bottom: -4,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.moroccoGreen,
                                    child: Icon(Icons.call, size: 12, color: Colors.white),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          Text(s.t('emergencyNumbers'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            for (final (label, n) in [(s.t('police'), '19'), (s.t('gendarmerie'), '177'), (s.t('ambulance'), '15')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
                    onPressed: () => call(n),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_in_talk, size: 20),
                      const SizedBox(height: 4),
                      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
                backgroundColor: AppColors.greenSoft, child: Icon(Icons.share_location, color: AppColors.moroccoGreen)),
            title: Text(s.t('shareTrip'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(ctx);
              onShare();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
                backgroundColor: AppColors.redSoft, child: Icon(Icons.flag_rounded, color: AppColors.taxiRed)),
            title: Text(s.t('complain'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintScreen(taxiId: taxiId)));
            },
          ),
        ]),
      ),
    ),
  );
}

/// Messages rapides au chauffeur, traduits dans sa langue (darija).
Future<void> showChatSheet(BuildContext context, {required String driverName}) {
  const keys = ['quickHere', 'quickComing', 'quickWait', 'quickLuggage'];
  final sent = <String>[];
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.sand,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            sheetHeader(driverName, icon: Icons.chat_bubble_rounded),
            for (final k in sent) ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(s.t(k), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    if (langNotifier.value != 'dr')
                      Text('${s.t('translatedFor')} : ${S('dr').t(k)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Text(s.t('driverReplyOk'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in keys)
                ActionChip(
                  label: Text(s.t(k)),
                  backgroundColor: Colors.white,
                  shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
                  onPressed: () => setSheet(() => sent.add(k)),
                ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

/// Choix du passager : « Pour moi » (null) ou une autre personne (nom et téléphone).
/// Renvoie null si le panneau est fermé sans valider.
Future<({TrustedContact? other})?> showPassengerSheet(BuildContext context, {TrustedContact? current}) {
  final name = TextEditingController(text: current?.name);
  final phone = TextEditingController(text: current?.phone);
  var forOther = current != null;
  return showModalBottomSheet<({TrustedContact? other})>(
    context: context,
    backgroundColor: AppColors.sand,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final ok = !forOther || (name.text.trim().isNotEmpty && phone.text.trim().isNotEmpty);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              sheetHeader(s.t('whoRides'), icon: Icons.person_pin_circle_rounded, color: AppColors.moroccoGreen),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.moroccoGreen,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.person), label: Text(s.t('forMe'))),
                  ButtonSegment(value: true, icon: const Icon(Icons.group), label: Text(s.t('forSomeoneElse'))),
                ],
                selected: {forOther},
                onSelectionChanged: (v) => setSheet(() => forOther = v.first),
              ),
              if (forOther) ...[
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('passengerName'),
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setSheet(() {}),
                  decoration: _field(s.t('passengerName'), Icons.badge_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('passengerPhone'),
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setSheet(() {}),
                  decoration: _field(s.t('phone'), Icons.phone_outlined),
                ),
                if (settings.contacts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(s.t('fromContacts'),
                      style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in settings.contacts)
                      ActionChip(
                        avatar: const Icon(Icons.person_outline, size: 18),
                        label: Text(c.name),
                        backgroundColor: Colors.white,
                        shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
                        onPressed: () => setSheet(() {
                          name.text = c.name;
                          phone.text = c.phone;
                        }),
                      ),
                  ]),
                ],
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ok
                    ? () => Navigator.pop(
                        ctx, (other: forOther ? TrustedContact(name.text.trim(), phone.text.trim()) : null))
                    : null,
                child: Text(s.t('validate')),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

InputDecoration _field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
