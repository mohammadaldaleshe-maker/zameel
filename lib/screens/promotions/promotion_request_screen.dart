import '../../services/play_billing_service.dart';
import '../../widgets/play_payment_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/feature_control.dart';
import 'promotion_locations.dart';

class PromotionRequestScreen extends StatefulWidget {
  final String postId;
  final bool arabic;
  const PromotionRequestScreen({
    super.key,
    required this.postId,
    required this.arabic,
  });
  @override
  State<PromotionRequestScreen> createState() => _PromotionRequestScreenState();
}

class _PromotionRequestScreenState extends State<PromotionRequestScreen> {
  final _notes = TextEditingController();
  final _min = TextEditingController(text: '18'),
      _max = TextEditingController(text: '100');
  final _form = GlobalKey<FormState>();
  final Set<String> _cities = {}, _universities = {};
  Map<String, dynamic>? _catalog, _receipt;
  String _audience = 'general', _gender = 'both';
  bool _countrywide = true, _busy = false;
  String? _error;
  int _days = 7;
  String t(String ar, String en) => widget.arabic ? ar : en;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client.rpc(
        'zameel_promotion_catalog',
      );
      if (data is! Map) throw StateError('catalog_unavailable');
      final previous = await Supabase.instance.client
          .from('zameel_post_promotions')
          .select(
            'id,status,days,payment_code,amount_fils,wallet_number,beneficiary,audience_type,countrywide,target_cities,target_universities,min_age,max_age,target_gender,ends_at,impressions,clicks',
          )
          .eq('post_id', widget.postId)
          .inFilter('status', ['pending', 'approved'])
          .order('created_at', ascending: false)
          .limit(1);
      if (mounted)
        setState(() {
          _catalog = Map<String, dynamic>.from(data);
          _error = null;
          if (previous.isNotEmpty &&
              (previous.first['status'] == 'pending' ||
                  DateTime.tryParse(previous.first['ends_at']?.toString() ?? '')
                          ?.isAfter(DateTime.now()) ==
                      true))
            _receipt = Map<String, dynamic>.from(previous.first);
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = t(
            'تعذر تحميل خيارات الترويج. حاول مجددًا.',
            'Unable to load promotion options.',
          ),
        );
    }
  }

  Future<void> _select(bool university) async {
    final entries = List<Map<String, dynamic>>.from(
      (_catalog![university ? 'universities' : 'cities'] as List).map(
        (v) => Map<String, dynamic>.from(v as Map),
      ),
    );
    final selected = {...(university ? _universities : _cities)};
    var query = '';
    var governorate = '';
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: t('بحث', 'Search'),
                    ),
                    onChanged: (v) => setLocal(() => query = v.trim()),
                  ),
                ),
                if (!university)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: governorate,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t('المحافظة', 'Governorate'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(t('جميع المحافظات', 'All governorates')),
                        ),
                        for (final name in promotionGovernorates)
                          DropdownMenuItem(
                            value: name,
                            child: Text(t('محافظة $name', name)),
                          ),
                      ],
                      onChanged: (value) =>
                          setLocal(() => governorate = value ?? ''),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in entries.where((v) {
                        final name = v['name']?.toString() ?? '';
                        final region = university
                            ? v['city']?.toString() ?? ''
                            : promotionGovernorateName(v['governorate']);
                        final search = promotionLocationSearch(query);
                        return (university ||
                                governorate.isEmpty ||
                                region == governorate) &&
                            (promotionLocationSearch(name).contains(search) ||
                                promotionLocationSearch(region)
                                    .contains(search));
                      }))
                        CheckboxListTile(
                          value: selected.contains(entry['name']),
                          title: Text(
                            university
                                ? entry['name'].toString()
                                : promotionCityLabel(
                                    entry,
                                    arabic: widget.arabic,
                                  ),
                          ),
                          subtitle: university
                              ? Text(entry['city']?.toString() ?? '')
                              : null,
                          onChanged: (v) => setLocal(() {
                            if (v == true)
                              selected.add(entry['name'].toString());
                            else
                              selected.remove(entry['name']);
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: Text(
                      '${t('تأكيد الاختيار', 'Confirm')} (${selected.length})',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted)
      setState(() {
        final target = university ? _universities : _cities;
        target.clear();
        target.addAll(result);
      });
  }

  String _citySummary(Iterable<String> names) {
    final catalog = (_catalog?['cities'] as List?) ?? const [];
    final cities = {
      for (final value in catalog)
        if (value is Map)
          value['name']?.toString(): Map<String, dynamic>.from(value),
    };
    return names
        .map(
          (name) => cities[name] == null
              ? name
              : promotionCityLabel(cities[name]!, arabic: widget.arabic),
        )
        .join('، ');
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if ((_audience == 'students' && _universities.isEmpty) ||
        (_audience == 'general' && !_countrywide && _cities.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'اختر جامعة أو مدينة للاستهداف.',
              'Select the target universities or cities.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final params = <String, dynamic>{
        'p_post': widget.postId,
        'p_days': _days,
        'p_audience': _audience,
        'p_countrywide': _audience == 'general' && _countrywide,
        'p_cities': _audience == 'general' && !_countrywide
            ? _cities.toList()
            : <String>[],
        'p_universities':
            _audience == 'students' ? _universities.toList() : <String>[],
        'p_min_age': _parseAge(_min.text)!,
        'p_max_age': _parseAge(_max.text)!,
        'p_gender': _gender,
        'p_notes': _notes.text.trim(),
      };
      final result = PlayBillingService.enabled
          ? (await PlayBillingService.instance.api({
              'action': 'create',
              'kind': 'promotion',
              'params': params,
            }))['request']
          : await Supabase.instance.client.rpc(
              'zameel_request_promotion_v2',
              params: params,
            );
      if (mounted)
        setState(() => _receipt = Map<String, dynamic>.from(result as Map));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FeatureControl.errorMessage(
                e,
                t(
                  'تعذر إنشاء طلب الترويج',
                  'Unable to create promotion request',
                ),
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int? _parseAge(String? value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    final normalized = (value ?? '').split('').map((c) {
      final a = arabicDigits.indexOf(c), p = persianDigits.indexOf(c);
      return a >= 0
          ? '$a'
          : p >= 0
              ? '$p'
              : c;
    }).join();
    return int.tryParse(normalized);
  }

  String? _age(String? value, bool maximum) {
    final age = _parseAge(value);
    if (age == null ||
        age < 18 ||
        age > 100 ||
        (maximum && age < (_parseAge(_min.text) ?? 18)))
      return t(
        'أدخل عمرًا صحيحًا من 18 إلى 100',
        'Enter a valid age from 18 to 100',
      );
    return null;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(title: Text(t('ترويج المنشور', 'Promote post'))),
          body: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: Text(t('إعادة المحاولة', 'Retry')),
                      ),
                    ],
                  ),
                )
              : _catalog == null
                  ? const Center(child: CircularProgressIndicator())
                  : _receipt != null
                      ? _payment()
                      : Form(
                          key: _form,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                t(
                                  PlayBillingService.enabled
                                      ? 'يبدأ الترويج تلقائيًا بعد تأكيد الدفع عبر Google Play.'
                                      : 'يبدأ الترويج بعد مطابقة حوالتك والكود واعتماد الإدارة.',
                                  PlayBillingService.enabled
                                      ? 'Promotion starts automatically after Google Play confirms payment.'
                                      : 'Promotion begins after your transfer and reference are verified.',
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _audience,
                                decoration: InputDecoration(
                                  labelText: t('الجمهور المستهدف', 'Audience'),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'general',
                                    child: Text(t('الجميع', 'General public')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'students',
                                    child: Text(t('طلبة الجامعات',
                                        'University students')),
                                  ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() {
                                          _audience = v!;
                                        }),
                              ),
                              const SizedBox(height: 12),
                              if (_audience == 'general') ...[
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _countrywide,
                                  title: Text(
                                    t('المملكة الأردنية الهاشمية ككل',
                                        'All of Jordan'),
                                  ),
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(() => _countrywide = v),
                                ),
                                if (!_countrywide)
                                  OutlinedButton(
                                    onPressed:
                                        _busy ? null : () => _select(false),
                                    child: Text(
                                      _cities.isEmpty
                                          ? t('اختيار مدينة أو عدة مدن',
                                              'Choose cities')
                                          : _citySummary(_cities),
                                    ),
                                  ),
                              ] else
                                OutlinedButton(
                                  onPressed: _busy ? null : () => _select(true),
                                  child: Text(
                                    _universities.isEmpty
                                        ? t(
                                            'اختيار جامعة أو عدة جامعات',
                                            'Choose universities',
                                          )
                                        : _universities.join('، '),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _min,
                                      enabled: !_busy,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9٠-٩۰-۹]'),
                                        ),
                                      ],
                                      validator: (v) => _age(v, false),
                                      decoration: InputDecoration(
                                        labelText: t('العمر من (18+)',
                                            'Minimum age (18+)'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _max,
                                      enabled: !_busy,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9٠-٩۰-۹]'),
                                        ),
                                      ],
                                      validator: (v) => _age(v, true),
                                      decoration: InputDecoration(
                                        labelText:
                                            t('العمر إلى', 'Maximum age'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _gender,
                                decoration: InputDecoration(
                                  labelText:
                                      t('الجنس المستهدف', 'Target gender'),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'both',
                                    child: Text(t('كلاهما', 'Both')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'male',
                                    child: Text(t('ذكور', 'Male')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'female',
                                    child: Text(t('إناث', 'Female')),
                                  ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _gender = v!),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: _days,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('عدد أيام الترويج', 'Duration'),
                                ),
                                items: [
                                  for (var d = 1; d <= 30; d++)
                                    DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        PlayBillingService.enabled
                                            ? '$d ${t('يوم', 'day(s)')}'
                                            : '$d ${t('يوم', 'day(s)')} — ${(d * .5).toStringAsFixed(2)} ${t('دينار أردني', 'JOD')}',
                                      ),
                                    ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _days = v!),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                PlayBillingService.enabled
                                    ? t(
                                        'السعر النهائي يظهر من Google Play قبل الشراء',
                                        'Google Play shows the final price before purchase',
                                      )
                                    : '${t('الإجمالي', 'Total')}: ${(_days * .5).toStringAsFixed(2)} ${t('دينار أردني', 'JOD')}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notes,
                                enabled: !_busy,
                                maxLength: 1000,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: t(
                                    'ملاحظات للإدارة (اختياري)',
                                    'Notes (optional)',
                                  ),
                                ),
                              ),
                              if (!PlayBillingService.enabled &&
                                  _catalog!['wallet_ready'] != true)
                                Text(
                                  t(
                                    'الدفع غير متاح حاليًا؛ تنتظر الخدمة إعداد المحفظة من الإدارة.',
                                    'Payment is unavailable until the wallet is configured.',
                                  ),
                                ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _busy ||
                                        (!PlayBillingService.enabled &&
                                            _catalog!['wallet_ready'] != true)
                                    ? null
                                    : _send,
                                child: Text(
                                  t(
                                    _busy
                                        ? 'جارٍ إنشاء الطلب…'
                                        : 'إنشاء الطلب وعرض تعليمات الدفع',
                                    _busy
                                        ? 'Creating…'
                                        : 'Create request and show payment',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      );
  Widget _payment() {
    final r = _receipt!;
    if (!PlayBillingService.enabled &&
        r['status'] == 'pending' &&
        r['wallet_number'] == 'Google Play')
      return Center(
        child: Text(
          t(
            'هذا الطلب مرتبط بمتجر Google Play؛ حدّث حالته من نسخة المتجر.',
            'Manage this Google Play request using the Play Store version.',
          ),
        ),
      );
    if (PlayBillingService.enabled && r['status'] == 'pending')
      return ListView(
        children: [
          PlayPaymentCard(receipt: {...r, 'billing_kind': 'promotion'}),
          Text(
            '${t('مرات الظهور', 'Impressions')}: ${r['impressions'] ?? 0} — ${t('النقرات', 'Clicks')}: ${r['clicks'] ?? 0}',
          ),
          Text(
            t(
              'الترويج مقابل المدة، ولا يضمن عددًا محددًا من المشاهدات.',
              'Promotion pays for duration; a specific number of views is not guaranteed.',
            ),
          ),
        ],
      );
    if (r['status'] != 'pending' || r['payment_code'] == null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            r['status'] == 'approved'
                ? t(
                    'الترويج معتمد بالفعل. لا ترسل حوالة ثانية.',
                    'Promotion is already approved. Do not pay again.',
                  )
                : t(
                    'يوجد طلب قديم بانتظار مراجعة الإدارة.',
                    'An earlier request is awaiting review.',
                  ),
          ),
        ),
      );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t(
            'الطلب بانتظار الحوالة ومراجعة الإدارة',
            'Awaiting transfer and administrative review',
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        SelectableText(
          '${t('المحفظة', 'Wallet')}: ${r['wallet_number']}\n${t('اسم المستفيد', 'Beneficiary')}: ${r['beneficiary']}\n${t('المبلغ', 'Amount')}: ${((r['amount_fils'] as num) / 1000).toStringAsFixed(2)} ${t('دينار أردني', 'JOD')}',
        ),
        const SizedBox(height: 16),
        SelectableText(
          r['payment_code'].toString(),
          style: Theme.of(context).textTheme.headlineMedium,
          textDirection: TextDirection.ltr,
        ),
        TextButton.icon(
          onPressed: () => Clipboard.setData(
            ClipboardData(text: r['payment_code'].toString()),
          ),
          icon: const Icon(Icons.copy),
          label: Text(t('نسخ كود الدفع', 'Copy payment code')),
        ),
        Text(
          t(
            'أرفق هذا الكود في ملاحظات الحوالة. لا يبدأ الإعلان قبل مطابقة الكود والمبلغ في المحفظة واعتماد الإدارة. لا ترسل حوالة ثانية عند فتح الطلب مجددًا.',
            'Include this reference in transfer notes. Promotion begins only after manual verification and approval. Do not pay twice when reopening the request.',
          ),
        ),
        const SizedBox(height: 16),
        Text('${t('المدة', 'Duration')}: ${r['days']} ${t('يوم', 'days')}'),
        Text(
          '${t('الجمهور', 'Audience')}: ${r['audience_type'] == 'students' ? (r['target_universities'] as List).join('، ') : r['countrywide'] == true ? t('الأردن ككل', 'All Jordan') : _citySummary((r['target_cities'] as List).map((v) => v.toString()))}',
        ),
        Text('${t('العمر', 'Age')}: ${r['min_age']}–${r['max_age']}'),
        Text(
          '${t('الجنس', 'Gender')}: ${({
            'both': t('كلاهما', 'Both'),
            'male': t('ذكور', 'Male'),
            'female': t('إناث', 'Female')
          })[r['target_gender']]}',
        ),
      ],
    );
  }
}
