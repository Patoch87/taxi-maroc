/// Vérifications de format d'une carte bancaire, pour le paiement simulé de la démo.
/// Aucun paiement réel : les numéros ne sont ni envoyés ni enregistrés.
library;

/// 13 à 19 chiffres, espaces permis.
bool validCardNumber(String v) => RegExp(r'^\d{13,19}$').hasMatch(v.replaceAll(' ', ''));

/// MM/AA, mois de 01 à 12, pas dans le passé.
bool validExpiry(String v, {DateTime? now}) {
  final m = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(v.trim());
  if (m == null) return false;
  final month = int.parse(m.group(1)!);
  final year = 2000 + int.parse(m.group(2)!);
  if (month < 1 || month > 12) return false;
  final n = now ?? DateTime.now();
  return year > n.year || (year == n.year && month >= n.month);
}

/// 3 ou 4 chiffres.
bool validCvc(String v) => RegExp(r'^\d{3,4}$').hasMatch(v.trim());
