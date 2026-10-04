import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

class TrustGameScreen extends StatefulWidget {
  const TrustGameScreen({super.key, required this.isArabic});
  final bool isArabic;
  @override
  State<TrustGameScreen> createState() => _TrustGameScreenState();
}

class _TrustGameScreenState extends State<TrustGameScreen>
    with WidgetsBindingObserver {
  final _db = Supabase.instance.client;
  final _message = TextEditingController();
  final _chatScroll = ScrollController();
  Timer? _poll;
  Timer? _clock;
  Map<String, dynamic> _state = {};
  String? _match;
  String? _error;
  String? _pendingMessageId;
  bool _busy = false;
  bool _visible = true;
  bool _canPop = false;
  Duration _serverOffset = Duration.zero;
  String _t(String ar, String en) => widget.isArabic ? ar : en;
  String get _phase => '${_state['phase'] ?? 'lobby'}';
  bool get _playing => _phase == 'questions' || _phase == 'decision';
  String _coins(dynamic x) {
    final n = x is num ? x.toDouble() : double.tryParse('$x') ?? 0;
    return n == n.truncateToDouble()
        ? n.toInt().toString()
        : n.toStringAsFixed(1);
  }

  int get _seconds {
    final until = DateTime.tryParse('${_state['deadline']}');
    if (until == null) return 0;
    return max(
      0,
      until.difference(DateTime.now().add(_serverOffset)).inSeconds,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_visible) _refresh();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _playing) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _clock?.cancel();
    _message.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  String _friendly(Object e) {
    final text = e is PostgrestException ? e.message : e.toString();
    if (text.contains('insufficient_coins'))
      return _t(
        'رصيدك لا يكفي لحجز عملات المباراة.',
        'Your balance is too low for the match stake.',
      );
    if (text.contains('chat_rate_limit'))
      return _t(
        'انتظر قليلًا قبل إرسال رسالة أخرى.',
        'Wait briefly before sending another message.',
      );
    if (text.contains('trust_temporarily_unavailable'))
      return _t('اللعبة معلقة حاليًا.', 'The game is currently suspended.');
    if (text.contains('ten_published_questions_required'))
      return _t(
        'بنك الأسئلة غير جاهز للمباراة.',
        'The question bank is not ready.',
      );
    if (text.contains('trust_account_unavailable'))
      return _t(
        'حسابك غير متاح للعب حاليًا.',
        'Your account is currently unavailable for play.',
      );
    return _t(
      'تعذر الاتصال. أعد المحاولة؛ لديك 90 ثانية للعودة إلى المباراة.',
      'Connection failed. Retry; your reconnection grace period is 90 seconds.',
    );
  }

  Future<void> _run(String rpc, {Map<String, dynamic>? params}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final raw = await _db
          .rpc(rpc, params: params)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final next = Map<String, dynamic>.from(raw as Map);
      final serverNow = DateTime.tryParse('${next['server_now']}');
      if (serverNow != null)
        _serverOffset = serverNow.difference(DateTime.now());
      setState(() {
        _state = next;
        _match = next['match_id']?.toString();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() =>
      _run('zameel_trust_state', params: {'p_match': _match});

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> _send() async {
    if (_busy || _message.text.trim().isEmpty || !_playing) return;
    _pendingMessageId ??= _uuid();
    await _run(
      'zameel_trust_chat',
      params: {
        'p_match': _match,
        'p_body': _message.text.trim(),
        'p_client_id': _pendingMessageId,
      },
    );
    if (!mounted) return;
    if (_error == null) {
      _message.clear();
      _pendingMessageId = null;
    }
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (_playing) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(_t('الانسحاب من المباراة؟', 'Leave the match?')),
          content: Text(
            _t(
              'ستخسر ${_coins(_state['stake'])} عملة محجوزة، ويسترد الطرف الآخر عملاته.',
              'You will lose ${_coins(_state['stake'])} reserved coins; your partner receives their stake back.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(_t('متابعة اللعب', 'Keep playing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(_t('انسحاب', 'Leave')),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    if (_playing || _phase == 'waiting') {
      await _run('zameel_trust_leave', params: {'p_match': _match});
      if (_error != null || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _decision(String choice) async {
    if (_busy || _state['own_choice'] != null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t('تأكيد القرار السري', 'Confirm your secret decision')),
        content: Text(
          choice == 'trust'
              ? _t(
                  'اخترت الثقة. لا يمكن تغيير القرار بعد تأكيده.',
                  'You chose trust. Your decision cannot be changed after confirmation.',
                )
              : _t(
                  'اخترت الغدر. لا يمكن تغيير القرار بعد تأكيده.',
                  'You chose betrayal. Your decision cannot be changed after confirmation.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(_t('رجوع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(_t('تأكيد', 'Confirm')),
          ),
        ],
      ),
    );
    if (yes == true && mounted)
      await _run(
        'zameel_trust_decide',
        params: {'p_match': _match, 'p_choice': choice},
      );
  }

  Future<void> _report() async {
    if (_match == null) return;
    final input = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t('الإبلاغ عن المباراة', 'Report match')),
        content: TextField(controller: input, maxLength: 1000, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(_t('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              if (input.text.trim().length >= 5)
                Navigator.pop(c, input.text.trim());
            },
            child: Text(_t('إرسال', 'Send')),
          ),
        ],
      ),
    );
    input.dispose();
    if (reason == null) return;
    try {
      await _db.rpc(
        'zameel_trust_report',
        params: {'p_match': _match, 'p_reason': reason},
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('تم إرسال البلاغ', 'Report submitted'))),
        );
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    }
  }

  Future<void> _history() async {
    try {
      final raw = await _db.rpc('zameel_coin_history');
      final rows = (raw as List).whereType<Map>().toList();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(_t('سجل عملات زميل', 'Zameel coin history')),
                ),
                Expanded(
                  child: ListView(
                    children: rows
                        .map(
                          (r) => ListTile(
                            title: Text(_reason('${r['reason']}')),
                            subtitle: Text('${r['created_at']}'),
                            trailing: Text('${_coins(r['delta'])} 🪙'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    }
  }

  String _reason(String code) => switch (code) {
        'initial_grant' => _t('الرصيد الابتدائي', 'Initial balance'),
        'match_stake' => _t('حجز عملات المباراة', 'Match stake reserved'),
        'result' => _t('تسوية نتيجة المباراة', 'Match result settlement'),
        'abandoned' => _t(
            'انسحاب أو انتهاء مهلة العودة/القرار',
            'Withdrawal or reconnection/decision timeout',
          ),
        'server_outage' => _t(
            'إعادة العملات بسبب عطل الخادم',
            'Server outage refund',
          ),
        'both_disconnected' => _t(
            'إلغاء وإعادة العملات للطرفين',
            'Both participants refunded',
          ),
        'admin_refund' =>
          _t('إلغاء إداري وإعادة العملات', 'Administrative refund'),
        'account_deleted' => _t(
            'إلغاء بسبب حذف حساب',
            'Account deletion cancellation',
          ),
        _ => code,
      };

  Widget _coin() => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.amber.shade300,
          border: Border.all(color: Colors.amber.shade800, width: 3),
        ),
        padding: const EdgeInsets.all(7),
        child: Image.asset('assets/branding/zameel_mark.png'),
      );

  Widget _chat() {
    final rows = (_state['messages'] as List? ?? []).whereType<Map>().toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              _t(
                'دردشة المباراة — هويتكما مخفية',
                'Match chat — identities hidden',
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView(
                controller: _chatScroll,
                reverse: true,
                children: rows.reversed
                    .map(
                      (r) => Align(
                        alignment: r['own'] == true
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.centerEnd,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: r['own'] == true
                                ? AppTheme.primary.withAlpha(25)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${r['own'] == true ? _t('أنت', 'You') : _t('الزميل', 'Partner')}: ${r['body']}',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    maxLength: 500,
                    onChanged: (_) {
                      if (_pendingMessageId != null) _pendingMessageId = null;
                    },
                    decoration: InputDecoration(
                      hintText: _t(
                        'ناقشا الإجابة هنا',
                        'Discuss the answer here',
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _state['question'] is Map
        ? _state['question'] as Map
        : <String, dynamic>{};
    final options =
        (question[widget.isArabic ? 'options_ar' : 'options_en'] as List?) ??
            [];
    final stake = _coins(_state['stake'] ?? 50);
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_t('ثقة أم غدر؟', 'Trust or Betray?')),
            leading: IconButton(
              onPressed: _exit,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(onPressed: _history, icon: const Icon(Icons.history)),
              if (_match != null)
                IconButton(
                  onPressed: _report,
                  icon: const Icon(Icons.flag_outlined),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _coin(),
                    const SizedBox(width: 12),
                    Text(
                      _t(
                        'رصيدك: ${_coins(_state['balance'])}',
                        'Balance: ${_coins(_state['balance'])}',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_phase == 'lobby' || _phase == 'waiting') ...[
                  Text(
                    _t(
                      'تعاون في عشرة أسئلة… ثم اختر الثقة أو الغدر.',
                      'Cooperate on ten questions… then choose trust or betrayal.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      '90 ثانية لكل سؤال. تُحجز $stake عملة من كل لاعب عند بدء المباراة. إجابة مشتركة صحيحة تربح قيمة السؤال.',
                      '90 seconds per question. Each player reserves $stake coins when the match starts. A shared correct answer earns the question value.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'ثقة + ثقة: استرداد الحجز وتقاسم المكافأة.\nغدر + ثقة: الغادر يأخذ المكافأة وحجز الطرف الآخر.\nغدر + غدر: خسارة الحجزين والمكافأة.\nالانسحاب أو عدم العودة خلال 90 ثانية: خسارة حجزك.\nعملات زميل افتراضية داخل التطبيق.',
                      'Trust + trust: stakes returned and reward shared.\nBetray + trust: betrayer takes the reward and the other stake.\nBetray + betray: both lose stakes and reward.\nLeaving or not returning within 90 seconds forfeits your stake.\nZameel coins are virtual in-app coins.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_phase == 'waiting') ...[
                    const Center(child: CircularProgressIndicator()),
                    Text(
                      _t(
                        'نبحث عن لاعب عشوائي… لم تُحجز عملاتك بعد.',
                        'Finding a random partner… your coins are not reserved yet.',
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _run('zameel_trust_leave'),
                      child: Text(_t('إلغاء البحث', 'Cancel search')),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _busy ? null : () => _run('zameel_trust_join'),
                      child: Text(_t('ابدأ المباراة', 'Find a match')),
                    ),
                ],
                if (_playing) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          _t(
                            'المكافأة: ${_state['prize']}',
                            'Reward: ${_state['prize']}',
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          _t(
                            'الوقت: $_seconds ثانية',
                            'Time: $_seconds seconds',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_state['last_round'] is Map)
                    Text(
                      _state['last_round']['won'] == true
                          ? _t(
                              'الإجابة السابقة صحيحة ✓',
                              'Previous answer correct ✓',
                            )
                          : _t(
                              'السؤال السابق دون مكافأة',
                              'Previous question earned no reward',
                            ),
                    ),
                ],
                if (_phase == 'questions') ...[
                  Text(
                    _t(
                      'السؤال ${_state['round_no']} من 10 — قيمته ${(_state['round_no'] as num? ?? 1) * (_state['reward_unit'] as num? ?? 10)} عملة',
                      'Question ${_state['round_no']} of 10',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${question[widget.isArabic ? 'question_ar' : 'question_en'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  for (int i = 0; i < options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: _busy || _seconds == 0
                            ? null
                            : () => _run(
                                  'zameel_trust_answer',
                                  params: {
                                    'p_match': _match,
                                    'p_round': _state['round_no'],
                                    'p_selected': i,
                                  },
                                ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: question['own_selected'] == i
                              ? AppTheme.primary.withAlpha(35)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text('${options[i]}')),
                            if (question['own_selected'] == i)
                              const Icon(Icons.check),
                            if (question['opponent_selected'] == i)
                              const Icon(Icons.people_outline),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    _t(
                      'اختيارك ✓ — اختيار الزميل ♧. تُثبّت الإجابة عند اختياركما الخيار نفسه، ويمكن تغييرها قبل الاتفاق.',
                      'Your choice ✓ — partner choice ♧. The answer locks when both choose the same option; you can change it before agreement.',
                    ),
                  ),
                ],
                if (_phase == 'decision') ...[
                  Text(
                    _t('لحظة القرار…', 'Time to decide…'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_state['own_choice'] == null)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _decision('trust'),
                            child: Text(_t('ثقة 🤝', 'Trust 🤝')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _decision('betray'),
                            child: Text(_t('غدر 🗡️', 'Betray 🗡️')),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _t(
                        'تم تثبيت قرارك السري. ننتظر قرار الزميل.',
                        'Your secret decision is locked. Waiting for your partner.',
                      ),
                    ),
                ],
                if (_playing) ...[const SizedBox(height: 18), _chat()],
                if ([
                  'finished',
                  'cancelled',
                  'abandoned',
                ].contains(_phase)) ...[
                  Text(
                    _t('انتهت المباراة', 'Match ended'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _reason('${_state['reason']}'),
                    textAlign: TextAlign.center,
                  ),
                  if (_phase == 'finished') ...[
                    Text(
                      _t(
                        'قرارك: ${_state['own_choice'] == 'trust' ? 'ثقة' : 'غدر'}',
                        'Your choice: ${_state['own_choice']}',
                      ),
                    ),
                    Text(
                      _t(
                        'قرار الزميل: ${_state['opponent_choice'] == 'trust' ? 'ثقة' : 'غدر'}',
                        'Partner choice: ${_state['opponent_choice']}',
                      ),
                    ),
                  ],
                  Text(
                    _t(
                      'أُضيف إلى رصيدك: ${_coins(_state['own_payout'])} عملة. الصافي بعد الحجز: ${_coins((_state['own_payout'] as num? ?? 0) - (_state['stake'] as num? ?? 50))}.',
                      'Credited: ${_coins(_state['own_payout'])} coins. Net after stake: ${_coins((_state['own_payout'] as num? ?? 0) - (_state['stake'] as num? ?? 50))}.',
                    ),
                  ),
                  if (_state['opponent'] is Map)
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('${_state['opponent']['name'] ?? ''}'),
                      subtitle: Text(
                        _t('زميلك في المباراة', 'Your match partner'),
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            _match = null;
                            _run('zameel_trust_join');
                          },
                    child: Text(_t('مباراة جديدة', 'New match')),
                  ),
                ],
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: _busy ? null : _refresh,
                    child: Text(_t('إعادة المحاولة', 'Retry')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
