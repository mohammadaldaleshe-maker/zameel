import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../services/advertising_service.dart';
import 'advertisement_card.dart';

/// Public partner page. The database exposes only approved, active adverts.
class PartnerAdsScreen extends StatefulWidget {
  const PartnerAdsScreen({super.key, required this.partner, required this.isArabic});

  final Map<String, dynamic> partner;
  final bool isArabic;

  @override
  State<PartnerAdsScreen> createState() => _PartnerAdsScreenState();
}

class _PartnerAdsScreenState extends State<PartnerAdsScreen> {
  late Future<List<Map<String, dynamic>>> _ads = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    return AdvertisingService.liveAds(
      partnerId: widget.partner['id'].toString(), limit: 50,
    );
  }

  Future<void> _refresh() async {
    setState(() => _ads = _load());
    await _ads;
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    final partner = widget.partner;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: AppBar(title: Text(partner['name']?.toString() ?? '')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _ads,
            builder: (context, snapshot) {
              final ads = snapshot.data ?? const <Map<String, dynamic>>[];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(partner['name']?.toString() ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(partner['description']?.toString() ?? ''),
                      if ((partner['website_url']?.toString() ?? '').isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            final value = partner['website_url'].toString();
                            final uri = Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
                            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: Text(ar ? 'زيارة الموقع' : 'Visit website'),
                        ),
                    ]),
                  )),
                  const SizedBox(height: 12),
                  Text(ar ? 'إعلانات الشريك' : 'Partner ads', style: Theme.of(context).textTheme.titleLarge),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    Padding(padding: const EdgeInsets.all(20), child: Text(ar ? 'تعذر تحميل الإعلانات حالياً' : 'Could not load ads right now'))
                  else if (ads.isEmpty)
                    Padding(padding: const EdgeInsets.all(20), child: Text(ar ? 'لا توجد إعلانات منشورة حالياً' : 'No published ads yet'))
                  else
                    ...ads.map((ad) => AdvertisementCard(ad: ad, isArabic: ar)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
