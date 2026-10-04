import 'account.dart';
import 'promos.dart';

/// Compte de démonstration (« Continuer en démo ») : identifiant fixe quand aucun compte n'a été créé.
const demoUserId = 'U7Q3K9';

/// Identifiant du compte du passager, ou celui de la démo.
String get currentUserId => accountStore.account?.id ?? demoUserId;

/// Durée de validité d'un bon.
const couponValidity = Duration(hours: 24);

/// Somme de contrôle courte (2 caractères en base 36) : détecte une faute de frappe dans un code saisi à la main.
String couponChecksum(String body) {
  var sum = 0;
  for (var i = 0; i < body.length; i++) {
    sum = (sum + (i + 1) * body.codeUnitAt(i)) % 1296;
  }
  return sum.toRadixString(36).toUpperCase().padLeft(2, '0');
}

/// Code du bon : `TM-<compte>-<offre>-<course>-<aaaammjj d'expiration>-<contrôle>`.
/// C'est aussi le contenu du QR code présenté en caisse.
String buildCouponCode({
  required String userId,
  required String offerId,
  required String tripId,
  required DateTime expires,
}) {
  final date = '${expires.year.toString().padLeft(4, '0')}${expires.month.toString().padLeft(2, '0')}'
      '${expires.day.toString().padLeft(2, '0')}';
  final body = 'TM-$userId-$offerId-$tripId-$date';
  return '$body-${couponChecksum(body)}';
}

/// Vérifie qu'un code n'a pas été mal recopié.
bool isValidCouponCode(String code) {
  final i = code.lastIndexOf('-');
  if (i <= 0 || !code.startsWith('TM-')) return false;
  return couponChecksum(code.substring(0, i)) == code.substring(i + 1);
}

/// Bon de réduction lié au compte du passager, à une offre et à une course.
class Coupon {
  Coupon({required this.promo, required this.tripId, required this.issuedAt, String? userId})
      : userId = userId ?? currentUserId;
  final Promo promo;
  final String tripId;
  final DateTime issuedAt;
  final String userId;

  DateTime get expires => issuedAt.add(couponValidity);
  String get code => buildCouponCode(userId: userId, offerId: promo.id, tripId: tripId, expires: expires);
}

/// « Mes offres » : bons enregistrés pendant la session.
final savedCoupons = <Coupon>[];

bool isSaved(Coupon c) => savedCoupons.any((o) => o.code == c.code);

void saveCoupon(Coupon c) {
  if (!isSaved(c)) savedCoupons.insert(0, c);
}
