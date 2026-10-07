import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayBillingService extends ChangeNotifier {
  PlayBillingService._();
  static final instance = PlayBillingService._();
  static bool get enabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const bool.fromEnvironment('ZAMEEL_GOOGLE_PLAY_BILLING');
  static const _channel = MethodChannel('zameel/play_billing');
  final Map<String, String> _states = {};
  final Set<String> _processing = {};
  bool _started = false;
  String? error;
  String? state(String binding) => _states[binding];
  Future<Map<String, dynamic>> api(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'play-billing',
      body: body,
    );
    final data = response.data;
    if (data is! Map || data['ok'] != true)
      throw StateError('billing_request_failed');
    final value = Map<String, dynamic>.from(data);
    final intent = value['intent'];
    if (intent is Map &&
        intent['intent_binding'] is String &&
        intent['state'] is String) {
      _states[intent['intent_binding'] as String] = intent['state'] as String;
      notifyListeners();
    }
    return value;
  }

  Future<void> initialize() async {
    if (!enabled || _started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'updates' && call.arguments is Map) {
        final data = Map<Object?, Object?>.from(call.arguments as Map);
        final code = data['code'];
        if (code == 1) {
          error = 'تم إلغاء الشراء؛ لم نسجل دفعة.';
          notifyListeners();
        } else if (code != 0) {
          error = 'تعذر إتمام الشراء عبر Google Play.';
          notifyListeners();
        }
        for (final item in (data['purchases'] as List? ?? const [])) {
          if (item is Map) await _verify(Map<Object?, Object?>.from(item));
        }
      }
    });
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _states.clear();
      error = null;
      if (Supabase.instance.client.auth.currentUser != null)
        unawaited(recover());
    });
    await recover();
  }

  Future<void> recover() async {
    if (!enabled || Supabase.instance.client.auth.currentUser == null) return;
    try {
      await _channel.invokeMethod<bool>('connect');
      final rows = await _channel.invokeListMethod<dynamic>('recover') ?? [];
      for (final row in rows) {
        if (row is Map) await _verify(Map<Object?, Object?>.from(row));
      }
    } catch (_) {
      error = 'تعذر تحديث مشتريات Google Play. أعد المحاولة.';
      notifyListeners();
    }
  }

  Future<void> _verify(Map<Object?, Object?> item) async {
    final token = item['token'];
    final binding = item['binding'];
    if (token is! String || binding is! String || _processing.contains(token))
      return;
    if (item['state'] != 1) {
      _states[binding] = 'pending';
      notifyListeners();
      return;
    }
    final products = item['products'];
    if (products is! List ||
        products.length != 1 ||
        Supabase.instance.client.auth.currentUser == null) return;
    _processing.add(token);
    try {
      final data = await api({
        'action': 'verify',
        'purchaseToken': token,
        'productId': products.single,
        'binding': binding,
      });
      _states[binding] =
          data['settlement_state']?.toString() ?? 'awaiting_review';
      error = null;
    } catch (_) {
      error =
          'لم نتمكن من تأكيد الدفع بعد. لا تدفع مرة ثانية؛ اضغط تحديث المشتريات.';
    } finally {
      _processing.remove(token);
      notifyListeners();
    }
  }

  Future<String?> price(String id) async {
    await initialize();
    await _channel.invokeMethod<bool>('connect');
    final rows = await _channel.invokeListMethod<dynamic>('products', {
          'ids': [id],
        }) ??
        [];
    for (final row in rows) {
      if (row is Map && row['id'] == id) return row['price']?.toString();
    }
    return null;
  }

  Future<void> buy(Map<String, dynamic> intent) async {
    final status = await api({'action': 'status', 'intentId': intent['id']});
    if (status['state'] != 'awaiting_payment') {
      await recover();
      return;
    }
    final code = await _channel.invokeMethod<int>('buy', {
      'id': intent['product_id'],
      'account': intent['account_binding'],
      'profile': intent['intent_binding'],
    });
    if (code != 0) throw StateError('purchase_unavailable');
  }
}
