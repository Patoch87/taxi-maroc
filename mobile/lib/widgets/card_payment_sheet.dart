import 'package:flutter/material.dart';

import '../main.dart';
import '../services/card_check.dart';
import '../services/rides.dart';
import '../theme.dart';

/// Paiement du pourboire par carte : carte enregistrée « Visa •••• 4242 » ou nouvelle carte.
/// Paiement simulé (démo) : rien n'est débité, le numéro n'est ni envoyé ni gardé.
/// Renvoie true quand le paiement (simulé) est validé.
Future<bool?> showCardPaymentSheet(BuildContext context, {required double amount}) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => CardPaymentView(amount: amount),
    );

class CardPaymentView extends StatefulWidget {
  const CardPaymentView({super.key, required this.amount});
  final double amount;

  @override
  State<CardPaymentView> createState() => _CardPaymentViewState();
}

class _CardPaymentViewState extends State<CardPaymentView> {
  bool _newCard = false;
  bool _checked = false;
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  bool get _valid => validCardNumber(_number.text) && validExpiry(_expiry.text) && validCvc(_cvc.text);

  void _pay() {
    if (_newCard && !_valid) {
      setState(() => _checked = true);
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _cardChoice({required bool newCard, required IconData icon, required String title, String? subtitle}) {
    final selected = _newCard == newCard;
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.moroccoGreen : AppColors.line, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _newCard = newCard),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(icon, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (subtitle != null) Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppColors.moroccoGreen : AppColors.muted),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final err = _checked && _newCard;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('${s.t('tip')} · ${dh(widget.amount)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            // Mention bien visible : aucun paiement réel.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.taxiRed, borderRadius: BorderRadius.circular(8)),
                child: Text(s.t('simulatedPayment'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 12),
            _cardChoice(newCard: false, icon: Icons.credit_card, title: 'Visa •••• 4242', subtitle: s.t('savedCard')),
            const SizedBox(height: 8),
            _cardChoice(newCard: true, icon: Icons.add_card, title: s.t('addCard')),
            if (_newCard) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('cardNumber'),
                controller: _number,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: s.t('cardNumber'),
                  hintText: '4242 4242 4242 4242',
                  errorText: err && !validCardNumber(_number.text) ? s.t('invalidCard') : null,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('cardExpiry'),
                    controller: _expiry,
                    keyboardType: TextInputType.datetime,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('cardExpiry'),
                      hintText: '12/29',
                      errorText: err && !validExpiry(_expiry.text) ? s.t('invalidExpiry') : null,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: TextField(
                    key: const ValueKey('cardCvc'),
                    controller: _cvc,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('cardCvc'),
                      errorText: err && !validCvc(_cvc.text) ? s.t('invalidCvc') : null,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pay,
              icon: const Icon(Icons.lock_outline),
              label: Text('${s.t('payNow')} ${dh(widget.amount)}'),
            ),
          ]),
        ),
      ),
    );
  }
}
