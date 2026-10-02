import 'package:flutter/material.dart';

import '../main.dart';
import '../services/rides.dart';
import '../theme.dart';

/// Historique des courses (terminées et prévues).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
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
                  final date =
                      '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')} · ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: t.scheduled ? const Color(0xFFFFF4D6) : const Color(0xFFE8F3EC),
                        foregroundColor: t.scheduled ? const Color(0xFFB07D00) : AppColors.moroccoGreen,
                        child: Icon(t.scheduled ? Icons.schedule : Icons.check),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.destination, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('$date · ${t.option}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          if (t.driver != null)
                            Text(
                                '${t.driver!.name} · ${t.driver!.taxiNumber}${t.rating > 0 ? ' · ${'★' * t.rating}' : ''}',
                                style: const TextStyle(fontSize: 13)),
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
