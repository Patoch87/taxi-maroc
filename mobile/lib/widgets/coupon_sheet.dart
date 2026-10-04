import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart';
import '../services/coupons.dart';
import '../theme.dart';
import 'promo_card.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// Date et heure d'expiration : 05/10/2026 14:30.
String couponDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// Bon de réduction : QR code lié au compte du passager, code en clair, expiration, adresse et conditions.
Future<void> showCouponSheet(BuildContext context, Coupon coupon) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => CouponView(coupon: coupon),
    );

class CouponView extends StatefulWidget {
  const CouponView({super.key, required this.coupon});
  final Coupon coupon;

  @override
  State<CouponView> createState() => _CouponViewState();
}

class _CouponViewState extends State<CouponView> {
  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    final saved = isSaved(c);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              BrandBadge(promo: c.promo, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('couponTitle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(s.t('promoLabel'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(s.t(c.promo.titleKey), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${c.promo.brand} · ${s.t(c.promo.detailKey)}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            // Le QR code contient le code du bon : il est scanné en caisse.
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line, width: 1.5),
                ),
                child: Semantics(
                  label: '${s.t('couponTitle')} : ${c.code}',
                  child: QrImageView(
                    data: c.code,
                    size: 200,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(c.code,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .5)),
            Text(s.t('couponLinked'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            _line(Icons.event, '${s.t('couponExpires')} ${couponDate(c.expires)}'),
            _line(Icons.place_outlined, '${s.t('storeAddress')} : ${c.promo.address}'),
            _line(Icons.info_outline, s.t('couponConditions')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saved
                  ? null
                  : () {
                      saveCoupon(c);
                      setState(() {});
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.t('offerSaved'))));
                    },
              icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
              label: Text(saved ? s.t('offerSaved') : s.t('saveOffer')),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.moroccoGreen),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
