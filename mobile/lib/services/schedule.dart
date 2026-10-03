import '../l10n/strings.dart';

/// Réservation à l'avance : jusqu'à 30 jours, au moins 15 minutes avant le départ.
const maxScheduleDays = 30;
const minScheduleDelay = Duration(minutes: 15);

const _days = {
  'fr': ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'],
  'ar': ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
  'dr': ['الاثنين', 'الثلاث', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الحد'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
};

const _months = {
  'fr': ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو', 'يوليوز', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر'],
  'dr': ['يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو', 'يوليوز', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
};

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Libellé court d'une course réservée : « Aujourd'hui 14:00 », « Demain 08:30 », « Lun. 6 oct. 08:30 ».
String scheduleLabel(DateTime when, {required String lang, DateTime? now}) {
  final s = S(lang);
  final n = now ?? DateTime.now();
  // Dates en UTC pour compter les jours sans être gêné par le changement d'heure.
  final diff = DateTime.utc(when.year, when.month, when.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  if (diff == 0) return '${s.t('today')} ${hhmm(when)}';
  if (diff == 1) return '${s.t('tomorrow')} ${hhmm(when)}';
  final l = _days.containsKey(lang) ? lang : 'fr';
  final dayName = _days[l]![when.weekday - 1];
  final month = _months[l]![when.month - 1];
  return '$dayName ${when.day} $month ${hhmm(when)}';
}

/// Corrige une date choisie : au moins 15 minutes après maintenant, au plus 30 jours.
DateTime clampSchedule(DateTime wanted, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final earliest = n.add(minScheduleDelay);
  if (wanted.isBefore(earliest)) {
    // Arrondi aux 5 minutes suivantes.
    final extra = (5 - earliest.minute % 5) % 5;
    return DateTime(earliest.year, earliest.month, earliest.day, earliest.hour, earliest.minute + extra);
  }
  final latest = DateTime(n.year, n.month, n.day + maxScheduleDays, 23, 59);
  return wanted.isAfter(latest) ? latest : wanted;
}
