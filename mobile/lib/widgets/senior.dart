import 'package:flutter/material.dart';

import '../main.dart';
import '../services/rides.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'app_logo.dart';
import 'driver_card.dart';

/// Mode senior : écrans très simples, texte de 24 points ou plus, fort contraste et gros boutons.
const seniorText = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2);
const seniorSmall = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.25);

/// Fond commun : bandeau vert décoré de zellige avec le logo, puis contenu sur fond sable.
/// Le bouton « Revenir au mode normal » est toujours en haut, sur tous les écrans du mode senior.
class SeniorScaffold extends StatelessWidget {
  const SeniorScaffold({super.key, required this.children, this.subtitle, this.footer});
  final List<Widget> children;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.sand,
        body: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.moroccoGreen,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Zellige(
              color: Colors.white,
              opacity: .12,
              cell: 44,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SeniorExitButton(),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.sand, shape: BoxShape.circle),
                        child: const AppLogo(size: 52),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.t('appTitle'),
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  ...children,
                  if (footer != null) ...[const SizedBox(height: 8), footer!]
                ],
              ),
            ),
          ),
        ]),
      );
}

/// « Revenir au mode normal » : gros bouton blanc, bien visible en haut de chaque écran senior.
class SeniorExitButton extends StatelessWidget {
  const SeniorExitButton({super.key, this.onExit});

  /// Action en plus (par exemple fermer l'écran de recherche).
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.icon(
          key: const ValueKey('seniorExit'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.moroccoGreen,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          onPressed: () {
            settings.senior = false;
            onExit?.call();
          },
          icon: const Icon(Icons.elderly, size: 28),
          label: Text(s.t('normalMode')),
        ),
      );
}

/// Très gros bouton arrondi avec une icône dans un cercle.
class SeniorButton extends StatelessWidget {
  const SeniorButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.moroccoGreen,
    this.foreground = Colors.white,
    this.subtitle,
    this.outlined = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Semantics(
          button: true,
          label: subtitle == null ? label : '$label, $subtitle',
          excludeSemantics: true,
          child: Material(
            color: color,
            elevation: outlined ? 0 : 3,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: outlined ? const BorderSide(color: AppColors.moroccoGreen, width: 3) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: outlined ? AppColors.greenSoft : Colors.white.withValues(alpha: .2),
                      child: Icon(icon, size: 36, color: foreground),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label,
                            style:
                                TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: foreground, height: 1.15)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: foreground)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Bouton secondaire, sobre mais toujours grand.
class SeniorTextButton extends StatelessWidget {
  const SeniorTextButton({super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(72),
          side: const BorderSide(color: AppColors.ink, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        onPressed: onTap,
        icon: Icon(icon ?? Icons.close, size: 30),
        label: Text(label),
      );
}

/// Accueil du mode senior : trois gros boutons, rien d'autre.
class SeniorHome extends StatelessWidget {
  const SeniorHome({
    super.key,
    required this.onOrder,
    required this.onGoHome,
    required this.onCall,
    this.contactName,
  });
  final VoidCallback onOrder;
  final VoidCallback onGoHome;
  final VoidCallback onCall;
  final String? contactName;

  @override
  Widget build(BuildContext context) => SeniorScaffold(
        subtitle: s.t('hello'),
        children: [
          SeniorButton(icon: Icons.local_taxi, label: s.t('seniorOrder'), onTap: onOrder),
          SeniorButton(
            icon: Icons.home_rounded,
            label: s.t('seniorHome'),
            subtitle: s.t('petitTaxi'),
            onTap: onGoHome,
            color: Colors.white,
            foreground: AppColors.moroccoGreen,
            outlined: true,
          ),
          SeniorButton(
            icon: Icons.call,
            label: s.t('seniorCall'),
            subtitle: contactName,
            onTap: onCall,
            color: AppColors.ink,
          ),
        ],
      );
}

/// Grande plaque d'immatriculation marocaine.
class SeniorPlate extends StatelessWidget {
  const SeniorPlate({super.key, required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${s.t('plate')} $plate',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ink, width: 4),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(plate,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ),
      );
}

/// Course en mode senior : photo du chauffeur, plaque en très grand, compte à rebours, un gros bouton SOS.
class SeniorTrip extends StatelessWidget {
  const SeniorTrip({
    super.key,
    required this.title,
    required this.driver,
    required this.onSos,
    this.countdown,
    this.countdownLabel,
    this.onStart,
    this.onFastForward,
    this.speed = 1,
    this.extra,
  });
  final String title;
  final DemoDriver driver;
  final String? countdown;
  final String? countdownLabel;
  final VoidCallback onSos;
  final VoidCallback? onStart;
  final VoidCallback? onFastForward;

  /// Vitesse de la démo (×1 à ×4).
  final int speed;

  /// Contenu en plus, sous le bouton SOS (offre à la demande pendant la course).
  final Widget? extra;

  @override
  Widget build(BuildContext context) => SeniorScaffold(
        children: [
          Semantics(liveRegion: true, child: Text(title, style: seniorText.copyWith(fontSize: 30))),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line, width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                DriverPhoto(driver: driver, size: 96),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(driver.name, style: seniorText),
                    Text(driver.car, style: seniorSmall.copyWith(color: AppColors.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              SeniorPlate(plate: driver.plate),
            ]),
          ),
          if (countdown != null) ...[
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              label: '${countdownLabel ?? ''} $countdown',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.moroccoGreen, borderRadius: BorderRadius.circular(28)),
                child: Column(children: [
                  if (countdownLabel != null) Text(countdownLabel!, style: seniorSmall.copyWith(color: Colors.white)),
                  Text(countdown!,
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
          ],
          if (onStart != null) ...[
            const SizedBox(height: 18),
            SeniorButton(icon: Icons.directions_car, label: s.t('startTrip'), onTap: onStart!),
          ],
          const SizedBox(height: 18),
          SeniorButton(icon: Icons.sos, label: s.t('sos'), onTap: onSos, color: AppColors.taxiRed),
          if (onFastForward != null)
            TextButton.icon(
              onPressed: onFastForward,
              icon: const Icon(Icons.fast_forward, color: AppColors.muted),
              label:
                  Text('${s.t('fastForward')} ×$speed', style: const TextStyle(color: AppColors.muted, fontSize: 18)),
            ),
          if (extra != null) ...[const SizedBox(height: 14), extra!],
        ],
      );
}
