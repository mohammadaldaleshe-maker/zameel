import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});
  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  String query = '';
  int category = 0;

  final List<Map<String, dynamic>> partners = const [
    {'name': 'Zameel Campus Store', 'cat': 1, 'icon': Icons.shopping_bag_rounded, 'tag': 'طلاب فقط', 'desc': 'مستلزمات جامعية وقرطاسية بأسعار طلابية.'},
    {'name': 'Code Academy', 'cat': 2, 'icon': Icons.code_rounded, 'tag': 'تعليم', 'desc': 'دورات تقنية وفرص تدريب عملية للطلاب.'},
    {'name': 'Career Bridge', 'cat': 3, 'icon': Icons.work_outline_rounded, 'tag': 'وظائف', 'desc': 'تدريب وفرص عمل مصممة لحديثي التخرج.'},
    {'name': 'Campus Café', 'cat': 1, 'icon': Icons.local_cafe_rounded, 'tag': 'خصم طلابي', 'desc': 'عروض ومزايا خاصة لمستخدمي زميل.'},
    {'name': 'Study Hub', 'cat': 2, 'icon': Icons.menu_book_rounded, 'tag': 'أكاديمي', 'desc': 'ملخصات وأدوات تساعدك على الدراسة بذكاء.'},
    {'name': 'Tech Solutions', 'cat': 3, 'icon': Icons.business_center_rounded, 'tag': 'شريك', 'desc': 'حلول تقنية وبرامج تدريبية للطلبة والجامعات.'},
  ];

  List<Map<String, dynamic>> get filtered => partners.where((p) {
    final matchesCategory = category == 0 || p['cat'] == category;
    final q = query.trim().toLowerCase();
    return matchesCategory && (q.isEmpty || p['name'].toString().toLowerCase().contains(q) || p['desc'].toString().toLowerCase().contains(q));
  }).toList();

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(title: Text(ar ? 'شركاء زميل' : 'Zameel Partners'), actions: [IconButton(onPressed: () => _showInfo(ar), icon: const Icon(Icons.info_outline_rounded))]),
        body: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
            children: [
              _hero(ar),
              const SizedBox(height: 14),
              TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: ar ? 'ابحث عن شركة، منتج أو عرض' : 'Search companies, products or offers', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [
                _filter(0, ar ? 'الكل' : 'All'), _filter(1, ar ? 'عروض طلابية' : 'Student offers'), _filter(2, ar ? 'تعليم' : 'Education'), _filter(3, ar ? 'وظائف' : 'Career'),
              ])),
              const SizedBox(height: 14),
              Row(children: [Text(ar ? 'شركاء مختارون' : 'Featured partners', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length}', style: const TextStyle(color: Colors.grey))]),
              const SizedBox(height: 10),
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
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF2563EB)]), borderRadius: BorderRadius.circular(24)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withAlpha(35), borderRadius: BorderRadius.circular(16)), child: Image.asset('assets/branding/zameel_mark.png', fit: BoxFit.contain)), const SizedBox(width: 12), Expanded(child: Text(ar ? 'منظومة شركاء زميل' : 'Zameel Partner Network', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 12),
      Text(ar ? 'اكتشف عروضًا وفرصًا وخدمات صُممت للطلاب والطالبات داخل مجتمعهم الجامعي.' : 'Discover offers, opportunities and services built for university students.', style: const TextStyle(color: Colors.white70, height: 1.5)),
    ]),
  );

  Widget _filter(int id, String label) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(label), selected: category == id, onSelected: (_) => setState(() => category = id)));

  Widget _partnerCard(Map<String, dynamic> p, bool ar) => Card(margin: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () => _showPartner(p, ar), borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFF0ECFF), borderRadius: BorderRadius.circular(16)), child: Icon(p['icon'], color: const Color(0xFF5B21B6), size: 28)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: Text(p['tag'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))))]), const SizedBox(height: 4), Text(p['desc'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, height: 1.35))])), const Icon(Icons.chevron_left_rounded, color: Colors.grey)]))));

  Widget _studentValueCard(bool ar) {
    return Card(
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
                    ar ? 'سيظهر وسم الشريك والعرض بوضوح، ولن تختلط العروض المدفوعة بالمحتوى الأكاديمي.' : 'Partner and sponsored content stays clearly labeled and separate from academic content.',
                    style: const TextStyle(color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPartner(Map<String, dynamic> p, bool ar) => showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 30, backgroundColor: const Color(0xFFF0ECFF), child: Icon(p['icon'], color: const Color(0xFF5B21B6), size: 30)), const SizedBox(height: 10), Text(p['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(p['desc'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)), const SizedBox(height: 16), FilledButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'سيتم فتح تفاصيل الشريك والعرض هنا.' : 'Partner and offer details will open here.'))); }, icon: const Icon(Icons.open_in_new_rounded), label: Text(ar ? 'عرض التفاصيل' : 'View details'))]))));

  void _showInfo(bool ar) => showDialog(context: context, builder: (_) => AlertDialog(title: Text(ar ? 'شركاء زميل' : 'Zameel Partners'), content: Text(ar ? 'مساحة مخصصة للشركات والجهات التي تقدم قيمة حقيقية للطلاب والطالبات: خصومات، تدريب، وظائف، خدمات ومنتجات.' : 'A dedicated space for organizations offering real student value: discounts, training, jobs, services and products.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(ar ? 'حسنًا' : 'OK'))]));
}
