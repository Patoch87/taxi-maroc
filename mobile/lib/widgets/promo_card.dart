import 'package:flutter/material.dart';

import '../main.dart';
import '../services/promos.dart';
import '../services/rides.dart';
import '../services/tourism.dart';
import '../theme.dart';

/// Carte d'offre discrète, toujours marquée « Publicité ».
class PromoCard extends StatelessWidget {
  const PromoCard({super.key, required this.promo, this.big = false, this.onClose, this.onTap});
  final Promo promo;

  /// Mode senior : texte plus grand.
  final bool big;

  /// Croix « Masquer la publicité » : l'offre disparaît pour le reste de la course.
  final VoidCallback? onClose;

  /// Toucher l'offre : ouvre le bon de réduction avec son QR code.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsetsDirectional.fromSTEB(12, 10, onClose == null ? 12 : 0, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Row(children: [
          Expanded(
            child: Semantics(
              container: true,
              button: onTap != null,
              label: '${s.t('promoLabel')}. ${promo.brand}. ${s.t(promo.titleKey)}. ${s.t(promo.detailKey)}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(children: [
                  BrandBadge(promo: promo, size: big ? 56 : 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Mention visible : ces enseignes ne sont pas des partenaires.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.sandDeep, borderRadius: BorderRadius.circular(6)),
                        child: Text(s.t('promoLabel'),
                            style: TextStyle(
                                fontSize: big ? 16 : 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
                      ),
                      const SizedBox(height: 3),
                      Text(s.t(promo.titleKey),
                          style: TextStyle(fontSize: big ? 24 : 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      Text('${promo.brand} · ${s.t(promo.detailKey)}',
                          style: TextStyle(fontSize: big ? 20 : 12, color: AppColors.muted)),
                    ]),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.qr_code_2, color: AppColors.moroccoGreen),
                  ],
                ]),
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: s.t('hideAd'),
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
            ),
        ]),
      );
}

/// Badge de l'annonceur : son logo s'il est fourni, sinon ses initiales sur sa couleur.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.promo, this.size = 44});
  final Promo promo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = promo.logoAsset;
    if (logo == null) return _initials();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Image.asset(logo, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _initials()),
    );
  }

  Widget _initials() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        padding: EdgeInsets.all(size * .14),
        decoration: BoxDecoration(
          color: promo.color,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
        ),
        child: FittedBox(
          child: Text(promo.initials,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1)),
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
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${s.t(r.cuisineKey)} · ${r.priceMad} · ${distanceText(m)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              // Note et bouton côte à côte, ou l'un sous l'autre si la place manque (grands textes).
              Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                RatingBubbles(rating: r.rating, reviews: r.reviews),
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
            ]),
          ),
      ]);
}

/// Bandeau publicitaire fin en haut de la carte : mention « Exemple publicitaire (démo) », croix pour le masquer,
/// appui pour voir le détail de l'offre.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key, required this.promo, required this.onClose, required this.onOpen});
  final Promo promo;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        child: Row(children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '${s.t('promoLabel')}. ${s.t(promo.titleKey)}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(14)).resolve(
                  Directionality.of(context),
                ),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 4, 6),
                  child: Row(children: [
                    BrandBadge(promo: promo, size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey(promo.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.t('promoLabel'),
                                style:
                                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
                            Text(s.t(promo.titleKey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: s.t('hideAd'),
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
          ),
        ]),
      );
}

/// Note façon TripAdvisor : 5 bulles vertes, la note et le nombre d'avis, avec la mention « (démo) ».
/// Pas de logo officiel : les restaurants et les notes de la démo sont fictifs.
class RatingBubbles extends StatelessWidget {
  const RatingBubbles({super.key, required this.rating, required this.reviews});
  final double rating;
  final int reviews;

  static const green = Color(0xFF00AA6C);

  @override
  Widget build(BuildContext context) {
    final value = s.decimalPoint ? rating.toStringAsFixed(1) : rating.toStringAsFixed(1).replaceAll('.', ',');
    return Semantics(
      label: '${s.t('tripadvisorDemo')} $value / 5, $reviews ${s.t('reviews')}',
      excludeSemantics: true,
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: SizedBox.square(
                dimension: 11,
                child: CustomPaint(painter: _BubblePainter((rating - i).clamp(0.0, 1.0))),
              ),
            ),
        ]),
        Text('$value · $reviews ${s.t('reviews')}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
        Text(s.t('tripadvisorDemo'), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}

/// Bulle pleine, à moitié pleine ou vide.
class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.fill);
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()..color = RatingBubbles.green;
    if (fill > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * (fill >= 1 ? 1 : .5), size.height));
      canvas.drawCircle(c, r, paint);
      canvas.restore();
    }
    canvas.drawCircle(
        c,
        r - .75,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.fill != fill;
}
