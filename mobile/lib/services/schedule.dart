import '../l10n/strings.dart';

/// Réservation à l'avance : jusqu'à 30 jours, au moins 15 minutes avant le départ.
const maxScheduleDays = 30;
const minScheduleDelay = Duration(minutes: 15);

const _days = {
  'fr': ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'],
  'ar': ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
  'dr': ['الاثنين', 'الثلاث', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الحد'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'es': ['lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.', 'dom.'],
  'pt': ['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'],
  'de': ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'],
  'it': ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'],
  'nl': ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'],
  'pl': ['pon.', 'wt.', 'śr.', 'czw.', 'pt.', 'sob.', 'niedz.'],
  'hr': ['pon', 'uto', 'sri', 'čet', 'pet', 'sub', 'ned'],
  'sr': ['pon', 'uto', 'sre', 'čet', 'pet', 'sub', 'ned'],
  'da': ['man.', 'tirs.', 'ons.', 'tors.', 'fre.', 'lør.', 'søn.'],
  'ja': ['月', '火', '水', '木', '金', '土', '日'],
  'ko': ['월', '화', '수', '목', '금', '토', '일'],
  'fa': ['دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'],
};

const _months = {
  'fr': ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو', 'يوليوز', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر'],
  'dr': ['يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو', 'يوليوز', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'es': ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'],
  'pt': ['jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'],
  'de': ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.'],
  'it': ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'],
  'nl': ['jan.', 'feb.', 'mrt.', 'apr.', 'mei', 'jun.', 'jul.', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.'],
  'pl': ['sty', 'lut', 'mar', 'kwi', 'maj', 'cze', 'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'],
  'hr': ['sij', 'velj', 'ožu', 'tra', 'svi', 'lip', 'srp', 'kol', 'ruj', 'lis', 'stu', 'pro'],
  'sr': ['jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'avg', 'sep', 'okt', 'nov', 'dec'],
  'da': ['jan.', 'feb.', 'mar.', 'apr.', 'maj', 'jun.', 'jul.', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.'],
  'fa': ['ژانویه', 'فوریه', 'مارس', 'آوریل', 'مه', 'ژوئن', 'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر'],
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
  // Japonais et coréen : mois, jour, puis le jour de la semaine entre parenthèses.
  if (l == 'ja') return '${when.month}月${when.day}日($dayName) ${hhmm(when)}';
  if (l == 'ko') return '${when.month}월 ${when.day}일 ($dayName) ${hhmm(when)}';
  final month = _months[l]![when.month - 1];
  // Anglais, allemand, néerlandais, danois... : « Mon 5 Oct 08:30 » ; allemand et danois ajoutent un point au jour.
  final day = l == 'de' || l == 'da' ? '${when.day}.' : '${when.day}';
  return '$dayName $day $month ${hhmm(when)}';
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
