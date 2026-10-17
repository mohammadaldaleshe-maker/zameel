import 'package:zameel/widgets/verified_name.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../games/game_kit.dart';
import '../games/game_widgets.dart';

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

  static const Color _betrayColor = Color(0xFFFF5C8A);

  Widget _coin({double size = 46}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFE08A), Color(0xFFFFB300)],
          ),
          border: Border.all(color: Colors.amber.shade800, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(color: kGameGold.withOpacity(0.45), blurRadius: 14),
          ],
        ),
        padding: EdgeInsets.all(size * 0.15),
        child: Image.asset('assets/branding/zameel_mark.png'),
      );

  Widget _balanceBar() {
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _coin(size: 40),
          const SizedBox(width: 12),
          Text(
            _t('رصيدك', 'Balance'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _coins(_state['balance']),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: kGameGold,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(String emoji, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.22),
              border: Border.all(color: color.withOpacity(0.7)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    Widget face(String emoji, Color color) => Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[color, color.withOpacity(0.55)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 18),
            ],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 34)),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        face('🤝', kGameTeal),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'VS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        face('🗡️', _betrayColor),
      ],
    );
  }

  Widget _lobby(String stake) {
    return Column(
      children: [
        _hero(),
        const SizedBox(height: 14),
        Text(
          _t(
            'تعاون في عشرة أسئلة… ثم اختر الثقة أو الغدر.',
            'Cooperate on ten questions… then choose trust or betrayal.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        GamePanel(
          child: Column(
            children: [
              _ruleRow(
                '⏱️',
                kGameGold,
                _t(
                  '90 ثانية لكل سؤال. تُحجز $stake عملة من كل لاعب عند بدء المباراة. إجابة مشتركة صحيحة تربح قيمة السؤال.',
                  '90 seconds per question. Each player reserves $stake coins when the match starts. A shared correct answer earns the question value.',
                ),
              ),
              _ruleRow(
                '🤝',
                kGameTeal,
                _t(
                  'ثقة + ثقة: استرداد الحجز وتقاسم المكافأة.',
                  'Trust + trust: stakes returned and reward shared.',
                ),
              ),
              _ruleRow(
                '🗡️',
                _betrayColor,
                _t(
                  'غدر + ثقة: الغادر يأخذ المكافأة وحجز الطرف الآخر.',
                  'Betray + trust: betrayer takes the reward and the other stake.',
                ),
              ),
              _ruleRow(
                '💥',
                const Color(0xFFB583FF),
                _t(
                  'غدر + غدر: خسارة الحجزين والمكافأة.',
                  'Betray + betray: both lose stakes and reward.',
                ),
              ),
              _ruleRow(
                '🚪',
                Colors.white70,
                _t(
                  'الانسحاب أو عدم العودة خلال 90 ثانية: خسارة حجزك.',
                  'Leaving or not returning within 90 seconds forfeits your stake.',
                ),
              ),
              _ruleRow(
                '🪙',
                kGameGold,
                _t(
                  'عملات زميل افتراضية داخل التطبيق.',
                  'Zameel coins are virtual in-app coins.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_phase == 'waiting') ...[
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              color: kGameTeal,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'نبحث عن لاعب عشوائي… لم تُحجز عملاتك بعد.',
              'Finding a random partner… your coins are not reserved yet.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 6),
          GameButton(
            primary: false,
            onPressed: _busy ? null : () => _run('zameel_trust_leave'),
            label: _t('إلغاء البحث', 'Cancel search'),
          ),
        ] else
          GameButton(
            onPressed: _busy ? null : () => _run('zameel_trust_join'),
            icon: Icons.sports_esports_rounded,
            label: _t('ابدأ المباراة', 'Find a match'),
          ),
      ],
    );
  }

  Widget _statusBar() {
    final low = _seconds <= 15;
    final round = (_state['round_no'] as num?)?.toInt() ?? 1;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GamePill(
              text: '🏆 ${_state['prize'] ?? 0}',
              subtitle: _t('المكافأة', 'Reward'),
            ),
            const SizedBox(width: 12),
            GamePill(
              text: '⏱️ $_seconds',
              active: !low,
              subtitle: _t('ثانية', 'seconds'),
            ),
          ],
        ),
        if (_phase == 'questions') ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 10; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == round ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: i < round
                        ? kGameTeal
                        : i == round
                            ? kGameGold
                            : Colors.white.withOpacity(0.25),
                  ),
                ),
            ],
          ),
        ],
        if (_state['last_round'] is Map) ...[
          const SizedBox(height: 8),
          GameBanner(
            size: 13.5,
            color: _state['last_round']['won'] == true
                ? kGameTeal
                : Colors.white70,
            text: _state['last_round']['won'] == true
                ? _t('الإجابة السابقة صحيحة ✓', 'Previous answer correct ✓')
                : _t('السؤال السابق دون مكافأة',
                    'Previous question earned no reward'),
          ),
        ],
      ],
    );
  }

  Widget _optionTile(Map question, List options, int i) {
    final mine = question['own_selected'] == i;
    final theirs = question['opponent_selected'] == i;
    final disabled = _busy || _seconds == 0;
    const letters = <String>['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
    const lettersEn = <String>['A', 'B', 'C', 'D', 'E', 'F'];
    final letter = (widget.isArabic ? letters : lettersEn)[i % 6];
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Opacity(
        opacity: disabled && !mine ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: disabled
                ? null
                : () {
                    gameTap();
                    _run(
                      'zameel_trust_answer',
                      params: {
                        'p_match': _match,
                        'p_round': _state['round_no'],
                        'p_selected': i,
                      },
                    );
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: mine
                    ? kGameTeal.withOpacity(0.28)
                    : Colors.white.withOpacity(0.10),
                border: Border.all(
                  color: mine ? kGameTeal : Colors.white.withOpacity(0.2),
                  width: mine ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mine ? kGameTeal : Colors.white.withOpacity(0.16),
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${options[i]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (mine)
                    const Icon(Icons.check_circle_rounded,
                        color: kGameTeal, size: 22),
                  if (theirs)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 6),
                      child: Icon(Icons.people_alt_rounded,
                          color: kGameGold, size: 22),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionPanel(Map question, List options) {
    final round = (_state['round_no'] as num?) ?? 1;
    final unit = (_state['reward_unit'] as num?) ?? 10;
    return Column(
      children: [
        GamePanel(
          child: Column(
            children: [
              Text(
                _t(
                  'السؤال $round من 10 — قيمته ${round * unit} عملة',
                  'Question $round of 10',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kGameGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${question[widget.isArabic ? 'question_ar' : 'question_en'] ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < options.length; i++) _optionTile(question, options, i),
        Text(
          _t(
            'اختيارك ✓ — اختيار الزميل 👥. تُثبّت الإجابة عند اختياركما الخيار نفسه، ويمكن تغييرها قبل الاتفاق.',
            'Your choice ✓ — partner choice 👥. The answer locks when both choose the same option; you can change it before agreement.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _decisionButton(String choice, String emoji, String label, Color color) {
    return Expanded(
      child: Opacity(
        opacity: _busy ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _busy ? null : () => _decision(choice),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[color, color.withOpacity(0.55)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 18),
                ],
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _decisionPanel() {
    return Column(
      children: [
        GameBanner(text: _t('لحظة القرار…', 'Time to decide…'), size: 24),
        const SizedBox(height: 4),
        Text(
          _t('قرارك سري ولا يمكن تغييره بعد التأكيد.',
              'Your decision is secret and final once confirmed.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.75)),
        ),
        const SizedBox(height: 16),
        if (_state['own_choice'] == null)
          Row(
            children: [
              _decisionButton(
                  'trust', '🤝', _t('ثقة', 'Trust'), const Color(0xFF1DB6A6)),
              const SizedBox(width: 14),
              _decisionButton(
                  'betray', '🗡️', _t('غدر', 'Betray'), _betrayColor),
            ],
          )
        else
          GamePanel(
            child: Column(
              children: [
                const Icon(Icons.lock_rounded, color: kGameGold, size: 34),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'تم تثبيت قرارك السري. ننتظر قرار الزميل.',
                    'Your secret decision is locked. Waiting for your partner.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      color: kGameTeal, strokeWidth: 3),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chat() {
    final rows = (_state['messages'] as List? ?? []).whereType<Map>().toList();
    return GamePanel(
      child: Column(
        children: [
          Text(
            _t(
              'دردشة المباراة — هويتكما مخفية',
              'Match chat — identities hidden',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: ListView(
              controller: _chatScroll,
              reverse: true,
              children: rows.reversed.map((r) {
                final own = r['own'] == true;
                return Align(
                  alignment: own
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: own
                          ? kGameTeal.withOpacity(0.32)
                          : Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${own ? _t('أنت', 'You') : _t('الزميل', 'Partner')}: ${r['body']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onEditingComplete: () {},
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: kGameTeal,
                  onChanged: (_) {
                    if (_pendingMessageId != null) _pendingMessageId = null;
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.10),
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.55)),
                    hintText: _t(
                      'ناقشا الإجابة هنا',
                      'Discuss the answer here',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _busy ? null : _send,
                style: IconButton.styleFrom(backgroundColor: kGameTeal),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finished() {
    final reason = '${_state['reason']}';
    final payout = (_state['own_payout'] as num?) ?? 0;
    final stakeN = (_state['stake'] as num?) ?? 50;
    final net = payout - stakeN;
    final won = _phase == 'finished' && net > 0;
    String choiceText(dynamic c) {
      if (widget.isArabic) return c == 'trust' ? 'ثقة 🤝' : 'غدر 🗡️';
      return '$c';
    }

    return Column(
      children: [
        GameResultCard(
          won: won,
          title: _t('انتهت المباراة', 'Match ended'),
          child: Column(
            children: [
              Text(
                _reason(reason),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              if (_phase == 'finished') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _choiceBox(
                        _t('قرارك', 'You'),
                        choiceText(_state['own_choice']),
                        kGameTeal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _choiceBox(
                        _t('قرار الزميل', 'Partner'),
                        choiceText(_state['opponent_choice']),
                        _betrayColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _t(
                  'أُضيف إلى رصيدك: ${_coins(payout)} عملة. الصافي بعد الحجز: ${_coins(net)}.',
                  'Credited: ${_coins(payout)} coins. Net after stake: ${_coins(net)}.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kGameGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (_state['opponent'] is Map) ...[
          const SizedBox(height: 12),
          GamePanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: kGameTeal,
                  child: Icon(Icons.person_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        child: VerifiedName(
                          userId: _state['opponent']['id']?.toString(),
                          child: Text('${_state['opponent']['name'] ?? ''}'),
                        ),
                      ),
                      Text(
                        _t('زميلك في المباراة', 'Your match partner'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        GameButton(
          onPressed: _busy
              ? null
              : () {
                  _match = null;
                  _run('zameel_trust_join');
                },
          icon: Icons.refresh_rounded,
          label: _t('مباراة جديدة', 'New match'),
        ),
      ],
    );
  }

  Widget _choiceBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
        child: GameScaffold(
          title: _t('ثقة أم غدر؟', 'Trust or Betray?'),
          actions: [
            IconButton(
              tooltip: _t('سجل العملات', 'Coin history'),
              onPressed: _history,
              icon: const Icon(Icons.history_rounded),
            ),
            if (_match != null)
              IconButton(
                tooltip: _t('إبلاغ', 'Report'),
                onPressed: _report,
                icon: const Icon(Icons.flag_outlined),
              ),
          ],
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              if (_state['is_bot'] == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GamePanel(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(Icons.smart_toy_rounded,
                            color: Color(0xFFB583FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'زميل — لاعب آلي',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'اختيارات اللاعب الآلي عشوائية',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _balanceBar(),
              const SizedBox(height: 14),
              if (_phase == 'lobby' || _phase == 'waiting') _lobby(stake),
              if (_playing) ...[
                _statusBar(),
                const SizedBox(height: 12),
              ],
              if (_phase == 'questions') _questionPanel(question, options),
              if (_phase == 'decision') _decisionPanel(),
              if (_playing) ...[const SizedBox(height: 16), _chat()],
              if (['finished', 'cancelled', 'abandoned'].contains(_phase))
                _finished(),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(
                    color: kGameTeal,
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF8A8A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Center(
                  child: GameButton(
                    primary: false,
                    onPressed: _busy ? null : _refresh,
                    label: _t('إعادة المحاولة', 'Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
