import 'package:flutter/material.dart';

import '../main.dart';
import '../services/rides.dart';
import '../theme.dart';

/// Photo du chauffeur avec les drapeaux des langues qu'il parle en dessous.
class DriverPhoto extends StatelessWidget {
  const DriverPhoto({super.key, required this.driver, this.size = 64});
  final DemoDriver driver;
  final double size;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.grandTaxi,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image(
            image: photoImage(driver.photo),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(driver.name.substring(0, 1),
                  style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          constraints: BoxConstraints(maxWidth: size + 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              driver.languages.map((l) => l.flag).join(' '),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ]);
}

/// Fiche du chauffeur affichée pendant la course.
class DriverCard extends StatelessWidget {
  const DriverCard(
      {super.key,
      required this.driver,
      this.passengerName,
      this.lowVision = false,
      this.babySeat = false,
      this.grand = false});
  final DemoDriver driver;

  /// Grand taxi : pas de photo du modèle (la photo montre le petit taxi rouge de Casablanca).
  final bool grand;

  /// Course commandée pour quelqu'un d'autre : le nom du passager, comme le voit le chauffeur.
  final String? passengerName;

  /// Le chauffeur est prévenu que le passager est malvoyant.
  final bool lowVision;

  /// Siège bébé demandé par le passager.
  final bool babySeat;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DriverPhoto(driver: driver),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(driver.name,
                maxLines: 1,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
            Text.rich(
              TextSpan(children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
                ),
                TextSpan(
                    text: ' ${driver.rating.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                TextSpan(text: ' · ${driver.rides} ${s.t('ridesCount')} · ${driver.car}'),
              ]),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final l in driver.languages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text('${l.flag} ${l.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
            if (passengerName != null || lowVision || babySeat) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                if (passengerName != null)
                  _badge(Icons.person, '${s.t('passenger')} : $passengerName', AppColors.moroccoGreen),
                if (lowVision) _badge(Icons.visibility_off, s.t('lowVisionBadge'), AppColors.ink),
                if (babySeat) _badge(Icons.child_friendly, s.t('babySeatRequested'), AppColors.moroccoGreen),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        _TaxiPicture(plate: driver.plate, label: driver.taxiNumber, grand: grand),
      ]);

  Widget _badge(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      );
}

/// Photo du modèle de taxi avec la plaque dessous, à reconnaître d'un coup d'œil dans la rue.
class _TaxiPicture extends StatelessWidget {
  const _TaxiPicture({required this.plate, required this.label, required this.grand});
  final String plate;
  final String label;
  final bool grand;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 112,
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: grand ? AppColors.grandTaxi : AppColors.sandDeep,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: grand
                ? const Icon(Icons.airport_shuttle_rounded, size: 44, color: AppColors.ink)
                : Image.asset('assets/taxi/petit_taxi.jpg', fit: BoxFit.cover),
          ),
          const SizedBox(height: 6),
          // Plaque façon plaque marocaine : fond blanc, bord noir.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
            constraints: const BoxConstraints(maxWidth: 112),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(plate,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ]),
      );
}
