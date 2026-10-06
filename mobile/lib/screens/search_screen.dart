import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../services/geocode.dart';
import '../services/live.dart';
import '../services/places.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/senior.dart';

/// Recherche de destination plein écran, avec la commande vocale.
/// La destination dictée est d'abord répétée à voix haute, puis écrite dans la recherche.
/// En mode senior : très gros texte, gros bouton « Dire ma destination » et grandes lignes de résultats.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.startWithVoice = false, this.senior = false, this.near});
  final bool startWithVoice;
  final bool senior;

  /// Position du téléphone : en test réel, les adresses proches sont proposées en premier.
  final LatLng? near;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _voice = Voice();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _listening = false;
  String _heard = '';
  String? _voiceStatus;

  /// Test réel : adresses trouvées partout (OpenStreetMap), en plus des lieux de la démo.
  List<Place> _addresses = [];
  Timer? _debounce;
  String _searched = '';

  void _onQuery() {
    setState(() {});
    if (!live.enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final q = _ctrl.text;
      if (q == _searched) return;
      _searched = q;
      try {
        final found = await searchAddresses(q, near: widget.near, lang: s.lang == 'dr' ? 'ar' : s.lang);
        if (mounted && _ctrl.text == q) setState(() => _addresses = found);
      } catch (_) {
        // Hors ligne : seuls les lieux de la démo restent proposés.
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.startWithVoice) WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pulse.dispose();
    _voice.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    if (!await _voice.init()) {
      setState(() => _voiceStatus = s.t('micDenied'));
      return;
    }
    await _voice.say(s.t('speakNow'));
    setState(() {
      _listening = true;
      _heard = '';
      _voiceStatus = s.t('listening');
    });
    _pulse.repeat(reverse: true);
    await _voice.listen(onResult: (words, done) {
      setState(() => _heard = words);
      if (done) _onHeard(words);
    });
  }

  Future<void> _onHeard(String words) async {
    _pulse.stop();
    setState(() => _listening = false);
    if (words.trim().isEmpty) {
      setState(() => _voiceStatus = s.t('notUnderstood'));
      await _voice.say(s.t('notUnderstood'));
      return;
    }
    // 1. Répéter la destination à voix haute.
    setState(() => _voiceStatus = '${s.t('youSaid')} : « $words »');
    await _voice.say('${s.t('youSaid')} : $words');
    // 2. L'écrire dans la recherche et chercher.
    final place = findPlace(words);
    final query = place?.name ?? words;
    _ctrl.text = query;
    _onQuery();
    setState(() => _voiceStatus = '${s.t('searchingFor')} « $query »');
    if (place != null) await _voice.say('${s.t('searchingFor')} ${place.name}');
  }

  /// Grand affichage tant que le mode senior est actif (il peut être quitté depuis cet écran).
  bool get _big => widget.senior && settings.senior;

  @override
  Widget build(BuildContext context) {
    final results = searchPlaces(_ctrl.text);
    final big = _big;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: big ? 72 : null,
        iconTheme: IconThemeData(size: big ? 32 : 24),
        flexibleSpace: const Zellige(opacity: .06),
        title: Text(s.t('whereTo'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 28 : null)),
      ),
      body: Column(
        children: [
          // Mode senior : le retour au mode normal reste visible ici aussi.
          if (big)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                decoration: BoxDecoration(color: AppColors.moroccoGreen, borderRadius: BorderRadius.circular(30)),
                child: SeniorExitButton(onExit: () => setState(() {})),
              ),
            ),
          if (big)
            // Gros bouton micro : la façon la plus simple de dire où aller.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Semantics(
                button: true,
                label: s.t('sayDestination'),
                excludeSemantics: true,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _listening ? AppColors.taxiRed : AppColors.moroccoGreen,
                    minimumSize: const Size.fromHeight(88),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _listen,
                  icon: Icon(_listening ? Icons.graphic_eq : Icons.mic, size: 40),
                  label: Text(s.t('sayDestination')),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Semantics(
              textField: true,
              label: s.t('searchPlace'),
              child: TextField(
                controller: _ctrl,
                autofocus: !widget.startWithVoice && !big,
                onChanged: (_) => _onQuery(),
                style: TextStyle(fontSize: big ? 26 : 16, fontWeight: big ? FontWeight.w700 : null),
                decoration: InputDecoration(
                  hintText: big ? s.t('typeDestination') : s.t('searchPlace'),
                  hintStyle: TextStyle(fontSize: big ? 24 : 16, color: AppColors.muted),
                  contentPadding: big ? const EdgeInsets.symmetric(horizontal: 18, vertical: 22) : null,
                  prefixIcon: Icon(Icons.search, size: big ? 32 : 24),
                  suffixIcon: big
                      ? null
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: ScaleTransition(
                            scale: Tween(begin: 1.0, end: 1.15).animate(_pulse),
                            child: IconButton.filled(
                              tooltip: s.t('speakNow'),
                              style: IconButton.styleFrom(
                                backgroundColor: _listening ? AppColors.taxiRed : AppColors.moroccoGreen,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _listen,
                              icon: Icon(_listening ? Icons.graphic_eq : Icons.mic),
                            ),
                          ),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(big ? 20 : 14),
                    borderSide: BorderSide(color: AppColors.line, width: big ? 2 : 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(big ? 20 : 14),
                    borderSide: BorderSide(color: AppColors.line, width: big ? 2 : 1),
                  ),
                ),
              ),
            ),
          ),
          if (_voiceStatus != null)
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.sandDeep, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(_listening ? Icons.hearing : Icons.record_voice_over, color: AppColors.taxiRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_listening && _heard.isNotEmpty ? '« $_heard »' : _voiceStatus!,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: big ? 22 : 14)),
                  ),
                ]),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                if (_ctrl.text.isEmpty) ...[
                  _tile(homePlace, Icons.home_rounded, s.t('home')),
                  _tile(workPlace, Icons.work_rounded, s.t('work')),
                  const Divider(height: 1, color: AppColors.line),
                ],
                // Test réel : les adresses autour du téléphone d'abord.
                if (live.enabled && _ctrl.text.trim().length >= 3)
                  for (final p in _addresses) _tile(p, Icons.location_on_outlined, p.name),
                for (final p in results) _tile(p, p.intercity ? Icons.alt_route : Icons.place_outlined, p.name),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Place p, IconData icon, String title) {
    final big = _big;
    return Semantics(
      button: true,
      label: '$title, ${p.subtitle}',
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: big ? 8 : 0),
        leading: CircleAvatar(
          radius: big ? 28 : 20,
          backgroundColor: AppColors.greenSoft,
          foregroundColor: AppColors.moroccoGreen,
          child: Icon(icon, size: big ? 30 : 24),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: big ? 26 : 16)),
        subtitle: Text(p.subtitle, style: TextStyle(color: AppColors.muted, fontSize: big ? 20 : 14)),
        onTap: () => Navigator.pop(context, p),
      ),
    );
  }
}
