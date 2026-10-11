import 'dart:async';
import 'package:flutter/material.dart';

class GlobalNavigationMenu {
  static WidgetBuilder? builder;
  static Object? owner;
  static VoidCallback? homeProfile;
  static Future<Widget?> Function()? profilePage;
  static bool open = false;
  static final observer = GlobalNavigationObserver();
  static void register(Object value, WidgetBuilder menu, VoidCallback profile,
      {Future<Widget?> Function()? profilePageBuilder}) {
    owner = value;
    builder = menu;
    homeProfile = profile;
    profilePage = profilePageBuilder;
  }

  static void unregister(Object value) {
    if (!identical(owner, value)) return;
    owner = null;
    builder = null;
    homeProfile = null;
    profilePage = null;
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

/// Route progress is driven by the finger first, then settles to either endpoint.
class FingerDrawerRoute extends PopupRoute<void> {
  FingerDrawerRoute(this.builder, {this.initialProgress = 1});
  final WidgetBuilder builder;
  final double initialProgress;
  double? _closeStart;
  @override
  Color get barrierColor => Colors.black54;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'القائمة';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);
  @override
  TickerFuture didPush() {
    super.didPush();
    controller!.stop(canceled: false);
    controller!.value = initialProgress.clamp(0.0, 1.0);
    return controller!.animateTo(1, curve: Curves.easeOutCubic);
  }

  void dragTo(double progress) {
    if (isActive) controller!.value = progress.clamp(0.0, 1.0);
  }

  Future<void> settle(bool commit) async {
    if (!isActive) return;
    if (commit) {
      await controller!.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      await controller!.animateBack(0, curve: Curves.easeOutCubic);
      if (isActive) {
        if (isCurrent)
          navigator?.pop();
        else
          navigator?.removeRoute(this);
      }
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) {
                _closeStart = controller!.value;
              },
              onHorizontalDragUpdate: (details) {
                if (_closeStart == null) return;
                dragTo(controller!.value - details.delta.dx / 304);
              },
              onHorizontalDragEnd: (details) {
                _closeStart = null;
                unawaited(settle(details.primaryVelocity! < -350 ||
                    (details.primaryVelocity! <= 350 &&
                        controller!.value > .65)));
              },
              onHorizontalDragCancel: () {
                _closeStart = null;
                unawaited(settle(true));
              },
              child: SafeArea(child: builder(context))));
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      AnimatedBuilder(
          animation: animation,
          builder: (_, c) => Transform.translate(
              offset: Offset(304 * (1 - animation.value), 0), child: c),
          child: child);
}

class FingerProfileRoute extends PageRouteBuilder<void> {
  FingerProfileRoute(Widget page, {this.initialProgress = 1})
      : super(
            opaque: false,
            maintainState: true,
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (_, animation, secondary) => page,
            transitionsBuilder: (_, animation, secondary, child) =>
                SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(-1, 0), end: Offset.zero)
                        .animate(animation),
                    child: child));
  final double initialProgress;
  @override
  TickerFuture didPush() {
    super.didPush();
    controller!.stop(canceled: false);
    controller!.value = initialProgress.clamp(0.0, 1.0);
    return controller!.animateTo(1, curve: Curves.easeOutCubic);
  }

  void dragTo(double progress) {
    if (isActive) controller!.value = progress.clamp(0.0, 1.0);
  }

  Future<void> settle(bool commit) async {
    if (!isActive) return;
    if (commit) {
      await controller!.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      await controller!.animateBack(0, curve: Curves.easeOutCubic);
      if (isActive) {
        if (isCurrent)
          navigator?.pop();
        else
          navigator?.removeRoute(this);
      }
    }
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

class _GlobalNavigationSwipeState extends State<GlobalNavigationSwipe>
    with SingleTickerProviderStateMixin {
  Offset? _start, _last;
  int? _pointer;
  bool _right = false, _starting = false;
  double _width = 1;
  OverlayEntry? _preview;
  Widget? _profilePage;
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));

  void _down(PointerDownEvent event) {
    if (_pointer != null) {
      _cancel();
      return;
    }
    if (!widget.canOpen() ||
        GlobalNavigationMenu.builder == null ||
        GlobalNavigationMenu.open ||
        _preview != null ||
        GlobalNavigationMenu.observer.popup) return;
    final width = MediaQuery.sizeOf(context).width;
    final insets = MediaQuery.systemGestureInsetsOf(context);
    if (event.position.dx > 28 + insets.left &&
        event.position.dx < width - 28 - insets.right) return;
    _pointer = event.pointer;
    _start = event.position;
    _last = event.position;
    _width = width;
    _right = event.position.dx >= width - 28 - insets.right;
  }

  double get _progress {
    if (_start == null || _last == null) return 0;
    final dx = _last!.dx - _start!.dx;
    return ((_right ? -dx : dx) / (_right ? 304 : _width)).clamp(0.0, 1.0);
  }

  Future<void> _begin() async {
    if (_starting || _preview != null || _pointer == null) return;
    final nav = widget.navigatorKey.currentState;
    if (nav == null || !widget.canOpen()) return;
    final pointer = _pointer;
    _starting = true;
    try {
      if (!_right) {
        if (nav.canPop()) return;
        final factory = GlobalNavigationMenu.profilePage;
        if (factory == null) return;
        final page = await factory();
        if (!mounted ||
            _pointer != pointer ||
            page == null ||
            nav.canPop() ||
            !widget.canOpen()) return;
        _profilePage = page;
      }
      if (!mounted || _pointer != pointer) return;
      _animation.value = _progress;
      final menu = GlobalNavigationMenu.builder!;
      final right = _right;
      final page = _profilePage;
      _preview = OverlayEntry(
          builder: (context) => Positioned.fill(
              child: IgnorePointer(
                  child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, child) => right
                          ? Stack(children: [
                              ColoredBox(
                                  color: Colors.black.withValues(
                                      alpha: .54 * _animation.value),
                                  child: const SizedBox.expand()),
                              Transform.translate(
                                  offset:
                                      Offset(304 * (1 - _animation.value), 0),
                                  child: Align(
                                      alignment: Alignment.centerRight,
                                      child: SafeArea(child: menu(context))))
                            ])
                          : Transform.translate(
                              offset:
                                  Offset(-_width * (1 - _animation.value), 0),
                              child: child),
                      child: page))));
      nav.overlay!.insert(_preview!);
    } finally {
      _starting = false;
    }
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer || _start == null) return;
    _last = event.position;
    final delta = _last! - _start!;
    if (_preview == null) {
      if (delta.dy.abs() > 16 && delta.dy.abs() > delta.dx.abs()) {
        _cancel();
        return;
      }
      if (delta.dx.abs() < 10 ||
          delta.dx.abs() < delta.dy.abs() * 1.6 ||
          (_right ? delta.dx >= 0 : delta.dx <= 0)) return;
      unawaited(_begin());
    } else {
      _animation.value = _progress;
    }
  }

  void _removePreview() {
    _preview?.remove();
    _preview?.dispose();
    _preview = null;
    _profilePage = null;
  }

  Future<void> _discardPreview() async {
    if (_preview == null) return;
    await _animation.animateBack(0, curve: Curves.easeOutCubic);
    if (mounted) _removePreview();
  }

  void _up(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    final progress = _progress;
    final start = _start, last = _last;
    _pointer = null;
    _start = null;
    _last = null;
    final nav = widget.navigatorKey.currentState;
    if (_preview != null && nav != null) {
      if (progress < (_right ? .35 : .3)) {
        unawaited(_discardPreview());
        return;
      }
      final page = _profilePage;
      _removePreview();
      if (_right) {
        GlobalNavigationMenu.open = true;
        final route = FingerDrawerRoute(GlobalNavigationMenu.builder!,
            initialProgress: progress);
        unawaited(nav.push(route).whenComplete(() {
          GlobalNavigationMenu.open = false;
        }));
      } else if (page != null) {
        unawaited(
            nav.push(FingerProfileRoute(page, initialProgress: progress)));
      }
    } else if (!_right &&
        GlobalNavigationMenu.profilePage == null &&
        start != null &&
        last != null &&
        last.dx - start.dx >= 72 &&
        nav != null &&
        !nav.canPop()) {
      GlobalNavigationMenu.homeProfile?.call();
    }
  }

  void _cancel() {
    _pointer = null;
    _start = null;
    _last = null;
    unawaited(_discardPreview());
  }

  @override
  void dispose() {
    _removePreview();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: (_) => _cancel(),
      child: widget.child);
}
