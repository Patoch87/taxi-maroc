import 'package:flutter/material.dart';

import '../main.dart';
import '../services/coupons.dart';
import '../theme.dart';
import '../widgets/coupon_sheet.dart';
import '../widgets/promo_card.dart';

/// « Mes offres » : bons de réduction enregistrés, à présenter en caisse avec leur QR code.
class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(s.t('myOffers'))),
        body: savedCoupons.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(s.t('noOffers'),
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: savedCoupons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = savedCoupons[i];
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    PromoCard(promo: c.promo, onTap: () => showCouponSheet(context, c)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text('${s.t('couponExpires')} ${couponDate(c.expires)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  ]);
                },
              ),
      );
}
