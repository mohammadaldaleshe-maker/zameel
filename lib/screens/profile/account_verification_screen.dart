import '../../services/play_billing_service.dart';
import '../../widgets/play_payment_card.dart';
import '../../widgets/verified_name.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});
  @override
  State<AccountVerificationScreen> createState() =>
      _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen> {
  bool _loading = true, _busy = false;
  String? _error, _expires;
  Map<String, dynamic>? _request;
  final db = Supabase.instance.client;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = db.auth.currentUser?.id;
      if (uid == null) throw Exception('session');
      final result = await Future.wait<dynamic>([
        db
            .from('users')
            .select('verification_expires_at')
            .eq('id', uid)
            .single(),
        db
            .from('zameel_verification_requests')
            .select('*')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(1),
      ]);
      if (!mounted) return;
      VerificationDirectory.instance.updateOwn(
        uid,
        result[0]['verification_expires_at']?.toString(),
      );
      setState(() {
        _expires = result[0]['verification_expires_at']?.toString();
        final rows = result[1] as List;
        _request = rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل طلب التوثيق');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestVerification() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final row = PlayBillingService.enabled
          ? (await PlayBillingService.instance.api({
              'action': 'create',
              'kind': 'verification',
            }))['request']
          : await db.rpc('zameel_request_verification');
      if (mounted) setState(() => _request = Map<String, dynamic>.from(row));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('wallet_unavailable')
                  ? 'المحفظة غير متاحة حاليًا. حاول لاحقًا.'
                  : 'تعذر إنشاء طلب التوثيق',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<LanguageProvider>().isArabic;
    final r = _request;
    final expiry = DateTime.tryParse(_expires ?? '');
    final active = expiry?.isAfter(DateTime.now()) ?? false;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ar ? 'توثيق الحساب' : 'Account verification'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF1877F2),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      PlayBillingService.enabled
                          ? (ar
                              ? 'توثيق لمدة شهر — السعر من Google Play'
                              : 'One month — Google Play price')
                          : (ar
                              ? 'دينار أردني واحد شهريًا'
                              : 'JOD 1 per month'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      PlayBillingService.enabled
                          ? 'الشراء عبر Google Play دون تجديد تلقائي. يبدأ الشهر بعد إثبات الدفع وموافقة الإدارة.'
                          : ar
                              ? 'يبدأ الشهر بعد مطابقة الحوالة والموافقة. التجديد بطلب دفع جديد، دون خصم تلقائي. العلامة تدل على اشتراك توثيق مدفوع.'
                              : 'One month starts after payment review and approval. Renew with a new payment request; no automatic charge. The badge indicates a paid verification subscription.',
                    ),
                    if (active)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '${ar ? 'موثق حتى' : 'Verified until'} ${MaterialLocalizations.of(context).formatFullDate(expiry!.toLocal())}',
                        ),
                      ),
                    if (_error != null) Text(_error!),
                    if (r != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        '${ar ? 'حالة الطلب' : 'Request status'}: ${{
                              'pending': ar ? 'بانتظار المراجعة' : 'Pending',
                              'approved': ar ? 'تمت الموافقة' : 'Approved',
                              'rejected': ar ? 'مرفوض' : 'Rejected'
                            }[r['status']] ?? r['status']}',
                      ),
                      if (r['status'] == 'pending' &&
                          PlayBillingService.enabled)
                        PlayPaymentCard(
                          receipt: {...r, 'billing_kind': 'verification'},
                        ),
                      if (r['status'] == 'pending' &&
                          !PlayBillingService.enabled &&
                          r['payment_source'] != 'google_play') ...[
                        SelectableText(
                          '${ar ? 'المحفظة' : 'Wallet'}: ${r['wallet_number']}',
                        ),
                        Text(
                          '${ar ? 'المستفيد' : 'Beneficiary'}: ${r['beneficiary']}',
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          '${ar ? 'كود الدفع' : 'Payment code'}: ${r['payment_code']}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ar
                              ? 'حوّل دينارًا واحدًا وأرفق الكود في ملاحظات الحوالة، ثم انتظر مراجعة الإدارة.'
                              : 'Transfer JOD 1 and include this code in the payment notes, then wait for review.',
                        ),
                      ],
                    ],
                    if (!PlayBillingService.enabled &&
                        r?['status'] == 'pending' &&
                        r?['payment_source'] == 'google_play')
                      Text(ar
                          ? 'هذا الطلب مرتبط بمتجر Google Play؛ حدّث حالته من نسخة المتجر.'
                          : 'Manage this Google Play request using the Play Store version.'),
                    const SizedBox(height: 20),
                    if (r?['status'] != 'pending')
                      FilledButton(
                        onPressed: _busy ? null : _requestVerification,
                        child: Text(
                          ar
                              ? (active
                                  ? 'طلب تجديد لشهر إضافي'
                                  : PlayBillingService.enabled
                                      ? 'طلب التوثيق'
                                      : 'طلب التوثيق — 1 دينار')
                              : (active
                                  ? 'Renew for one more month'
                                  : PlayBillingService.enabled
                                      ? 'Request verification'
                                      : 'Request verification — JOD 1'),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
