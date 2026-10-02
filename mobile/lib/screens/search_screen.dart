import 'package:flutter/material.dart';

import '../main.dart';
import '../services/places.dart';
import '../theme.dart';

/// Recherche de destination plein écran. Renvoie le lieu choisi.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final results = searchPlaces(_q);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(s.t('whereTo'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: s.t('searchPlace'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: AppColors.line),
              itemBuilder: (_, i) {
                final p = results[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF3F3F3),
                    foregroundColor: AppColors.ink,
                    child: Icon(p.intercity ? Icons.alt_route : Icons.place),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.subtitle, style: const TextStyle(color: AppColors.muted)),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
