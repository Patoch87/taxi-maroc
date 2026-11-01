import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'app_logo.dart';

/// Réponse proposée à l'écran pendant le parcours vocal (même effet que la dire à voix haute).
class VoiceChoice {
  const VoiceChoice(this.label, this.value, {this.icon});
  final String label;

  /// Texte rendu comme s'il avait été dit (« oui », « premium », « 5 »...).
  final String value;
  final IconData? icon;
}

/// Panneau du parcours 100 % vocal : la question posée, ce que le passager dit, et un très grand micro.
/// Tout le panneau se touche pour parler (un seul geste, même avec TalkBack).
/// Les réponses proposées restent touchables, pour un accompagnant ou sans micro.
class VoiceJourneyPanel extends StatefulWidget {
  const VoiceJourneyPanel({
    super.key,
    required this.prompt,
    required this.heard,
    required this.listening,
    required this.waitingTap,
    required this.choices,
    required this.onMic,
    required this.onChoice,
    required this.onClose,
    this.status,
    this.micUnavailable = false,
  });

  final String prompt;
  final String heard;
  final bool listening;

  /// L'application n'écoute plus d'elle-même : le passager touche l'écran pour parler.
  final bool waitingTap;
  final List<VoiceChoice> choices;
  final VoidCallback onMic;
  final ValueChanged<String> onChoice;
  final VoidCallback onClose;

  /// Où en est la course (taxi, plaque, minutes), affiché sous le titre.
  final String? status;
  final bool micUnavailable;

  @override
  State<VoiceJourneyPanel> createState() => _VoiceJourneyPanelState();
}

class _VoiceJourneyPanelState extends State<VoiceJourneyPanel> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceJourneyPanel old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.listening && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.listening && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final hint = w.micUnavailable
        ? s.t('vjMicOff')
        : w.listening
            ? s.t('listening')
            : w.waitingTap
                ? s.t('vjTapToTalk')
                : s.t('vjSpeaking');
    return Container(
      key: const ValueKey('voiceJourney'),
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .66),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.moroccoGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 18)],
      ),
      child: Zellige(
        color: Colors.white,
        opacity: .09,
        cell: 40,
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: w.onMic,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 18),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.record_voice_over, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.t('vjTitle'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    TextButton.icon(
                      key: const ValueKey('voiceJourneyClose'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: w.onClose,
                      icon: const Icon(Icons.close, size: 20),
                      label: Text(s.t('vjQuit')),
                    ),
                  ]),
                  if (w.status != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                      child: Text(w.status!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  const SizedBox(height: 12),
                  // La question, lue aussi par TalkBack quand elle change.
                  Semantics(
                    liveRegion: true,
                    child: Text(w.prompt,
                        key: const ValueKey('voicePrompt'),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: w.prompt.length > 110 ? 19 : 24,
                            height: 1.2,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Semantics(
                      button: true,
                      label: w.listening ? s.t('listening') : s.t('vjTapToTalk'),
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const ValueKey('voiceMic'),
                        onTap: w.onMic,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: w.listening ? AppColors.taxiRed : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: (w.listening ? AppColors.taxiRed : Colors.white).withValues(alpha: .45),
                                  blurRadius: 10 + 22 * _pulse.value,
                                  spreadRadius: 2 + 10 * _pulse.value,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: Icon(
                            w.micUnavailable ? Icons.mic_off : (w.listening ? Icons.graphic_eq : Icons.mic),
                            size: 50,
                            color: w.listening ? Colors.white : AppColors.moroccoGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(hint, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        if (w.heard.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('« ${w.heard} »',
                                key: const ValueKey('voiceHeard'),
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                    ),
                  ]),
                  if (w.choices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(s.t('vjOrTap'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in w.choices)
                        ActionChip(
                          key: ValueKey('vj-${c.value}'),
                          avatar: c.icon == null ? null : Icon(c.icon, size: 20, color: AppColors.moroccoGreen),
                          label: Text(c.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          backgroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          onPressed: () => w.onChoice(c.value),
                        ),
                    ]),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
