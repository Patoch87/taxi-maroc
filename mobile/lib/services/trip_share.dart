import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import 'rides.dart';

/// Partage la position et les informations de la course (WhatsApp, SMS...).
Future<void> shareTrip({
  required LatLng position,
  required String destination,
  DemoDriver? driver,
  DateTime? arrival,
}) async {
  final h =
      arrival == null ? '' : '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  final lines = [
    '🚕 ${s.t('shareText')}',
    if (driver != null) '${driver.name} · ${driver.taxiNumber} · ${driver.plate} · ${driver.car}',
    '📍 ${s.t('onTrip')} $destination${h.isEmpty ? '' : ' · ${s.t('arrivalAt')} $h'}',
    '${s.t('myPosition')} : https://maps.google.com/?q=${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}',
  ];
  await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
}
