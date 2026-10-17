import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';

/// « Devenir chauffeur Premium » : critères du véhicule, de l'équipement à bord et du chauffeur,
/// contrôles et gains du badge Premium.
class PremiumDriverScreen extends StatelessWidget {
  const PremiumDriverScreen({super.key});

  /// Sections : icône, clé du titre, clé des critères (un critère par ligne).
  static const sections = [
    (Icons.directions_car_outlined, 'premVehicleTitle', 'premVehicle'),
    (Icons.local_drink_outlined, 'premOnBoardTitle', 'premOnBoard'),
    (Icons.badge_outlined, 'premDriverTitle', 'premDriver'),
    (Icons.fact_check_outlined, 'premControlTitle', 'premControl'),
    (Icons.payments_outlined, 'premGainsTitle', 'premGains'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('becomePremium'), style: const TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: const Zellige(opacity: .06),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final (icon, title, items) in sections)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line, width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(s.t(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 6),
                for (final line in s.t(items).split('\n'))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle, size: 15, color: AppColors.moroccoGreen),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line, style: const TextStyle(fontSize: 14))),
                    ]),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}
