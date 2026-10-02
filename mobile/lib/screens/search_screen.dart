import 'package:flutter/material.dart';

import '../main.dart';
import '../services/places.dart';
import '../services/voice.dart';
import '../theme.dart';

/// Recherche de destination plein écran, avec la commande vocale.
/// La destination dictée est d'abord répétée à voix haute, puis écrite dans la recherche.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.startWithVoice = false});
  final bool startWithVoice;

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

  @override
  void initState() {
    super.initState();
    if (widget.startWithVoice) WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
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
    setState(() => _voiceStatus = '${s.t('searchingFor')} « $query »');
    if (place != null) await _voice.say('${s.t('searchingFor')} ${place.name}');
  }

  @override
  Widget build(BuildContext context) {
    final results = searchPlaces(_ctrl.text);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(s.t('whereTo'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: !widget.startWithVoice,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.t('searchPlace'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.15).animate(_pulse),
                    child: IconButton.filled(
                      tooltip: s.t('speakNow'),
                      style: IconButton.styleFrom(
                        backgroundColor: _listening ? AppColors.taxiRed : AppColors.ink,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _listen,
                      icon: Icon(_listening ? Icons.graphic_eq : Icons.mic),
                    ),
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_voiceStatus != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7F3E8), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(_listening ? Icons.hearing : Icons.record_voice_over, color: AppColors.taxiRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_listening && _heard.isNotEmpty ? '« $_heard »' : _voiceStatus!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          Expanded(
            child: ListView(
              children: [
                if (_ctrl.text.isEmpty) ...[
                  _tile(homePlace, Icons.home_rounded, s.t('home')),
                  _tile(workPlace, Icons.work_rounded, s.t('work')),
                  const Divider(height: 1, color: AppColors.line),
                ],
                for (final p in results) _tile(p, p.intercity ? Icons.alt_route : Icons.place_outlined, p.name),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Place p, IconData icon, String title) => ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF3F3F3),
          foregroundColor: AppColors.ink,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(p.subtitle, style: const TextStyle(color: AppColors.muted)),
        onTap: () => Navigator.pop(context, p),
      );
}
