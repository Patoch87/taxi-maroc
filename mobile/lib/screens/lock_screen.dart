import 'package:flutter/material.dart';

import '../main.dart';
import '../services/account.dart';
import '../services/biometric_auth.dart';
import '../services/phone_code.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import 'sos_screen.dart';

/// Connexion à l'ouverture : empreinte digitale ou reconnaissance faciale (proposée tout de suite),
/// ou code SMS. Le SOS reste accessible sans se connecter.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.autoPrompt = true});

  /// Demande l'empreinte ou le visage dès l'affichage (désactivé dans certains tests).
  final bool autoPrompt;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _failed = false;
  bool _busy = false;
  bool _useCode = false;
  bool _codeSent = false;
  bool _sending = false;
  bool _sendFailed = false;
  final _verifier = PhoneCodeVerifier();
  final _code = TextEditingController();

  Future<void> _sendCode(String phone) async {
    setState(() {
      _sending = true;
      _sendFailed = false;
    });
    try {
      await _verifier.send(phone);
      if (mounted) setState(() => _codeSent = true);
    } catch (_) {
      if (mounted) setState(() => _sendFailed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoPrompt) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await biometricLock.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
  }

  IconData get _icon {
    final sup = biometricLock.support;
    if (sup.face && !sup.fingerprint) return Icons.face_retouching_natural;
    return Icons.fingerprint;
  }

  @override
  Widget build(BuildContext context) {
    final a = accountStore.account;
    return Scaffold(
      backgroundColor: AppColors.sand,
      body: Zellige(
        opacity: .06,
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
            const Center(child: AppLogo(size: 88)),
            const SizedBox(height: 20),
            Text('${s.t('bioHello')} ${a?.firstName ?? ''}'.trim(),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(s.t('bioReason'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 32),
            Center(
              child: Semantics(
                button: true,
                label: s.t('bioUnlock'),
                excludeSemantics: true,
                onTap: _unlock,
                child: InkWell(
                  key: const ValueKey('bioUnlock'),
                  customBorder: const CircleBorder(),
                  onTap: _unlock,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(color: AppColors.moroccoGreen, shape: BoxShape.circle),
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.white))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_icon, color: Colors.white, size: 56),
                            if (biometricLock.support.face && biometricLock.support.fingerprint)
                              const Icon(Icons.face_retouching_natural, color: Colors.white70, size: 30),
                          ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(s.t('bioUnlock'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(s.t('bioFailed'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 24),
            if (!_useCode)
              TextButton.icon(
                key: const ValueKey('bioUseCode'),
                onPressed: () => setState(() => _useCode = true),
                icon: const Icon(Icons.sms_outlined),
                label: Text(s.t('bioUseCode')),
              )
            else ...[
              if (!_codeSent) ...[
                OutlinedButton.icon(
                  onPressed: _sending || a == null ? null : () => _sendCode(a.phone),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sms_outlined),
                  label: Text('${s.t('sendCode')} · ${a?.phone ?? ''}'),
                ),
                if (_sendFailed)
                  Text(s.t('smsFailed'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w700)),
              ] else ...[
                // Vrai SMS envoyé ; sinon (démo, ou serveur sans SMS) le code est affiché ici.
                Text(
                    _verifier.sent?.testCode == null
                        ? '${s.t('codeSentSms')} ${a?.phone ?? ''}'
                        : '${s.t('codeSentDemo')} ${_verifier.sent!.testCode}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('lockSmsCode'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onChanged: (v) async {
                    setState(() {});
                    if (await _verifier.check(v)) biometricLock.unlocked();
                    if (mounted) setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: s.t('smsCode'),
                    errorText: _verifier.wrong ? s.t('wrongCode') : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
            // SOS sans se connecter, comme l'appel d'urgence d'un téléphone verrouillé.
            OutlinedButton.icon(
              key: const ValueKey('lockSos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.taxiRed,
                side: const BorderSide(color: AppColors.taxiRed, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => openSos(context),
              icon: const Icon(Icons.sos),
              label: Text(s.t('sos')),
            ),
          ]),
        ),
      ),
    );
  }
}
