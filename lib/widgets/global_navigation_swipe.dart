import 'package:flutter/material.dart';

/// Reuses the existing menu and its feature/permission checks on every route.
class GlobalNavigationMenu {
  static WidgetBuilder? builder;
  static Object? owner;
  static VoidCallback? homeProfile;
  static bool open = false;
  static final observer = GlobalNavigationObserver();
  static void register(Object value, WidgetBuilder menu, VoidCallback profile) {
    owner = value;
    builder = menu;
    homeProfile = profile;
  }

  static void unregister(Object value) {
    if (!identical(owner, value)) return;
    owner = null;
    builder = null;
    homeProfile = null;
  }
}

class GlobalNavigationObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  bool get popup => _routes.isNotEmpty && _routes.last is PopupRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
  }
}

class GlobalNavigationSwipe extends StatefulWidget {
  const GlobalNavigationSwipe(
      {super.key,
      required this.navigatorKey,
      required this.canOpen,
      required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() canOpen;
  final Widget child;
  @override
  State<GlobalNavigationSwipe> createState() => _GlobalNavigationSwipeState();
}

class _GlobalNavigationSwipeState extends State<GlobalNavigationSwipe> {
  Offset? _start;
  Offset? _last;
  int? _pointer;
  bool _right = false;
  void _down(PointerDownEvent event) {
    if (_pointer != null) {
      _start = null;
      return;
    }
    if (!widget.canOpen() ||
        GlobalNavigationMenu.builder == null ||
        GlobalNavigationMenu.open ||
        GlobalNavigationMenu.observer.popup) return;
    final width = MediaQuery.sizeOf(context).width;
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final leftEdge = 28 + insets.left, rightEdge = 28 + insets.right;
    if (event.position.dx > leftEdge && event.position.dx < width - rightEdge)
      return;
    _pointer = event.pointer;
    _start = event.position;
    _last = event.position;
    _right = event.position.dx >= width - rightEdge;
  }

  Future<void> _up(PointerUpEvent event) async {
    if (_pointer != event.pointer) return;
    final start = _start, last = _last;
    _pointer = null;
    _start = null;
    _last = null;
    if (start == null || last == null || !widget.canOpen()) return;
    final delta = last - start;
    if (delta.dx.abs() < 72 || delta.dx.abs() < delta.dy.abs() * 1.6) return;
    final nav = widget.navigatorKey.currentState;
    if (nav == null || GlobalNavigationMenu.observer.popup) return;
    if (!_right && delta.dx > 0 && !nav.canPop()) {
      GlobalNavigationMenu.homeProfile?.call();
      return;
    }
    if (!_right || delta.dx >= 0 || GlobalNavigationMenu.open) return;
    final builder = GlobalNavigationMenu.builder;
    if (builder == null) return;
    GlobalNavigationMenu.open = true;
    try {
      await showGeneralDialog<void>(
          context: nav.context,
          barrierDismissible: true,
          barrierLabel: 'القائمة',
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (c, animation, secondaryAnimation) => Align(
              alignment: Alignment.centerRight,
              child: SafeArea(child: builder(c))),
          transitionBuilder: (c, animation, secondaryAnimation, child) =>
              SlideTransition(
                  position:
                      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: animation, curve: Curves.easeOut)),
                  child: child));
    } finally {
      GlobalNavigationMenu.open = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: (event) {
        if (_pointer == event.pointer) _last = event.position;
      },
      onPointerUp: _up,
      onPointerCancel: (event) {
        if (_pointer == event.pointer) {
          _pointer = null;
          _start = null;
        }
      },
      child: widget.child);
}
