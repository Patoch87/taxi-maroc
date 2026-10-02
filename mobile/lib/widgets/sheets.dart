import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../screens/complaint_screen.dart';
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
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 14),
    ]);

/// Sécurité et réclamations, accessibles pendant la commande et la course.
Future<void> showSafetySheet(BuildContext context, {String? taxiId, required VoidCallback onShare}) {
  Future<void> call(String n) async {
    await launchUrl(Uri(scheme: 'tel', path: n));
  }

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
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
                backgroundColor: Color(0xFFE8F3EC), child: Icon(Icons.share_location, color: AppColors.moroccoGreen)),
            title: Text(s.t('shareTrip'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(ctx);
              onShare();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
                backgroundColor: Color(0xFFFBEAEA), child: Icon(Icons.flag_rounded, color: AppColors.taxiRed)),
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
    backgroundColor: Colors.white,
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
                  decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(16)),
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
