part of '../main.dart';

class _ZameelArcMenu extends StatefulWidget {
  final bool isArabic;
  final List<_ArcItemData> items;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onCustomize;

  const _ZameelArcMenu({
    required this.isArabic,
    required this.items,
    required this.onDrag,
    required this.onCustomize,
  });

  @override
  State<_ZameelArcMenu> createState() => _ZameelArcMenuState();
}

class _ZameelArcMenuState extends State<_ZameelArcMenu> {
  bool open = false;

  void _toggle() => setState(() => open = !open);

  List<Offset> _positions(int count) {
    switch (count) {
      case 1:
        return const [Offset(84, 2)];
      case 2:
        return const [Offset(42, 18), Offset(126, 18)];
      case 3:
        return const [Offset(14, 46), Offset(84, 2), Offset(154, 46)];
      case 4:
        return const [Offset(0, 58), Offset(56, 10), Offset(112, 10), Offset(168, 58)];
      default:
        return const [
          Offset(0, 58),
          Offset(42, 18),
          Offset(84, 2),
          Offset(126, 18),
          Offset(168, 58),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(5).toList();
    final offsets = _positions(items.length);
    return SizedBox(
      width: 250,
      height: open ? 255 : 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (open)
            ...List.generate(items.length, (i) {
              final offset = offsets[i];
              return Positioned(
                top: 48 + offset.dy,
                left: widget.isArabic ? offset.dx : 192 - offset.dx,
                child: _arcButton(items[i]),
              );
            }),
          if (open)
            Positioned(
              top: 4,
              left: widget.isArabic ? 64 : null,
              right: widget.isArabic ? null : 64,
              child: Tooltip(
                message: widget.isArabic ? 'تخصيص الزر العائم' : 'Customize floating menu',
                child: InkWell(
                  onTap: () {
                    setState(() => open = false);
                    widget.onCustomize();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
                    ),
                    child: const Icon(Icons.tune_rounded, color: primaryColor, size: 20),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: widget.isArabic ? 0 : null,
            right: widget.isArabic ? null : 0,
            child: GestureDetector(
              onTap: _toggle,
              onLongPress: widget.onCustomize,
              onPanUpdate: (details) => widget.onDrag(details.delta),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
                  boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 5), color: Colors.black26)],
                  border: Border.all(color: Colors.white.withAlpha(210), width: 2),
                ),
                child: AnimatedRotation(
                  turns: open ? .125 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(open ? Icons.close_rounded : Icons.apps_rounded, color: Colors.white, size: 29),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arcButton(_ArcItemData item) => GestureDetector(
        onTap: () {
          setState(() => open = false);
          item.onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 49,
              height: 49,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 9, color: Colors.black26)],
              ),
              child: Icon(item.icon, color: primaryColor, size: 23),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(125),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.label,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _ArcItemData {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ArcItemData(this.id, this.icon, this.label, this.onTap);
}
