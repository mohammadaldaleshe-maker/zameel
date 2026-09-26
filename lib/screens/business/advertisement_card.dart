import 'package:flutter/material.dart';

import '../../services/advertising_service.dart';
import '../../services/feature_control.dart';
import '../../widgets/video_player_widget.dart';

class AdvertisementCard extends StatelessWidget {
  const AdvertisementCard({super.key, required this.ad, required this.isArabic,
    this.openOnTap = true, this.onHide});

  final Map<String, dynamic> ad;
  final bool isArabic;
  final bool openOnTap;
  final Future<void> Function()? onHide;

  @override
  Widget build(BuildContext context) {
    final partner = ad['business_partners'];
    final name = partner is Map ? partner['name']?.toString() ?? '' : '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: openOnTap ? () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => AdvertisementDetails(ad: ad, isArabic: isArabic),
        )) : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.campaign_outlined, color: Color(0xFF08736D)),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(isArabic ? 'إعلان' : 'Ad', style: const TextStyle(color: Color(0xFF08736D))),
            ]),
            const SizedBox(height: 9),
            Text(ad['title']?.toString() ?? '', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(ad['body']?.toString() ?? '', maxLines: 4, overflow: TextOverflow.ellipsis),
            _AdMedia(media: ad['media'], preview: openOnTap),
            const SizedBox(height: 8),
            Text('${ad['view_count'] ?? 0} ${isArabic ? 'مشاهدة' : 'views'}   ·   ${ad['likes_count'] ?? 0} ${isArabic ? 'إعجاب' : 'likes'}   ·   ${ad['comments_count'] ?? 0} ${isArabic ? 'تعليق' : 'comments'}',
                style: const TextStyle(color: Colors.black54)),
            if (onHide != null) TextButton(
              onPressed: () async {
                try {
                  await onHide!();
                } catch (error) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر إخفاء الإعلان'))),
                  );
                }
              },
              child: Text(isArabic ? 'لا يهمني هذا الإعلان' : 'Not interested'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AdMedia extends StatelessWidget {
  const _AdMedia({required this.media, required this.preview});
  final Object? media;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final items = media is List ? media as List : const [];
    final urls = items.whereType<Map>().where((m) => m['url'] is String).toList();
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (_, index) {
          final item = urls[index];
          final url = item['url'].toString();
          if (item['type'] == 'video') {
            return preview
                ? const Center(child: Icon(Icons.play_circle_outline_rounded, size: 64))
                : VideoPlayerWidget(videoUrl: url);
          }
          return Image.network(url, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)));
        },
      ),
    );
  }
}

class AdvertisementDetails extends StatefulWidget {
  const AdvertisementDetails({super.key, required this.ad, required this.isArabic});
  final Map<String, dynamic> ad;
  final bool isArabic;

  @override
  State<AdvertisementDetails> createState() => _AdvertisementDetailsState();
}

class _AdvertisementDetailsState extends State<AdvertisementDetails> {
  final controller = TextEditingController();
  bool liked = false;
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
      await AdvertisingService.recordView(id);
      final results = await Future.wait([
        AdvertisingService.isLiked(id), AdvertisingService.comments(id),
      ]);
      if (mounted) setState(() {
        liked = results[0] as bool;
        comments = results[1] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(FeatureControl.errorMessage(error, 'تعذر تحميل الإعلان')),
      ));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    try {
      await AdvertisingService.setLiked(id, liked: !liked);
      if (mounted) setState(() => liked = !liked);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(FeatureControl.errorMessage(error, 'تعذر تسجيل الإعجاب')),
      ));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(FeatureControl.errorMessage(error, 'تعذر إضافة التعليق')),
      ));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'إعلان' : 'Advertisement')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          AdvertisementCard(ad: widget.ad, isArabic: ar, openOnTap: false),
          Wrap(spacing: 8, children: [
            TextButton.icon(onPressed: _like,
              icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
              label: Text(ar ? 'إعجاب' : 'Like')),
            Text('${widget.ad['view_count'] ?? 0} ${ar ? 'مشاهدة' : 'views'}'),
          ]),
          Text(ar ? 'التعليقات' : 'Comments', style: Theme.of(context).textTheme.titleMedium),
          ...comments.map((comment) => ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(comment['body']?.toString() ?? ''),
          )),
          Row(children: [
            Expanded(child: TextField(controller: controller,
              decoration: InputDecoration(hintText: ar ? 'اكتب تعليقاً' : 'Write a comment'))),
            IconButton(onPressed: submitting ? null : _comment, icon: const Icon(Icons.send_rounded)),
          ]),
        ]),
      ),
    );
  }
}
