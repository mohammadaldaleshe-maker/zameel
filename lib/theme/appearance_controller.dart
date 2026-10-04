import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAppearance { original, light, dark, system }

class AppearanceController extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = AppearanceController._();
  AppearanceController._();
  AppAppearance _appearance = AppAppearance.original;
  AppAppearance get appearance => _appearance;
  bool get original => _appearance == AppAppearance.original;
  Brightness get brightness => _appearance == AppAppearance.dark ||
          (_appearance == AppAppearance.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark)
      ? Brightness.dark
      : Brightness.light;
  ThemeMode get themeMode => _appearance == AppAppearance.system
      ? ThemeMode.system
      : brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final stored = (await SharedPreferences.getInstance())
          .getString('zameel_appearance');
      _appearance = AppAppearance.values.firstWhere((x) => x.name == stored,
          orElse: () => AppAppearance.original);
    } catch (_) {
      _appearance = AppAppearance.original;
    }
  }

  Future<void> select(AppAppearance value) async {
    if (_appearance != value) {
      _appearance = value;
      notifyListeners();
    }
    await (await SharedPreferences.getInstance())
        .setString('zameel_appearance', value.name);
  }

  @override
  void didChangePlatformBrightness() {
    if (_appearance == AppAppearance.system) notifyListeners();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  AppearanceScope({super.key, required super.child})
      : super(notifier: AppearanceController.instance);
  static void observe(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
  }

  static Widget rebuild(BuildContext context, Widget Function() builder) {
    observe(context);
    return builder();
  }
}
