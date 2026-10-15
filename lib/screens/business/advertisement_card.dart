import '../../widgets/sponsored_exposure.dart';
import '../../widgets/keep_keyboard_send_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../services/advertising_service.dart';
import '../../services/feature_control.dart';
import '../../widgets/cached_media_image.dart';
import '../../widgets/video_player_widget.dart';
import 'partner_ads_screen.dart';

class AdvertisementCard extends StatelessWidget {
  const AdvertisementCard(
      {super.key,
      required this.ad,
      required this.isArabic,
      this.openOnTap = true,
      this.onHide});

  final Map<String, dynamic> ad;
  final bool isArabic;
  final bool openOnTap;
  final Future<void> Function()? onHide;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final partner = ad['business_partners'];
    final name = partner is Map ? partner['name']?.toString() ?? '' : '';
    final partnerId = ad['partner_id']?.toString() ?? '';
    return SponsoredExposure(
        postId: '${ad['id']}',
        partner: true,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: InkWell(
            onTap: openOnTap
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AdvertisementDetails(ad: ad, isArabic: isArabic),
                    ))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.campaign_outlined,
                          color: Color(0xFF08736D)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: partnerId.isEmpty
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => PartnerAdsScreen(
                                              partner: {
                                                if (partner is Map)
                                                  ...Map<String, dynamic>.from(
                                                      partner),
                                                'id': partnerId,
                                                'name': name
                                              },
                                              isArabic: isArabic,
                                            )),
                                  ),
                          child: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )),
                      Text(isArabic ? 'إعلان' : 'Ad',
                          style: const TextStyle(color: Color(0xFF08736D))),
                    ]),
                    const SizedBox(height: 9),
                    Text(ad['title']?.toString() ?? '',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(ad['body']?.toString() ?? '',
                        maxLines: openOnTap ? 8 : null,
                        overflow: openOnTap ? TextOverflow.ellipsis : null),
                    _AdMedia(media: ad['media'], preview: openOnTap),
                    const SizedBox(height: 8),
                    Text(
                        '${ad['likes_count'] ?? 0} ${isArabic ? 'إعجاب' : 'likes'}   ·   ${ad['comments_count'] ?? 0} ${isArabic ? 'تعليق' : 'comments'}',
                        style: TextStyle(color: AppTheme.adaptiveSecondary)),
                    if (onHide != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await onHide!();
                          } catch (error) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(FeatureControl.errorMessage(
                                        error, 'تعذر إخفاء الإعلان'))),
                              );
                          }
                        },
                        child: Text(isArabic
                            ? 'لا يهمني هذا الإعلان'
                            : 'Not interested'),
                      ),
                  ]),
            ),
          ),
        ));
  }
}

class _AdMedia extends StatefulWidget {
  const _AdMedia({required this.media, required this.preview});
  final Object? media;
  final bool preview;

  @override
  State<_AdMedia> createState() => _AdMediaState();
}

class _AdMediaState extends State<_AdMedia> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final items = widget.media is List ? widget.media as List : const [];
    final urls =
        items.whereType<Map>().where((m) => m['url'] is String).toList();
    if (urls.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final mediaHeight = (size.width - 40) * 16 / 9;
    return SizedBox(
      width: double.infinity,
      height:
          mediaHeight < size.height * 0.82 ? mediaHeight : size.height * 0.82,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => currentIndex = index),
            itemBuilder: (_, index) {
              final item = urls[index];
              final url = item['url'].toString();
              if (item['type'] == 'video') {
                return widget.preview || index != currentIndex
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_circle_outline_rounded, size: 64),
                        Text(widget.preview
                            ? 'فيديو · افتح الإعلان للتشغيل'
                            : 'فيديو'),
                      ]))
                    : VideoPlayerWidget(videoUrl: url);
              }
              return CachedMediaImage(
                url: url,
                fit: BoxFit.contain,
                fallback:
                    const Center(child: Icon(Icons.broken_image_outlined)),
              );
            },
          ),
          if (urls.length > 1)
            PositionedDirectional(
              top: 12,
              end: 12,
              child: IgnorePointer(
                  child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text('${currentIndex + 1}/${urls.length}',
                      style: const TextStyle(color: Colors.white)),
                ),
              )),
            ),
        ],
      ),
    );
  }
}

class AdvertisementDetails extends StatefulWidget {
  const AdvertisementDetails(
      {super.key, required this.ad, required this.isArabic});
  final Map<String, dynamic> ad;
  final bool isArabic;

  @override
  State<AdvertisementDetails> createState() => _AdvertisementDetailsState();
}

class _AdvertisementDetailsState extends State<AdvertisementDetails> {
  final controller = TextEditingController();
  final _composerFocus161 = FocusNode();
  bool liked = false;
  bool _likeBusy162 = false;
  bool submitting = false;
  List<Map<String, dynamic>> comments = [];

  String get id => widget.ad['id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AdvertisingService.isLiked(id),
        AdvertisingService.comments(id),
      ]);
      if (mounted)
        setState(() {
          liked = results[0] as bool;
          comments = results[1] as List<Map<String, dynamic>>;
        });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(FeatureControl.errorMessage(error, 'تعذر تحميل الإعلان')),
        ));
    }
  }

  @override
  void dispose() {
    _composerFocus161.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    if (_likeBusy162) return;
    _likeBusy162 = true;
    final target = !liked;
    final previous = (widget.ad['likes_count'] as num?)?.toInt() ?? 0;
    try {
      final result = await AdvertisingService.setLiked(id, liked: target);
      if (mounted)
        setState(() {
          liked = target;
          widget.ad['likes_count'] =
              result.displayCount(previous, liked: target);
        });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(FeatureControl.errorMessage(error, 'تعذر تسجيل الإعجاب')),
        ));
    } finally {
      _likeBusy162 = false;
    }
  }

  Future<void> _comment() async {
    if (submitting || controller.text.trim().isEmpty) return;
    setState(() => submitting = true);
    try {
      await AdvertisingService.comment(id, controller.text);
      controller.clear();
      final fresh = await AdvertisingService.comments(id);
      if (mounted) setState(() => comments = fresh);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(FeatureControl.errorMessage(error, 'تعذر إضافة التعليق')),
        ));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final ar = widget.isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'إعلان' : 'Advertisement')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          AdvertisementCard(ad: widget.ad, isArabic: ar, openOnTap: false),
          Wrap(spacing: 8, children: [
            TextButton.icon(
                onPressed: _like,
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                label: Text(ar ? 'إعجاب' : 'Like')),
          ]),
          Text(ar ? 'التعليقات' : 'Comments',
              style: Theme.of(context).textTheme.titleMedium),
          ...comments.map((comment) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(comment['body']?.toString() ?? ''),
                trailing: comment['can_delete161'] == true
                    ? IconButton(
                        tooltip: 'حذف التعليق',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                      title: const Text('حذف التعليق؟'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, false),
                                            child: const Text('إلغاء')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, true),
                                            child: const Text('حذف'))
                                      ]));
                          if (ok != true || !mounted) return;
                          try {
                            await Supabase.instance.client
                                .rpc('zameel_delete_comment161', params: {
                              'p_kind': 'advertisement',
                              'p_id': comment['id']
                            });
                            final fresh = await AdvertisingService.comments(id);
                            if (mounted) setState(() => comments = fresh);
                          } catch (_) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('تعذر حذف التعليق')));
                          }
                        })
                    : null,
              )),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: controller,
                    focusNode: _composerFocus161,
                    groupId: _composerFocus161,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onEditingComplete: () {},
                    decoration: InputDecoration(
                        hintText: ar ? 'اكتب تعليقاً' : 'Write a comment'))),
            KeepKeyboardSendButton(
                composerFocus: _composerFocus161,
                onSend: _comment,
                enabled: !submitting,
                busy: submitting),
          ]),
        ]),
      ),
    );
  }
}
