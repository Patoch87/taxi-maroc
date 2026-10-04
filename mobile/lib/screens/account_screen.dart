import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../services/account.dart';
import '../services/dial_codes.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';

/// Liste des pays avec recherche et drapeaux, Maroc en premier. Renvoie le pays choisi.
Future<Country?> showNationalitySheet(BuildContext context) => showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _NationalityPicker(),
    );

class _NationalityPicker extends StatefulWidget {
  const _NationalityPicker();

  @override
  State<_NationalityPicker> createState() => _NationalityPickerState();
}

class _NationalityPickerState extends State<_NationalityPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = searchCountries(_query.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(s.t('chooseNationality'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('countrySearch'),
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.t('searchCountry'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(c.name(s.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: c.name(s.lang) == c.fr ? null : Text(c.fr),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Liste UIT complète des indicatifs, avec recherche (pays ou indicatif) et drapeaux, Maroc en premier.
Future<DialCode?> showDialCodeSheet(BuildContext context) => showModalBottomSheet<DialCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _DialPicker(),
    );

class _DialPicker extends StatefulWidget {
  const _DialPicker();

  @override
  State<_DialPicker> createState() => _DialPickerState();
}

class _DialPickerState extends State<_DialPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = searchDialCodes(_query.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(s.t('dialCode'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('dialSearch'),
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.t('searchDialCode'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final d = list[i];
                return ListTile(
                  key: ValueKey('dial-${d.iso}'),
                  leading: Text(d.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(d.name(s.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text(d.code,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.moroccoGreen)),
                  onTap: () => Navigator.pop(context, d),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Création du compte (premier lancement ou menu), et « Mon compte » pour le modifier.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.firstLaunch = false});

  /// Premier lancement : bouton « Continuer en démo » pour passer l'inscription.
  final bool firstLaunch;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  late final Account? _existing = accountStore.account;
  late final _first = TextEditingController(text: _existing?.firstName ?? '');
  late final _last = TextEditingController(text: _existing?.lastName ?? '');

  /// Indicatif (liste UIT complète, Maroc par défaut) et numéro local, dans deux champs séparés.
  late DialCode _dial = dialCodeFor(_existing?.phoneCountry);
  late final _phone = TextEditingController(text: _localPart(_existing));
  bool _dialTouched = false;
  late final _email = TextEditingController(text: _existing?.email ?? '');
  final _code = TextEditingController();
  late Country? _country = countryByCode(_existing?.nationality);
  late String _lang = langNotifier.value;
  bool _langTouched = false;
  bool _codeSent = false;
  bool _nationalityMissing = false;
  bool _phoneUnverified = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _email, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  String _normPhone(String v) => v.replaceAll(RegExp(r'[\s.-]'), '');

  static String _localPart(Account? a) {
    if (a == null) return '';
    final code = dialCodeFor(a.phoneCountry).code;
    return a.phone.startsWith(code) ? a.phone.substring(code.length).trim() : a.phone;
  }

  /// Numéro complet : « +212 612345678 ».
  String get _fullPhone => '${_dial.code} ${_phone.text.trim()}';

  /// Le numéro est vérifié s'il n'a pas changé, ou si le bon code SMS a été saisi.
  bool get _verified =>
      (_existing != null && _normPhone(_fullPhone) == _normPhone(_existing.phone)) || _code.text.trim() == demoSmsCode;

  Future<void> _pickCountry() async {
    final c = await showNationalitySheet(context);
    if (c == null || !mounted) return;
    setState(() {
      _country = c;
      _nationalityMissing = false;
      // La langue est proposée selon la nationalité ; le passager peut la changer.
      if (!_langTouched) _lang = c.lang;
      // L'indicatif suit aussi la nationalité, sauf s'il a été choisi à la main.
      if (!_dialTouched) _dial = dialCodeFor(c.code);
    });
  }

  Future<void> _pickDial() async {
    final d = await showDialCodeSheet(context);
    if (d == null || !mounted) return;
    setState(() {
      _dial = d;
      _dialTouched = true;
    });
  }

  void _submit() {
    final ok = _form.currentState!.validate();
    setState(() {
      _nationalityMissing = _country == null;
      _phoneUnverified = !_verified;
    });
    if (!ok || _country == null || !_verified) return;
    final created = _existing == null;
    accountStore.save(Account(
      id: _existing?.id ?? newAccountId(),
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      phone: _fullPhone,
      phoneCountry: _dial.iso,
      email: _email.text.trim(),
      nationality: _country!.code,
    ));
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!widget.firstLaunch && Navigator.canPop(context)) Navigator.pop(context);
    messenger?.showSnackBar(SnackBar(content: Text(s.t(created ? 'accountCreated' : 'accountSaved'))));
    if (_lang != langNotifier.value) langNotifier.value = _lang;
  }

  InputDecoration _deco(String label, {String? hint, String? error, Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  String? _required(String? v) => (v ?? '').trim().isEmpty ? s.t('requiredField') : null;

  @override
  Widget build(BuildContext context) {
    final title = _existing == null ? s.t('createAccount') : s.t('myAccount');
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.firstLaunch,
        title: Text(title),
        flexibleSpace: const Zellige(opacity: .06),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_existing == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(s.t('signUpIntro'), style: const TextStyle(color: AppColors.muted)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${s.t('accountId')} : ${_existing.id}',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('firstName'),
                  controller: _first,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco(s.t('firstName')),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('lastName'),
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco(s.t('lastName')),
                  validator: _required,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // Indicatif (drapeau + code, compact) à côté du numéro local.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                  button: true,
                  label: '${s.t('dialCode')} : ${_dial.name(s.lang)} ${_dial.code}',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.muted)),
                    child: InkWell(
                      key: const ValueKey('dialCode'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDial,
                      child: SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_dial.flag, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 6),
                            Text(_dial.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const Icon(Icons.arrow_drop_down),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: _deco(s.t('localNumber'),
                        hint: '612345678',
                        error: _phoneUnverified && validLocalNumber(_phone.text) && !_verified
                            ? s.t('verifyPhoneFirst')
                            : null,
                        suffix: _verified ? const Icon(Icons.verified, color: AppColors.moroccoGreen) : null),
                    validator: (v) => validLocalNumber(v ?? '') ? null : s.t('invalidPhone'),
                  ),
                ),
              ]),
            ),
            if (!_verified) ...[
              const SizedBox(height: 8),
              if (!_codeSent)
                OutlinedButton.icon(
                  onPressed: validLocalNumber(_phone.text) ? () => setState(() => _codeSent = true) : null,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(s.t('sendCode')),
                )
              else ...[
                // Démo : aucun SMS n'est envoyé, le code est affiché ici.
                Text('${s.t('codeSentDemo')} $demoSmsCode',
                    style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('smsCode'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      _deco(s.t('smsCode'), error: _code.text.length >= 4 && !_verified ? s.t('wrongCode') : null),
                ),
              ],
            ] else if (_existing == null || _normPhone(_fullPhone) != _normPhone(_existing.phone)) ...[
              const SizedBox(height: 4),
              Text(s.t('phoneVerified'),
                  style: const TextStyle(color: AppColors.moroccoGreen, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _deco(s.t('emailOptional')),
              validator: (v) => validEmail(v ?? '') ? null : s.t('invalidEmail'),
            ),
            const SizedBox(height: 12),
            // Nationalité (obligatoire) : liste avec recherche et drapeaux.
            Semantics(
              button: true,
              label: '${s.t('nationality')} : ${_country?.name(s.lang) ?? s.t('chooseNationality')}',
              excludeSemantics: true,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: _nationalityMissing ? AppColors.taxiRed : AppColors.line, width: 1.5),
                ),
                child: ListTile(
                  key: const ValueKey('nationality'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Text(_country?.flag ?? '🌍', style: const TextStyle(fontSize: 26)),
                  title: Text(s.t('nationality'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  subtitle: Text(_country?.name(s.lang) ?? s.t('chooseNationality'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _pickCountry,
                ),
              ),
            ),
            if (_nationalityMissing)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(s.t('requiredField'), style: const TextStyle(color: AppColors.taxiRed, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // La clé suit la langue proposée : le champ se met à jour quand la nationalité change.
              key: ValueKey('appLanguage-$_lang'),
              initialValue: _lang,
              isExpanded: true,
              decoration: _deco(s.t('appLanguage')),
              items: [
                for (final code in S.supported)
                  DropdownMenuItem(value: code, child: Text('${S.flags[code]}  ${S.names[code]}')),
              ],
              onChanged: (v) => setState(() {
                _lang = v ?? _lang;
                _langTouched = true;
              }),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.privacy_tip_outlined, size: 18, color: AppColors.moroccoGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.t('privacyNationality'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('saveAccount'),
              onPressed: _submit,
              child: Text(_existing == null ? s.t('createAccount') : s.t('saveAccount')),
            ),
            if (widget.firstLaunch) TextButton(onPressed: accountStore.skip, child: Text(s.t('continueDemo'))),
          ],
        ),
      ),
    );
  }
}
