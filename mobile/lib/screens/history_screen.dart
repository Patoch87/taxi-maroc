import 'package:flutter/material.dart';

import '../main.dart';
import '../services/rides.dart';
import '../services/schedule.dart';
import '../theme.dart';

/// Historique des courses (terminées et prévues).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(s.t('history'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: tripHistory.isEmpty
            ? Center(child: Text(s.t('noHistory'), style: const TextStyle(color: AppColors.muted)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tripHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final t = tripHistory[i];
                  final date = t.scheduled
                      ? scheduleLabel(t.date, lang: s.lang)
                      : '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')} · ${hhmm(t.date)}';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: t.scheduled ? AppColors.sandDeep : AppColors.greenSoft,
                        foregroundColor: t.scheduled ? AppColors.taxiRed : AppColors.moroccoGreen,
                        child: Icon(t.scheduled ? Icons.schedule : Icons.check),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.destination, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('$date · ${t.option}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          if (t.passengerName != null)
                            Text('${s.t('passenger')} : ${t.passengerName}',
                                style: const TextStyle(
                                    color: AppColors.moroccoGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                          if (t.driver != null)
                            Text('${t.driver!.name} · ${t.driver!.taxiNumber}', style: const TextStyle(fontSize: 13)),
                          // Note, avis et pourboire laissés à la fin de la course.
                          if (t.rating > 0)
                            Semantics(
                              label: '${t.rating} ${s.t('stars')}',
                              excludeSemantics: true,
                              child: Row(children: [
                                for (var i = 1; i <= 5; i++)
                                  Icon(i <= t.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 18, color: AppColors.gold),
                              ]),
                            ),
                          if (t.tags.isNotEmpty)
                            Text(t.tags.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          if (t.comment.isNotEmpty)
                            Text('« ${t.comment} »',
                                style:
                                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.muted)),
                          if (t.tip > 0)
                            Text('${s.t('tip')} : ${dh(t.tip)}',
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.moroccoGreen, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(dh(t.price + t.tip), style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(t.scheduled ? s.t('planned') : s.t('completed'),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ]),
                  );
                },
              ),
      );
}
