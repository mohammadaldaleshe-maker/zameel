import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/language_provider.dart';
import '../../services/remaining_services.dart';
import '../../services/feature_control.dart';
import 'partner_ads_screen.dart';
import 'package:zameel/theme/app_theme.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  String query = '';
  int category = 0;
  bool _loading = true;
  bool _canManage = false;
  List<Map<String, dynamic>> partners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        RemainingServices.partners(),
        RemainingServices.canManagePartners(),
      ]);
      final rows = results[0] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        partners = rows.map(_normalize).toList();
        _canManage = results[1] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> row) {
    final rawCategory = row['category']?.toString() ?? 'services';
    return {
      ...row,
      'cat': switch (rawCategory) {
        'offers' => 1,
        'education' => 2,
        'career' => 3,
        _ => 4,
      },
      'icon': switch (rawCategory) {
        'offers' => Icons.local_offer_rounded,
        'education' => Icons.school_rounded,
        'career' => Icons.work_outline_rounded,
        _ => Icons.business_rounded,
      },
      'tag': row['tag']?.toString() ?? '',
      'desc': row['description']?.toString() ?? '',
    };
  }

  List<Map<String, dynamic>> get filtered => partners.where((p) {
        final matchesCategory = category == 0 || p['cat'] == category;
        final q = query.trim().toLowerCase();
        return matchesCategory &&
            (q.isEmpty ||
                p['name'].toString().toLowerCase().contains(q) ||
                p['desc'].toString().toLowerCase().contains(q));
      }).toList();

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: AppBar(
          title: Text(ar ? 'شركاء Zameel' : 'Zameel Partners'),
          actions: [
            if (_canManage)
              IconButton(
                tooltip: ar ? 'إضافة شريك' : 'Add partner',
                onPressed: () => _showAddPartner(ar),
                icon: const Icon(Icons.add_business_rounded),
              ),
            IconButton(
              onPressed: () => _showInfo(ar),
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
                  children: [
                    _hero(ar),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: ar
                            ? 'ابحث عن شركة، منتج أو عرض'
                            : 'Search companies, products or offers',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filter(0, ar ? 'الكل' : 'All'),
                          _filter(1, ar ? 'عروض طلابية' : 'Student offers'),
                          _filter(2, ar ? 'تعليم' : 'Education'),
                          _filter(3, ar ? 'وظائف' : 'Career'),
                          _filter(4, ar ? 'خدمات' : 'Services'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          ar ? 'شركاء معتمدون' : 'Approved partners',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text('${filtered.length}', style: const TextStyle(color: AppTheme.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            const Icon(Icons.business_outlined, size: 54, color: AppTheme.muted),
                            const SizedBox(height: 10),
                            Text(
                              ar
                                  ? 'لا يوجد شركاء معتمدون في هذه الفئة بعد'
                                  : 'No approved partners in this category yet',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filtered.map((p) => _partnerCard(p, ar)),
                    const SizedBox(height: 8),
                    _studentValueCard(ar),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _hero(bool ar) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryDark]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset('assets/branding/zameel_mark.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ar ? 'منظومة شركاء Zameel' : 'Zameel Partner Network',
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ar
                  ? 'اكتشف عروضًا وفرصًا وخدمات صُممت للطلاب والطالبات داخل مجتمعهم الجامعي.'
                  : 'Discover offers, opportunities and services built for university students.',
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      );

  Widget _filter(int id, String label) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: category == id,
          onSelected: (_) => setState(() => category = id),
        ),
      );

  Widget _partnerCard(Map<String, dynamic> p, bool ar) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => _showPartner(p, ar),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(p['icon'] as IconData, color: AppTheme.primaryDark, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          if ((p['tag']?.toString() ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p['tag'].toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p['desc']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (_canManage)
                  IconButton(
                    tooltip: ar ? 'حذف الشريك' : 'Delete partner',
                    onPressed: () => _confirmDeletePartner(p, ar),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  )
                else
                  const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      );

  Widget _studentValueCard(bool ar) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar ? 'مزايا مخصصة للطلاب' : 'Student-first benefits', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      ar
                          ? 'لا يظهر هنا إلا الشركاء المعتمدون من Zameel، وتبقى العروض منفصلة بوضوح عن المحتوى الأكاديمي.'
                          : 'Only Zameel-approved partners appear here, and offers remain clearly separate from academic content.',
                      style: const TextStyle(color: AppTheme.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  void _showPartner(Map<String, dynamic> p, bool ar) {
    if (!FeatureControl.instance.enabled('partner_advertising')) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(p['desc']?.toString() ?? '', textAlign: TextAlign.center),
            if ((p['website_url']?.toString() ?? '').isNotEmpty)
              TextButton.icon(
                onPressed: () => _openPartnerWebsite(p['website_url'].toString(), ar),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(ar ? 'زيارة الموقع' : 'Visit website'),
              ),
          ]),
        )),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PartnerAdsScreen(partner: p, isArabic: ar),
    ));
  }

  Future<void> _openPartnerWebsite(String rawUrl, bool ar) async {
    final value = rawUrl.trim();
    if (value.isEmpty) return;
    final normalized = value.startsWith('http://') || value.startsWith('https://')
        ? value : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تعذر فتح موقع الشريك' : 'Could not open partner website'),
      ));
    }
  }


  Future<void> _showAddPartner(bool ar) async {
    final name = TextEditingController();
    final tag = TextEditingController();
    final description = TextEditingController();
    final website = TextEditingController();
    String categoryValue = 'services';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ar ? 'إضافة شريك Zameel' : 'Add Zameel Partner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: ar ? 'اسم الشريك' : 'Partner name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categoryValue,
                  decoration: InputDecoration(
                    labelText: ar ? 'الفئة' : 'Category',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'offers', child: Text(ar ? 'عروض طلابية' : 'Student offers')),
                    DropdownMenuItem(value: 'education', child: Text(ar ? 'تعليم' : 'Education')),
                    DropdownMenuItem(value: 'career', child: Text(ar ? 'وظائف' : 'Career')),
                    DropdownMenuItem(value: 'services', child: Text(ar ? 'خدمات' : 'Services')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => categoryValue = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tag,
                  decoration: InputDecoration(
                    labelText: ar ? 'وسم مختصر' : 'Short tag',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: ar ? 'الوصف' : 'Description',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: website,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: ar ? 'الموقع الإلكتروني (اختياري)' : 'Website (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(ar ? 'إضافة' : 'Add'),
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                try {
                  await RemainingServices.addPartner(
                    name: name.text,
                    category: categoryValue,
                    tag: tag.text,
                    description: description.text,
                    websiteUrl: website.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _load();
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(ar ? '✅ تمت إضافة الشريك' : '✅ Partner added')),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(ar ? 'تعذر إضافة الشريك' : 'Could not add partner')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePartner(Map<String, dynamic> partner, bool ar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'حذف الشريك' : 'Delete partner'),
        content: Text(
          ar
              ? 'هل تريد حذف "${partner['name']}" من شركاء Zameel؟'
              : 'Delete "${partner['name']}" from Zameel Partners?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ar ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RemainingServices.deletePartner(partner['id']?.toString() ?? '');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? '🗑️ تم حذف الشريك' : '🗑️ Partner deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? 'تعذر حذف الشريك' : 'Could not delete partner')),
      );
    }
  }

  void _showInfo(bool ar) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(ar ? 'شركاء Zameel' : 'Zameel Partners'),
          content: Text(
            ar
                ? 'مساحة للشركات والجهات المعتمدة التي تقدم خصومات أو تدريبًا أو وظائف أو خدمات مفيدة للطلاب.'
                : 'A space for approved organizations offering discounts, training, jobs or useful student services.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(ar ? 'حسنًا' : 'OK')),
          ],
        ),
      );
}
