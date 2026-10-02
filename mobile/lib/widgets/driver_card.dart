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
          child: Image.network(
            driver.photoUrl,
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
          child: Text(
            driver.languages.map((l) => l.flag).join(' '),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ]);
}

/// Fiche du chauffeur affichée pendant la course.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver});
  final DemoDriver driver;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DriverPhoto(driver: driver),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(driver.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5B301)),
              Text(driver.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            Text('${driver.rides} ${s.t('ridesCount')} · ${driver.car}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final l in driver.languages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(8)),
                  child: Text('${l.flag} ${l.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
            child: Text(driver.plate, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)),
          ),
          const SizedBox(height: 4),
          Text(driver.taxiNumber, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ]);
}
