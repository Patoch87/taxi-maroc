import 'package:flutter/material.dart';

import '../main.dart';
import '../services/account.dart';
import '../services/schedule.dart';
import '../services/tourism.dart';
import '../theme.dart';
import 'sheets.dart';

/// Réservation d'une table au restaurant (démo : le restaurant n'est pas prévenu).
class TableBooking {
  const TableBooking({required this.restaurant, required this.at, required this.people, required this.name});
  final Restaurant restaurant;
  final DateTime at;
  final int people;
  final String name;
}

/// Nom proposé par défaut : celui du compte, sinon un nom de démonstration.
String defaultBookingName() {
  final a = accountStore.account;
  if (a == null) return 'Yasmine B.';
  return '${a.firstName} ${a.lastName}'.trim();
}

/// Heure proposée : ce soir 20:00, ou demain 20:00 s'il est déjà tard.
DateTime defaultBookingTime({DateTime? now}) {
  final n = now ?? DateTime.now();
  final tonight = DateTime(n.year, n.month, n.day, 20);
  return n.isBefore(tonight.subtract(const Duration(hours: 1))) ? tonight : tonight.add(const Duration(days: 1));
}

/// Panneau « Réserver une table » : date, heure, nombre de personnes et nom (prérempli).
Future<TableBooking?> showTableBookingSheet(BuildContext context, Restaurant r) => showModalBottomSheet<TableBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => TableBookingSheet(restaurant: r),
    );

class TableBookingSheet extends StatefulWidget {
  const TableBookingSheet({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  State<TableBookingSheet> createState() => _TableBookingSheetState();
}

class _TableBookingSheetState extends State<TableBookingSheet> {
  late DateTime _at = defaultBookingTime();
  int _people = 2;
  late final _name = TextEditingController(text: defaultBookingName());

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(today) ? today : _at,
      firstDate: today,
      lastDate: today.add(const Duration(days: maxScheduleDays)),
      helpText: s.t('bookDate'),
    );
    if (d != null && mounted) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  Future<void> _pickTime() async {
    final t =
        await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at), helpText: s.t('bookTime'));
    if (t != null && mounted) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  String get _dateText {
    final label = scheduleLabel(_at, lang: s.lang);
    // « Aujourd'hui 20:00 » → « Aujourd'hui » (l'heure est sur sa propre ligne).
    return label.substring(0, label.length - 6);
  }

  Widget _row(IconData icon, String label, String value, VoidCallback onTap) => Semantics(
        button: true,
        label: '$label : $value',
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(icon, color: AppColors.moroccoGreen),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Icon(Icons.expand_more, color: AppColors.muted),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            sheetHeader(s.t('bookTable'), icon: Icons.table_restaurant, color: AppColors.taxiRed),
            Text(r.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${s.t(r.cuisineKey)} · ${r.priceMad}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            _row(Icons.event, s.t('bookDate'), _dateText, _pickDate),
            const SizedBox(height: 8),
            _row(Icons.schedule, s.t('bookTime'), hhmm(_at), _pickTime),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.people_alt_outlined, color: AppColors.moroccoGreen),
                const SizedBox(width: 12),
                Expanded(child: Text(s.t('people'), style: const TextStyle(color: AppColors.muted))),
                IconButton(
                  tooltip: s.t('fewerPeople'),
                  onPressed: _people > 1 ? () => setState(() => _people--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Semantics(
                  liveRegion: true,
                  label: '${s.t('people')} : $_people',
                  excludeSemantics: true,
                  child: Text('$_people', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: s.t('morePeople'),
                  onPressed: _people < 12 ? () => setState(() => _people++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: s.t('bookName'),
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Text(s.t('bookingDemo'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                TableBooking(
                  restaurant: r,
                  at: _at,
                  people: _people,
                  name: _name.text.trim().isEmpty ? defaultBookingName() : _name.text.trim(),
                ),
              ),
              icon: const Icon(Icons.check),
              label: Text(s.t('bookConfirm')),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Confirmation « Table réservée » ; renvoie true si le passager veut y aller en taxi à l'heure de la réservation.
class TableBookedScreen extends StatelessWidget {
  const TableBookedScreen({super.key, required this.booking});
  final TableBooking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('tableBooked'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.moroccoGreen),
          const SizedBox(height: 8),
          Text(s.t('tableBooked'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.restaurant, color: AppColors.taxiRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(b.restaurant.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('${s.t('tableFor')} ${b.people} · ${scheduleLabel(b.at, lang: s.lang)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text('${s.t('bookName')} ${b.name}', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(s.t('bookingDemo'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.local_taxi),
            label: Text(s.t('taxiAtBooking'), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('close'))),
        ]),
      ),
    );
  }
}
