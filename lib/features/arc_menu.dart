part of '../main.dart';

class _ZameelArcMenu extends StatefulWidget {
  final bool isArabic;
  final VoidCallback onChat;
  final VoidCallback onCalendar;
  final VoidCallback onGroups;
  final VoidCallback onBooks;
  final VoidCallback onVideos;
  final ValueChanged<Offset> onDrag;

  const _ZameelArcMenu({
    required this.isArabic,
    required this.onChat,
    required this.onCalendar,
    required this.onGroups,
    required this.onBooks,
    required this.onVideos,
    required this.onDrag,
  });

  @override
  State<_ZameelArcMenu> createState() => _ZameelArcMenuState();
}

class _ZameelArcMenuState extends State<_ZameelArcMenu> {
  bool open = false;

  void _toggle() => setState(() => open = !open);

  @override
  Widget build(BuildContext context) {
    final items = <_ArcItemData>[
      _ArcItemData(Icons.chat_bubble_rounded, widget.isArabic ? 'الدردشة' : 'Chat', widget.onChat),
      _ArcItemData(Icons.calendar_month_rounded, widget.isArabic ? 'جدولي' : 'Schedule', widget.onCalendar),
      _ArcItemData(Icons.groups_rounded, widget.isArabic ? 'مجموعاتي' : 'Groups', widget.onGroups),
      _ArcItemData(Icons.menu_book_rounded, widget.isArabic ? 'الكتب' : 'Books', widget.onBooks),
      _ArcItemData(Icons.movie_creation_rounded, widget.isArabic ? 'الفيديوهات' : 'Videos', widget.onVideos),
    ];
    return SizedBox(
      width: 250,
      height: open ? 255 : 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (open)
            ...List.generate(items.length, (i) {
              const offsets = <Offset>[
                Offset(0, 58),
                Offset(42, 18),
                Offset(84, 2),
                Offset(126, 18),
                Offset(168, 58),
              ];
              final offset = offsets[i];
              return Positioned(
                top: 48 + offset.dy,
                left: widget.isArabic ? offset.dx : 192 - offset.dx,
                child: _arcButton(items[i]),
              );
            }),
          Positioned(
            top: 0,
            left: widget.isArabic ? 0 : null,
            right: widget.isArabic ? null : 0,
            child: GestureDetector(
              onTap: _toggle,
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
    onTap: () { setState(() => open = false); item.onTap(); },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 49, height: 49, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(blurRadius: 9, color: Colors.black26)]), child: Icon(item.icon, color: primaryColor, size: 23)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.black.withAlpha(125), borderRadius: BorderRadius.circular(10)), child: Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
      ],
    ),
  );
}

class _ArcItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ArcItemData(this.icon, this.label, this.onTap);
}
