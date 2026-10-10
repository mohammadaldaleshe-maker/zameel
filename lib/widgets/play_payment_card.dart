import 'package:flutter/material.dart';

import '../services/play_billing_service.dart';

class PlayPaymentCard extends StatefulWidget {
  final Map<String, dynamic> receipt;
  const PlayPaymentCard({super.key, required this.receipt});
  @override
  State<PlayPaymentCard> createState() => _PlayPaymentCardState();
}

class _PlayPaymentCardState extends State<PlayPaymentCard> {
  final service = PlayBillingService.instance;
  Map<String, dynamic>? intent;
  String? price, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await service.api({
        'action': 'request_status',
        'kind': widget.receipt['billing_kind'],
        'requestId': widget.receipt['id'],
      });
      final row = Map<String, dynamic>.from(data['intent'] as Map);
      final value = row['state'] == 'awaiting_payment'
          ? await service.price(row['product_id'].toString())
          : null;
      if (mounted)
        setState(() {
          intent = row;
          price = value;
          error = value == null && row['state'] == 'awaiting_payment'
              ? 'منتج Google Play غير متاح حاليًا.'
              : null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'تعذر تحميل الدفع. لا تُجرِ حوالة خارجية لهذا الطلب.',
        );
    }
  }

  Future<void> _buy() async {
    setState(() => busy = true);
    try {
      await service.buy(intent!);
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر فتح شاشة الشراء. أعد المحاولة لاحقًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = intent == null
        ? null
        : service.state(intent!['intent_binding'].toString()) ??
            intent!['state'];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الدفع عبر Google Play',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'لا تتجدد المدة تلقائيًا. يبدأ التوثيق أو الترويج تلقائيًا بعد تأكيد الدفع من Google Play. إذا تعذر تفعيل الطلب المدفوع، تتم معالجة استرداده عبر Google Play.',
          ),
          if (error != null) Text(error!),
          if (service.error != null) Text(service.error!),
          if (state == 'awaiting_payment' && price != null)
            FilledButton(
              onPressed: busy ? null : _buy,
              child: Text('شراء — $price'),
            ),
          if (state != null && state != 'awaiting_payment')
            Text(
              state == 'pending'
                  ? 'الدفع معلّق؛ لم تُفعّل الميزة بعد.'
                  : state == 'refund_required'
                      ? 'طلب استرداد المبلغ قيد المعالجة.'
                      : state == 'refunded'
                          ? 'تم استرداد المبلغ.'
                          : state == 'approved'
                              ? 'تم التفعيل.'
                              : state == 'cancelled'
                                  ? 'أُلغي الطلب؛ لا تُجرِ عملية شراء جديدة لهذا الطلب.'
                                  : state == 'revoked'
                                      ? 'أُلغي استحقاق هذا الشراء.'
                                      : 'تم تسجيل الدفع؛ جارٍ تأكيد التفعيل. لا تدفع مرة ثانية.',
            ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    await service.recover();
                    await _load();
                  },
            child: const Text('تحديث المشتريات وحالة الطلب'),
          ),
        ],
      ),
    );
  }
}
