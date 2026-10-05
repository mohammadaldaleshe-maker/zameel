import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/feature_control.dart';
import '../trust_game/trust_game_screen.dart';

class ZameelGamesScreen extends StatelessWidget {
  const ZameelGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<LanguageProvider>().isArabic;
    final features = FeatureControl.instance;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'ألعاب زميل' : 'Zameel games')),
        body: ValueListenableBuilder<int>(
          valueListenable: features.changes,
          builder: (context, value, child) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (features.visible('trust_game'))
                Card(
                    child: ListTile(
                  key: const ValueKey('zameelTrustGame'),
                  leading: const Icon(Icons.handshake_outlined),
                  title: Text(ar ? 'ثقة أم غدر؟' : 'Trust or Betray?'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => features.open(context, 'trust_game',
                      () => TrustGameScreen(isArabic: ar)),
                ))
              else
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      ar
                          ? 'لا توجد ألعاب متاحة حاليًا.'
                          : 'No games are currently available.',
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
