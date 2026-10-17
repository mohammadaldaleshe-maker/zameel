import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/feature_control.dart';
import '../trust_game/trust_game_screen.dart';
import 'dice_game_screen.dart';
import 'rps_game_screen.dart';
import 'tarneeb_game_screen.dart';
import 'tictactoe_game_screen.dart';
import 'trix_game_screen.dart';

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
              _gameTile(
                context,
                key: 'zameelRps',
                icon: Icons.back_hand_rounded,
                title: ar ? 'حجر ورقة مقص' : 'Rock Paper Scissors',
                subtitle: ar ? 'ضد الهاتف أو لاعبان' : 'vs phone or two players',
                page: RpsGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                key: 'zameelDice',
                icon: Icons.casino_rounded,
                title: ar ? 'النرد' : 'Dice',
                subtitle: ar ? 'تحدَّ الهاتف أو صديقك' : 'duel the phone or a friend',
                page: DiceGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                key: 'zameelTicTacToe',
                icon: Icons.grid_3x3_rounded,
                title: ar ? 'إكس أو' : 'Tic-Tac-Toe',
                subtitle: ar ? 'ثلاثة مستويات ولاعبان' : 'three levels and two players',
                page: TicTacToeGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                key: 'zameelTarneeb',
                icon: Icons.style_rounded,
                title: ar ? 'الطرنيب' : 'Tarneeb',
                subtitle: ar ? 'أنت وشريكك ضد خصمين' : 'you and a partner vs two opponents',
                page: TarneebGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                key: 'zameelTrix',
                icon: Icons.layers_rounded,
                title: ar ? 'التركس' : 'Trix',
                subtitle: ar ? 'أربعة لاعبين وخمسة عقود' : 'four players and five contracts',
                page: TrixGameScreen(isArabic: ar),
              ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameTile(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      child: ListTile(
        key: ValueKey(key),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page)),
      ),
    );
  }
}
