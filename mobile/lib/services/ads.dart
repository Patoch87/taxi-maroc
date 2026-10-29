import 'package:flutter/material.dart';

import 'live.dart';
import 'places.dart';
import 'promos.dart';

/// Emplacements des publicités côté passager. Jamais sur l'écran du chauffeur en conduite.
enum AdPlacement {
  /// Bannière d'accueil : en haut de l'accueil, logo + titre (40 caractères au plus) + bon.
  home('accueil'),

  /// Écran d'attente : carte pendant la recherche d'un chauffeur.
  waiting('attente'),

  /// Carte en course : logo, offre et QR code dans le panneau de suivi de la course.
  ride('course'),

  /// Restaurant ou lieu mis en avant : premier des restaurants à proximité, badge « Sponsorisé ».
  place('lieu'),

  /// Destination sponsorisée : une suggestion parmi les premières de la recherche, « Sponsorisé ».
  destination('destination'),

  /// Bon de réduction sur le reçu de fin de course, enregistré dans « Mes offres ».
  receipt('recu');

  const AdPlacement(this.server);

  /// Nom de l'emplacement sur le serveur (GET /ads).
  final String server;
}

/// Publicité du catalogue : annonceur FICTIF (exemple de démo), toujours marqué « exemple fictif ».
/// Contextuelle (trajet, lieu, heure) : jamais ciblée selon le revenu ou la catégorie sociale.
class Ad {
  const Ad({required this.placement, required this.promo, this.lat, this.lng, this.coupon = false});
  final AdPlacement placement;

  /// Annonceur, textes (clés de traduction), badge et adresse : mêmes cartes que les autres offres.
  final Promo promo;

  /// Bon de réduction avec QR code.
  final bool coupon;

  /// Lieu mis en avant ou destination sponsorisée.
  final double? lat;
  final double? lng;

  String get id => promo.id;

  /// Lieu à proposer comme destination (lieu mis en avant, destination sponsorisée).
  Place? get asPlace => lat == null || lng == null
      ? null
      : Place(promo.brand, lat!, lng!, [promo.brand.toLowerCase()], subtitle: promo.address);
}

/// Catalogue local : le même que celui du serveur (backend/src/ads/ads.ts), utilisé en mode démo
/// et quand le serveur ne répond pas.
const localAds = [
  Ad(
    placement: AdPlacement.home,
    coupon: true,
    promo: Promo(
      id: 'SOUK',
      brand: 'Souk Mode',
      initials: 'SM',
      titleKey: 'adSoukTitle',
      detailKey: 'adSoukText',
      address: 'Souk Mode, boulevard d’Anfa (exemple fictif)',
      icon: Icons.checkroom_outlined,
      color: Color(0xFFB5179E),
      fictive: true,
    ),
  ),
  Ad(
    placement: AdPlacement.waiting,
    promo: Promo(
      id: 'TELE',
      brand: 'Télé-Maroc Démo',
      initials: 'TM',
      titleKey: 'adTeleTitle',
      detailKey: 'adTeleText',
      address: 'Boutiques Télé-Maroc Démo (exemple fictif)',
      icon: Icons.wifi,
      color: Color(0xFFE76F00),
      fictive: true,
    ),
  ),
  Ad(
    placement: AdPlacement.ride,
    coupon: true,
    promo: Promo(
      id: 'DARBANK',
      brand: 'Dar Bank',
      initials: 'DB',
      titleKey: 'adBankTitle',
      detailKey: 'adBankText',
      address: 'Agences Dar Bank (exemple fictif)',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF1D4E89),
      fictive: true,
    ),
  ),
  Ad(
    placement: AdPlacement.place,
    lat: 33.5905,
    lng: -7.619,
    promo: Promo(
      id: 'ATLAS',
      brand: 'Café Atlas',
      initials: 'CA',
      titleKey: 'adAtlasPlace',
      detailKey: 'adAtlasPlace',
      address: 'Rue Tahar Sebti (exemple fictif)',
      icon: Icons.coffee_outlined,
      color: Color(0xFF6F4E37),
      fictive: true,
    ),
  ),
  Ad(
    placement: AdPlacement.destination,
    lat: 33.585,
    lng: -7.625,
    promo: Promo(
      id: 'AMAL',
      brand: 'Pharmacie Al Amal',
      initials: 'PA',
      titleKey: 'adAmalText',
      detailKey: 'adAmalText',
      address: 'Maârif (exemple fictif)',
      icon: Icons.local_pharmacy_outlined,
      color: Color(0xFF2A9D8F),
      fictive: true,
    ),
  ),
  Ad(
    placement: AdPlacement.receipt,
    coupon: true,
    promo: Promo(
      id: 'ATLASBON',
      brand: 'Café Atlas',
      initials: 'CA',
      titleKey: 'adAtlasCouponTitle',
      detailKey: 'adAtlasCouponText',
      address: 'Cafés Atlas de Casablanca (exemple fictif)',
      icon: Icons.coffee_outlined,
      color: Color(0xFF6F4E37),
      fictive: true,
    ),
  ),
];

/// Publicités affichées : celles du serveur (GET /ads) quand il répond, sinon le catalogue local.
/// Le serveur choisit quelles publicités sont actives et leur ordre ; les textes traduits restent
/// dans l'application.
/// Captures pour le film de présentation : aucune publicité dans l'application (--dart-define=NO_ADS=true).
const noAds = bool.fromEnvironment('NO_ADS');

class AdCatalog extends ChangeNotifier {
  List<Ad> _ads = noAds ? const [] : localAds;
  List<Ad> get ads => _ads;

  Ad? forPlacement(AdPlacement p) => _ads.where((a) => a.placement == p).firstOrNull;

  Future<void> refresh({LiveApi? api}) async {
    if (!live.enabled || noAds) return;
    try {
      final list = await (api ?? LiveApi()).ads();
      final active = <Ad>[
        for (final j in list)
          if (j is Map && j['exempleFictif'] == true)
            ...localAds.where((a) => a.id == j['id'] && a.placement.server == j['emplacement']),
      ];
      _ads = active;
      notifyListeners();
    } catch (_) {
      // Serveur injoignable : le catalogue local reste affiché.
    }
  }

  /// Statistiques de l'annonceur (vue, clic, bon), sans donnée personnelle ; rien en mode démo.
  void track(Ad ad, String type) {
    if (live.enabled) LiveApi().adEvent(ad.id, type).catchError((_) {});
  }

  @visibleForTesting
  void reset() {
    _ads = localAds;
    notifyListeners();
  }
}

final adCatalog = AdCatalog();
