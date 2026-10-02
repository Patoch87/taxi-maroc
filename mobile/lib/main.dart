import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/driver_screen.dart';
import 'screens/passenger_screen.dart';
import 'screens/voice_screen.dart';
import 'services/api.dart';

/// Langue choisie par l'utilisateur (fr, ar, en).
final langNotifier = ValueNotifier<String>('fr');
S get s => S(langNotifier.value);

void main() => runApp(const TaxiMarocApp());

class TaxiMarocApp extends StatelessWidget {
  const TaxiMarocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, lang, _) => MaterialApp(
        title: s.t('appTitle'),
        locale: Locale(lang),
        supportedLocales: S.supported.map(Locale.new),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorSchemeSeed: const Color(0xFFC1272D), useMaterial3: true),
        // La clé force la reconstruction de l'accueil quand la langue change.
        home: HomeScreen(key: ValueKey(lang)),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('appTitle')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (l) => langNotifier.value = l,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'fr', child: Text('Français')),
              PopupMenuItem(value: 'ar', child: Text('العربية')),
              PopupMenuItem(value: 'en', child: Text('English')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDemo)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text('Mode démo : taxis fictifs, sans serveur', textAlign: TextAlign.center),
              ),
            _BigButton(icon: Icons.person, label: s.t('iAmPassenger'), onTap: () => open(const PassengerScreen())),
            const SizedBox(height: 16),
            _BigButton(icon: Icons.local_taxi, label: s.t('iAmDriver'), onTap: () => open(const DriverScreen())),
            const SizedBox(height: 16),
            _BigButton(icon: Icons.mic, label: s.t('voiceMode'), onTap: () => open(const VoiceScreen())),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 32),
          label: Text(label, style: const TextStyle(fontSize: 20)),
        ),
      );
}
