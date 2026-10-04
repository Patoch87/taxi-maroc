import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../theme.dart';
import 'sheets.dart';

/// Choix de la langue : une grille de drapeaux, chaque langue écrite dans sa propre langue.
Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sand,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            sheetHeader(s.t('language'), icon: Icons.translate, color: AppColors.moroccoGreen),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.25,
              children: [
                for (final code in S.supported)
                  _LanguageTile(
                    code: code,
                    selected: langNotifier.value == code,
                    onTap: () {
                      Navigator.pop(ctx);
                      langNotifier.value = code;
                    },
                  ),
              ],
            ),
          ]),
        ),
      ),
    );

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.code, required this.selected, required this.onTap});
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: S.names[code],
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.greenSoft : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? AppColors.moroccoGreen : AppColors.line, width: selected ? 2 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(S.flags[code]!, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(S.names[code]!,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: selected ? AppColors.moroccoGreen : AppColors.ink)),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Petit bouton rond avec le drapeau de la langue actuelle, qui ouvre le choix de la langue.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: Semantics(
          button: true,
          label: '${s.t('language')} : ${S.names[s.lang]}',
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showLanguageSheet(context),
            child: SizedBox.square(
              dimension: 48,
              child: Center(child: Text(S.flags[s.lang]!, style: const TextStyle(fontSize: 24))),
            ),
          ),
        ),
      );
}
