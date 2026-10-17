import 'dart:math';

import 'package:flutter/material.dart';

// The computer players of the games: Arabic names (men and women) and
// hand-drawn avatars. Pure presentation - no game rule depends on this file.

enum BotLook { shortHair, cap, beard, ghutra, longHair, hijab, ponytail }

class BotPersona {
  const BotPersona({
    required this.nameAr,
    required this.nameEn,
    required this.female,
    required this.look,
    required this.skin,
    required this.accent,
    required this.detail,
  });

  final String nameAr;
  final String nameEn;
  final bool female;
  final BotLook look;
  final Color skin;
  final Color accent;
  // Hair colour, scarf colour or cap colour depending on the look.
  final Color detail;

  String name(bool ar) => ar ? nameAr : nameEn;
}

const List<BotPersona> kBotPersonas = <BotPersona>[
  BotPersona(
    nameAr: 'سالم',
    nameEn: 'Salem',
    female: false,
    look: BotLook.shortHair,
    skin: Color(0xFFE8B98F),
    accent: Color(0xFF2F6BFF),
    detail: Color(0xFF2B1B14),
  ),
  BotPersona(
    nameAr: 'فارس',
    nameEn: 'Fares',
    female: false,
    look: BotLook.cap,
    skin: Color(0xFFD9A57C),
    accent: Color(0xFF1DB6A6),
    detail: Color(0xFFFF8A5B),
  ),
  BotPersona(
    nameAr: 'يزن',
    nameEn: 'Yazan',
    female: false,
    look: BotLook.beard,
    skin: Color(0xFFF0C8A4),
    accent: Color(0xFF8A5BFF),
    detail: Color(0xFF3A2418),
  ),
  BotPersona(
    nameAr: 'ماجد',
    nameEn: 'Majed',
    female: false,
    look: BotLook.ghutra,
    skin: Color(0xFFC98F66),
    accent: Color(0xFFFFB300),
    detail: Color(0xFFFFFFFF),
  ),
  BotPersona(
    nameAr: 'ليان',
    nameEn: 'Layan',
    female: true,
    look: BotLook.longHair,
    skin: Color(0xFFF2CBA8),
    accent: Color(0xFFFF5C8A),
    detail: Color(0xFF4A2A1A),
  ),
  BotPersona(
    nameAr: 'سلمى',
    nameEn: 'Salma',
    female: true,
    look: BotLook.hijab,
    skin: Color(0xFFE8B98F),
    accent: Color(0xFFB583FF),
    detail: Color(0xFF7B4DFF),
  ),
  BotPersona(
    nameAr: 'رند',
    nameEn: 'Rand',
    female: true,
    look: BotLook.ponytail,
    skin: Color(0xFFD9A57C),
    accent: Color(0xFF2FB8FF),
    detail: Color(0xFF1E1E2A),
  ),
  BotPersona(
    nameAr: 'جود',
    nameEn: 'Joud',
    female: true,
    look: BotLook.hijab,
    skin: Color(0xFFF0C8A4),
    accent: Color(0xFFFF8A5B),
    detail: Color(0xFF1DB6A6),
  ),
];

// The group of computer players sitting at the current game. The screen draws
// it once when it opens, so names stay the same for the whole game.
class BotCast {
  BotCast._(this._seats);

  final Map<int, BotPersona> _seats;

  static BotCast? current;

  static BotCast draw(List<int> seats, {Random? random}) {
    final rng = random ?? Random();
    final pool = List<BotPersona>.of(kBotPersonas)..shuffle(rng);
    final map = <int, BotPersona>{};
    for (var i = 0; i < seats.length; i++) {
      map[seats[i]] = pool[i % pool.length];
    }
    final cast = BotCast._(map);
    current = cast;
    return cast;
  }

  BotPersona? at(int seat) => _seats[seat];
}

// Avatar painted with a CustomPainter: round backdrop, shoulders, face and a
// hair style. Nothing is loaded from the network or from assets.
class BotAvatar extends StatelessWidget {
  const BotAvatar({super.key, required this.persona, this.size = 34});

  final BotPersona persona;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AvatarPainter(persona)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.p);

  final BotPersona p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: s / 2)));

    // Backdrop.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[p.accent, p.accent.withOpacity(0.55)],
        ).createShader(Offset.zero & size),
    );

    final head = Offset(s * 0.5, s * 0.43);
    final headR = s * 0.2;
    final skin = Paint()..color = p.skin;
    final hair = Paint()..color = p.detail;
    final cloth = Paint()
      ..color = p.female ? Colors.white.withOpacity(0.92) : const Color(0xFF263045);

    // Hair / scarf that sits behind the face.
    if (p.look == BotLook.longHair) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.26, s * 0.2, s * 0.48, s * 0.62),
          Radius.circular(s * 0.22),
        ),
        hair,
      );
    } else if (p.look == BotLook.hijab) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.5), width: s * 0.66, height: s * 0.8),
        hair,
      );
    } else if (p.look == BotLook.ponytail) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.76, s * 0.56), width: s * 0.16, height: s * 0.38),
        hair,
      );
    } else if (p.look == BotLook.ghutra) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.5), width: s * 0.64, height: s * 0.78),
        hair,
      );
    }

    // Shoulders.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.98), width: s * 0.86, height: s * 0.6),
      p.look == BotLook.hijab ? hair : cloth,
    );
    // Neck.
    canvas.drawRect(
      Rect.fromLTWH(s * 0.44, s * 0.58, s * 0.12, s * 0.16),
      skin,
    );
    // Face.
    canvas.drawCircle(head, headR, skin);

    // Front hair, caps and beards.
    switch (p.look) {
      case BotLook.shortHair:
      case BotLook.beard:
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: headR * 1.08),
          pi,
          pi,
          true,
          hair,
        );
        if (p.look == BotLook.beard) {
          canvas.drawArc(
            Rect.fromCircle(center: head, radius: headR * 1.04),
            0.15,
            pi - 0.3,
            true,
            hair,
          );
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(head.dx, head.dy + headR * 0.55),
                width: headR * 0.9,
                height: headR * 0.5),
            skin,
          );
        }
        break;
      case BotLook.cap:
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: headR * 1.1),
          pi,
          pi,
          true,
          hair,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx - headR * 1.25, head.dy - headR * 0.12,
                headR * 2.5, headR * 0.28),
            Radius.circular(headR * 0.14),
          ),
          hair,
        );
        break;
      case BotLook.ghutra:
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: headR * 1.12),
          pi,
          pi,
          true,
          hair,
        );
        canvas.drawRect(
          Rect.fromLTWH(head.dx - headR * 1.1, head.dy - headR * 0.62,
              headR * 2.2, headR * 0.22),
          Paint()..color = const Color(0xFF1B1B22),
        );
        break;
      case BotLook.longHair:
      case BotLook.ponytail:
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: headR * 1.08),
          pi,
          pi,
          true,
          hair,
        );
        break;
      case BotLook.hijab:
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: headR * 1.12),
          pi,
          pi,
          true,
          hair,
        );
        break;
    }

    // Eyes and smile.
    final dark = Paint()..color = const Color(0xFF241812);
    final eyeY = head.dy - headR * 0.05;
    canvas.drawCircle(Offset(head.dx - headR * 0.4, eyeY), s * 0.022, dark);
    canvas.drawCircle(Offset(head.dx + headR * 0.4, eyeY), s * 0.022, dark);
    if (p.female) {
      final lash = Paint()
        ..color = const Color(0xFF241812)
        ..strokeWidth = s * 0.012
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(head.dx - headR * 0.58, eyeY - s * 0.012),
          Offset(head.dx - headR * 0.68, eyeY - s * 0.03), lash);
      canvas.drawLine(Offset(head.dx + headR * 0.58, eyeY - s * 0.012),
          Offset(head.dx + headR * 0.68, eyeY - s * 0.03), lash);
    }
    final smile = Paint()
      ..color = p.look == BotLook.beard
          ? Colors.white
          : const Color(0xFF8A3B2E)
      ..strokeWidth = s * 0.016
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(head.dx, head.dy + headR * 0.38),
          width: headR * 0.7,
          height: headR * 0.4),
      0.2,
      pi - 0.4,
      false,
      smile,
    );
    // Blush.
    final blush = Paint()..color = const Color(0x33FF5C5C);
    canvas.drawCircle(Offset(head.dx - headR * 0.62, head.dy + headR * 0.3),
        s * 0.03, blush);
    canvas.drawCircle(Offset(head.dx + headR * 0.62, head.dy + headR * 0.3),
        s * 0.03, blush);

    canvas.restore();
    canvas.drawCircle(
      c,
      s / 2 - 0.75,
      Paint()
        ..color = Colors.white.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.p != p;
}
