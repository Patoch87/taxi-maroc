import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import 'rides.dart';
import 'schedule.dart';

/// Texte de la course : position, chauffeur, destination et heure d'arrivée.
/// Avec [forName], le message s'adresse à la personne pour qui le taxi a été commandé.
String tripText({
  required LatLng position,
  required String destination,
  DemoDriver? driver,
  DateTime? arrival,
  DateTime? pickupAt,
  String? forName,
}) {
  final h = arrival == null ? '' : hhmm(arrival);
  return [
    if (forName != null) '${s.t('helloName')} $forName, ${s.t('bookedForYou')}' else '🚕 ${s.t('shareText')}',
    if (pickupAt != null) '🕒 ${s.t('pickupAt')} ${hhmm(pickupAt)}',
    if (driver != null) '${driver.name} · ${driver.taxiNumber} · ${driver.plate} · ${driver.car}',
    '📍 ${s.t('onTrip')} $destination${h.isEmpty ? '' : ' · ${s.t('arrivalAt')} $h'}',
    '${forName != null ? s.t('pickupPoint') : s.t('myPosition')} : https://maps.google.com/?q=${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}',
  ].join('\n');
}

/// Ouvre le partage du téléphone (WhatsApp, SMS...). Sans effet si le partage n'est pas disponible.
Future<void> shareText(String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (_) {}
}

/// Partage la position et les informations de la course (WhatsApp, SMS...).
Future<void> shareTrip({
  required LatLng position,
  required String destination,
  DemoDriver? driver,
  DateTime? arrival,
  DateTime? pickupAt,
  String? forName,
}) =>
    shareText(tripText(
      position: position,
      destination: destination,
      driver: driver,
      arrival: arrival,
      pickupAt: pickupAt,
      forName: forName,
    ));
