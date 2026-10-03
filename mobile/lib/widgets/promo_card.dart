import 'package:flutter/material.dart';

import '../main.dart';
import '../services/promos.dart';
import '../services/rides.dart';
import '../services/tourism.dart';
import '../theme.dart';

/// Carte d'offre discrète, toujours marquée « Exemple publicitaire (démo) ».
class PromoCard extends StatelessWidget {
  const PromoCard({super.key, required this.promo, this.big = false});
  final Promo promo;

  /// Mode senior : texte plus grand.
  final bool big;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '${s.t('promoLabel')}. ${s.t(promo.titleKey)}. ${s.t(promo.detailKey)}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: big ? 56 : 42,
              height: big ? 56 : 42,
              decoration:
                  BoxDecoration(color: promo.color.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
              child: Icon(promo.icon, color: promo.color, size: big ? 30 : 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Mention visible : ces marques ne sont pas des partenaires.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.sandDeep, borderRadius: BorderRadius.circular(6)),
                  child: Text(s.t('promoLabel'),
                      style: TextStyle(fontSize: big ? 16 : 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ),
                const SizedBox(height: 3),
                Text(s.t(promo.titleKey),
                    style: TextStyle(fontSize: big ? 24 : 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                Text(s.t(promo.detailKey), style: TextStyle(fontSize: big ? 20 : 12, color: AppColors.muted)),
              ]),
            ),
          ]),
        ),
      );
}

/// Restaurants proposés aux touristes près de la destination, chacun avec « Y aller en taxi ».
class RestaurantSuggestions extends StatelessWidget {
  const RestaurantSuggestions({super.key, required this.destinationName, required this.items, required this.onGo});
  final String destinationName;
  final List<(Restaurant, double)> items;
  final void Function(Restaurant) onGo;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.restaurant, size: 18, color: AppColors.taxiRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${s.t('restaurantsNear')} $destinationName',
                style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 6),
        for (final (r, m) in items)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${s.t(r.cuisineKey)} · ${r.priceMad} · ${distanceText(m)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              Semantics(
                button: true,
                label: '${s.t('goByTaxi')} : ${r.name}',
                excludeSemantics: true,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.moroccoGreen),
                  onPressed: () => onGo(r),
                  icon: const Icon(Icons.local_taxi, size: 18),
                  label: Text(s.t('goByTaxi'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
      ]);
}
