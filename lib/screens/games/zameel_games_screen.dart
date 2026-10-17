import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/feature_control.dart';
import '../trust_game/trust_game_screen.dart';
import 'dice_game_screen.dart';
import 'game_kit.dart';
import 'rps_game_screen.dart';
import 'snakes_ladders_game_screen.dart';
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
      child: GameScaffold(
        title: ar ? 'ألعاب زميل' : 'Zameel games',
        body: ValueListenableBuilder<int>(
          valueListenable: features.changes,
          builder: (context, value, child) {
            final tiles = <Widget>[
              _gameTile(
                context,
                index: 0,
                key: 'zameelTarneeb',
                icon: Icons.style_rounded,
                colors: const <Color>[Color(0xFF3152E8), Color(0xFF4B23B7)],
                title: ar ? 'الطرنيب' : 'Tarneeb',
                subtitle: ar
                    ? 'أنت وشريكك ضد خصمين'
                    : 'you and a partner vs two opponents',
                page: TarneebGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                index: 1,
                key: 'zameelTrix',
                icon: Icons.layers_rounded,
                colors: const <Color>[Color(0xFF8E3DD1), Color(0xFF3A1E8C)],
                title: ar ? 'التركس' : 'Trix',
                subtitle: ar
                    ? 'أربعة لاعبين وخمسة عقود'
                    : 'four players and five contracts',
                page: TrixGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                index: 2,
                key: 'zameelSnakesLadders',
                icon: Icons.stairs_rounded,
                colors: const <Color>[Color(0xFF1FA67A), Color(0xFF176A8C)],
                title: ar ? 'الحية والسلم' : 'Snakes & Ladders',
                subtitle: ar
                    ? 'ارمِ النرد وتسلّق إلى ١٠٠'
                    : 'roll the dice and race to 100',
                page: SnakesLaddersGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                index: 3,
                key: 'zameelTicTacToe',
                icon: Icons.grid_3x3_rounded,
                colors: const <Color>[Color(0xFFE04F8E), Color(0xFF8E2A9E)],
                title: ar ? 'إكس أو' : 'Tic-Tac-Toe',
                subtitle: ar
                    ? 'ثلاثة مستويات ولاعبان'
                    : 'three levels and two players',
                page: TicTacToeGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                index: 4,
                key: 'zameelDice',
                icon: Icons.casino_rounded,
                colors: const <Color>[Color(0xFFFF8A5B), Color(0xFFD1446B)],
                title: ar ? 'النرد' : 'Dice',
                subtitle: ar
                    ? 'تحدَّ الهاتف أو صديقك'
                    : 'duel the phone or a friend',
                page: DiceGameScreen(isArabic: ar),
              ),
              _gameTile(
                context,
                index: 5,
                key: 'zameelRps',
                icon: Icons.back_hand_rounded,
                colors: const <Color>[Color(0xFF27C7C7), Color(0xFF2D6BD6)],
                title: ar ? 'حجر ورقة مقص' : 'Rock Paper Scissors',
                subtitle:
                    ar ? 'ضد الهاتف أو لاعبان' : 'vs phone or two players',
                page: RpsGameScreen(isArabic: ar),
              ),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 4),
                  child: Text(
                    ar ? 'اختر لعبتك 🎮' : 'Pick your game 🎮',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ...tiles,
                if (features.visible('trust_game'))
                  _trustTile(context, ar, features),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _trustTile(BuildContext context, bool ar, FeatureControl features) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GamePanel(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const ValueKey('zameelTrustGame'),
          leading: const Icon(Icons.handshake_outlined, color: Colors.white),
          title: Text(
            ar ? 'ثقة أم غدر؟' : 'Trust or Betray?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          onTap: () => features.open(
              context, 'trust_game', () => TrustGameScreen(isArabic: ar)),
        ),
      ),
    );
  }

  Widget _gameTile(
    BuildContext context, {
    required int index,
    required String key,
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - v)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            key: ValueKey(key),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.first.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                gameTap();
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => page));
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 34),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
