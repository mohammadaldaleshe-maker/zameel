import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import 'lamma_chat_screen.dart';

class LammaScreen extends StatefulWidget {
  const LammaScreen({super.key});
  @override
  State<LammaScreen> createState() => _LammaScreenState();
}

class _LammaScreenState extends State<LammaScreen> with SingleTickerProviderStateMixin {
  final db = Supabase.instance.client;
  late final TabController _tabs;
  bool _loading = true;
  Map<String,dynamic>? _discovery;
  List<Map<String,dynamic>> _candidates=[];
  List<Map<String,dynamic>> _matches=[];
  List<Map<String,dynamic>> _lammas=[];
  Set<String> _myLammaIds={};

  @override
  void initState(){super.initState();_tabs=TabController(length:2,vsync:this);_load();}
  @override
  void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load() async {
    final uid=db.auth.currentUser?.id;if(uid==null)return;
    try{
      final profile=await db.from('social_discovery_profiles').select().eq('user_id',uid).maybeSingle();
      final lammas=await db.from('social_lammas').select('*,social_lamma_members(count)').order('created_at',ascending:false).limit(40);
      final memberships=await db.from('social_lamma_members').select('lamma_id').eq('user_id',uid);
      List<Map<String,dynamic>> candidates=[];
      List<Map<String,dynamic>> matches=[];
      if(profile?['enabled']==true){
        final rows=await db.rpc('get_social_discovery_candidates',params:{'p_limit':30});
        candidates=List<Map<String,dynamic>>.from((rows as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)));
        final matchedRows=await db.rpc('get_my_social_matches');
        matches=List<Map<String,dynamic>>.from((matchedRows as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)));
      }
      if(mounted)setState((){_discovery=profile==null?null:Map<String,dynamic>.from(profile);_lammas=List<Map<String,dynamic>>.from(lammas);_myLammaIds={for(final row in memberships as List) row['lamma_id'].toString()};_candidates=candidates;_matches=matches;_loading=false;});
    }catch(e){if(mounted){setState(()=>_loading=false);_error(e);}}
  }

  void _error(Object e)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إكمال العملية: $e')));
  bool get _ar=>Provider.of<LanguageProvider>(context,listen:false).isArabic;

  Future<void> _setupDiscovery() async {
    var intent=_discovery?['intent']?.toString()??'friendship';
    var preferred=_discovery?['preferred_gender']?.toString()??'any';
    var birth=DateTime.tryParse(_discovery?['birth_date']?.toString()??'')??DateTime(DateTime.now().year-20,1,1);
    final intro=TextEditingController(text:_discovery?['intro']?.toString()??'');
    final interests=TextEditingController(text:((_discovery?['interests'] as List?)??const []).join('، '));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(_ar?'إعداد انسجام':'Set up Insijam'),
      content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.primaryLight,borderRadius:BorderRadius.circular(12)),child:Text(_ar?'اختياري وسري. لن تظهر هنا إلا لمن فعّل الميزة، والدردشة لا تُفتح إلا بعد قبول متبادل. للبالغين 18+ فقط.':'Optional and private. Chat opens only after mutual interest. Adults 18+ only.')),
        const SizedBox(height:12),DropdownButtonFormField(value:intent,decoration:InputDecoration(labelText:_ar?'الغرض':'Purpose'),items:[DropdownMenuItem(value:'friendship',child:Text(_ar?'صداقة':'Friendship')),DropdownMenuItem(value:'serious',child:Text(_ar?'تعارف جاد':'Serious connection')),DropdownMenuItem(value:'both',child:Text(_ar?'كلاهما':'Both'))],onChanged:(v)=>setLocal(()=>intent=v!)),
        const SizedBox(height:10),DropdownButtonFormField(value:preferred,decoration:InputDecoration(labelText:_ar?'أرغب بالتعرّف إلى':'I want to meet'),items:[DropdownMenuItem(value:'any',child:Text(_ar?'لا فرق':'Anyone')),DropdownMenuItem(value:'male',child:Text(_ar?'شباب':'Men')),DropdownMenuItem(value:'female',child:Text(_ar?'فتيات':'Women'))],onChanged:(v)=>setLocal(()=>preferred=v!)),
        const SizedBox(height:10),ListTile(contentPadding:EdgeInsets.zero,title:Text(_ar?'تاريخ الميلاد':'Date of birth'),subtitle:Text('${birth.year}-${birth.month.toString().padLeft(2,'0')}-${birth.day.toString().padLeft(2,'0')}'),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:ctx,initialDate:birth,firstDate:DateTime(1950),lastDate:DateTime(DateTime.now().year-18,DateTime.now().month,DateTime.now().day));if(d!=null)setLocal(()=>birth=d);}),
        TextField(controller:intro,maxLength:280,maxLines:3,decoration:InputDecoration(labelText:_ar?'تعريف قصير':'Short intro')),
        TextField(controller:interests,decoration:InputDecoration(labelText:_ar?'اهتمامات مفصولة بفواصل':'Comma-separated interests')),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(_ar?'إلغاء':'Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(_ar?'تفعيل':'Enable'))],)));
    if(ok!=true)return;
    final age=DateTime.now().difference(birth).inDays~/365;if(age<18){_error(_ar?'الميزة للبالغين 18+ فقط':'Adults 18+ only');return;}
    try{await db.from('social_discovery_profiles').upsert({'user_id':db.auth.currentUser!.id,'enabled':true,'intent':intent,'preferred_gender':preferred,'birth_date':'${birth.year}-${birth.month.toString().padLeft(2,'0')}-${birth.day.toString().padLeft(2,'0')}','intro':intro.text.trim(),'interests':interests.text.split(RegExp(r'[,،]')).map((e)=>e.trim()).where((e)=>e.isNotEmpty).take(12).toList(),'updated_at':DateTime.now().toUtc().toIso8601String()});await _load();}catch(e){_error(e);}
  }

  Future<void> _pauseDiscovery() async {
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(_ar?'إيقاف انسجام؟':'Pause Insijam?'),
      content:Text(_ar?'ستختفي بطاقتك فورًا من الاقتراحات. لن يعرف أي شخص أنك أوقفت أو فعّلت الميزة، ويمكنك العودة لاحقًا.':'Your card disappears immediately. Nobody is told whether you enabled or paused the feature, and you can return later.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(_ar?'إلغاء':'Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(_ar?'إيقاف':'Pause'))],
    ));
    if(confirmed!=true)return;
    try{await db.from('social_discovery_profiles').update({'enabled':false,'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('user_id',db.auth.currentUser!.id);await _load();}catch(e){_error(e);}
  }

  Future<void> _react(Map<String,dynamic> person,String decision)async{
    try{final matched=await db.rpc('react_social_discovery',params:{'p_target':person['user_id'],'p_decision':decision})==true;if(mounted)setState(()=>_candidates.removeWhere((e)=>e['user_id']==person['user_id']));if(matched&&mounted){showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(_ar?'صار في انسجام! ✨':'It is a match! ✨'),content:Text(_ar?'الاهتمام متبادل. يمكنكما الآن بدء محادثة محترمة.':'Your interest is mutual. You can now start a conversation.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(_ar?'لاحقًا':'Later')),FilledButton(onPressed:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(partnerId:person['user_id'].toString(),partnerName:person['name']?.toString()??'Zameel')));},child:Text(_ar?'ابدأ المحادثة':'Start chat'))]));}}catch(e){_error(e);}
  }

  Future<void> _createLamma()async{
    final title=TextEditingController();var vibe='coffee';var max=6;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:Text(_ar?'أنشئ لَمّة':'Create a Lamma'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:InputDecoration(labelText:_ar?'عنوان بسيط':'Short title')),const SizedBox(height:10),DropdownButtonFormField(value:vibe,items:_vibes.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(_ar?e.value.$1:e.value.$2))).toList(),onChanged:(v)=>setLocal(()=>vibe=v!),decoration:InputDecoration(labelText:_ar?'نوع اللّمّة':'Vibe')),const SizedBox(height:10),DropdownButtonFormField(value:max,items:[3,4,5,6,7,8].map((e)=>DropdownMenuItem(value:e,child:Text('$e'))).toList(),onChanged:(v)=>setLocal(()=>max=v!),decoration:InputDecoration(labelText:_ar?'عدد المقاعد':'Seats'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(_ar?'إلغاء':'Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(_ar?'إنشاء':'Create'))])));
    if(ok!=true||title.text.trim().length<3)return;
    try{final me=await db.from('users').select('university,college').eq('id',db.auth.currentUser!.id).single();final row=await db.from('social_lammas').insert({'creator_id':db.auth.currentUser!.id,'title':title.text.trim(),'vibe':vibe,'max_members':max,'university':me['university']??'','college':me['college']??''}).select('id,title').single();final joined=await db.rpc('join_social_lamma',params:{'p_lamma':row['id']})==true;if(!joined)throw StateError('join_failed');await _load();if(mounted)_openLammaChat(row);}catch(e){_error(e);}
  }

  void _openLammaChat(Map<String,dynamic> lamma)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LammaChatScreen(lammaId:lamma['id'].toString(),title:lamma['title']?.toString()??'لَمّة')));

  Future<void> _join(Map<String,dynamic> lamma)async{final id=lamma['id'].toString();if(_myLammaIds.contains(id)){_openLammaChat(lamma);return;}try{final ok=await db.rpc('join_social_lamma',params:{'p_lamma':lamma['id']})==true;if(!ok){_error(_ar?'اكتمل عدد أعضاء هذه اللّمّة.':'This Lamma is full.');return;}await _load();if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_ar?'انضممت إلى اللّمّة ✓':'Joined the Lamma ✓')));_openLammaChat(lamma);}}catch(e){_error(e);}}

  static const _vibes=<String,(String,String)>{'coffee':('قهوة وتعارف','Coffee & chat'),'walk':('مشي داخل الحرم','Campus walk'),'lunch':('غداء جماعي','Lunch'),'games':('ألعاب وضحك','Games'),'ideas':('أفكار ومشاريع','Ideas'),'new_students':('طلاب جدد','New students'),'chill':('تغيير جو','Just chill')};

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ar ? 'لَمّة Zameel' : 'Zameel Lamma'),
          bottom: TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                text: ar ? 'اللّمات' : 'Lammas',
                icon: const Icon(Icons.groups_rounded),
              ),
              Tab(
                text: ar ? 'انسجام' : 'Insijam',
                icon: const Icon(Icons.favorite_outline_rounded),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [_lammaTab(ar), _insijamTab(ar)],
              ),
      ),
    );
  }

  Widget _lammaTab(bool ar)=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:AppTheme.signatureGradient,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(ar?'دخلت الجامعة وحدك؟':'Came to university alone?',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(ar?'Zameel يجد لك اللّمّة المناسبة.':'Zameel finds your kind of people.',style:const TextStyle(color:Colors.white70)),const SizedBox(height:14),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:AppTheme.primary),onPressed:_createLamma,icon:const Icon(Icons.add),label:Text(ar?'أنشئ لَمّة':'Create Lamma'))])),const SizedBox(height:18),if(_lammas.isEmpty)Padding(padding:const EdgeInsets.all(30),child:Center(child:Text(ar?'لا توجد لَمّات مفتوحة الآن. كن أول من يبدأ.':'No open Lammas yet. Start the first one.'))),..._lammas.map((l){final raw=l['social_lamma_members'];final count=raw is List&&raw.isNotEmpty?(raw.first['count']??0):0;final vibe=_vibes[l['vibe']]??_vibes['chill']!;final member=_myLammaIds.contains(l['id'].toString());return Card(margin:const EdgeInsets.only(bottom:12),child:ListTile(onTap:()=>_join(l),contentPadding:const EdgeInsets.all(14),leading:CircleAvatar(backgroundColor:AppTheme.primaryLight,child:const Icon(Icons.groups_rounded,color:AppTheme.primary)),title:Text(l['title']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${ar?vibe.$1:vibe.$2} • $count/${l['max_members']}'),trailing:FilledButton(onPressed:()=>_join(l),child:Text(member?(ar?'دخول':'Open'):(ar?'انضم':'Join')))));})]));

  Widget _insijamTab(bool ar){if(_discovery?['enabled']!=true)return Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.favorite_rounded,size:72,color:AppTheme.primary),const SizedBox(height:18),Text(ar?'انسجام اختياري وسري':'Insijam is private and opt-in',style:Theme.of(context).textTheme.headlineSmall,textAlign:TextAlign.center),const SizedBox(height:10),Text(ar?'لصداقة فردية أو تعارف جاد. لا محادثة قبل القبول المتبادل، ولا نكشف موقعك أو رقمك.':'For friendship or a serious connection. No chat before mutual interest, and your location and number stay private.',textAlign:TextAlign.center),const SizedBox(height:20),FilledButton.icon(onPressed:_setupDiscovery,icon:const Icon(Icons.lock_open_rounded),label:Text(ar?'فعّل انسجام':'Enable Insijam'))])));
    if(_candidates.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[if(_matches.isNotEmpty)...[Text(ar?'الأشخاص المتوافقون معك':'Your matches',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Wrap(spacing:10,runSpacing:10,children:_matches.map((m)=>ActionChip(avatar:CircleAvatar(backgroundImage:m['profile_image']?.toString().isNotEmpty==true?NetworkImage(m['profile_image'].toString()):null,child:m['profile_image']?.toString().isNotEmpty==true?null:const Icon(Icons.person,size:16)),label:Text(m['name']?.toString()??'Zameel'),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(partnerId:m['user_id'].toString(),partnerName:m['name']?.toString()??'Zameel'))))).toList()),const SizedBox(height:30)],const Icon(Icons.travel_explore_rounded,size:70,color:AppTheme.primary),const SizedBox(height:14),Text(ar?'لا توجد اقتراحات جديدة الآن':'No new suggestions right now'),const SizedBox(height:12),OutlinedButton(onPressed:_setupDiscovery,child:Text(ar?'تعديل تفضيلاتي':'Edit preferences'))])));
    final p=_candidates.first;final interests=(p['interests'] as List? ?? const []).join(' • ');return Padding(padding:const EdgeInsets.all(18),child:Column(children:[Row(children:[if(_matches.isNotEmpty)TextButton.icon(onPressed:()=>showModalBottomSheet(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,children:_matches.map((m)=>ListTile(leading:CircleAvatar(backgroundImage:m['profile_image']?.toString().isNotEmpty==true?NetworkImage(m['profile_image'].toString()):null,child:m['profile_image']?.toString().isNotEmpty==true?null:const Icon(Icons.person)),title:Text(m['name']?.toString()??'Zameel'),subtitle:Text(m['department']?.toString()??''),onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(partnerId:m['user_id'].toString(),partnerName:m['name']?.toString()??'Zameel')));},)).toList()))),icon:const Icon(Icons.favorite_rounded),label:Text('${_matches.length}')),const Spacer(),IconButton(tooltip:ar?'إيقاف انسجام':'Pause Insijam',onPressed:_pauseDiscovery,icon:const Icon(Icons.visibility_off_rounded)),IconButton(tooltip:ar?'تعديل التفضيلات':'Edit preferences',onPressed:_setupDiscovery,icon:const Icon(Icons.tune_rounded))]),Expanded(child:Card(clipBehavior:Clip.antiAlias,child:Column(children:[Expanded(child:Container(width:double.infinity,color:AppTheme.primaryLight,child:p['profile_image']?.toString().isNotEmpty==true?Image.network(p['profile_image'],fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.person,size:100)):const Icon(Icons.person,size:100,color:AppTheme.primary))),Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p['name']??'Zameel'}، ${p['age']??''}',style:Theme.of(context).textTheme.headlineSmall),Text('${p['department']??''} • ${p['college']??''}',style:const TextStyle(color:AppTheme.textSecondary)),if((p['intro']??'').toString().isNotEmpty)...[const SizedBox(height:10),Text(p['intro'].toString())],if(interests.isNotEmpty)...[const SizedBox(height:10),Text(interests,style:const TextStyle(color:AppTheme.primary,fontWeight:FontWeight.w700))]]))]))),const SizedBox(height:14),Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[FloatingActionButton(heroTag:'pass',backgroundColor:Colors.white,foregroundColor:AppTheme.error,onPressed:()=>_react(p,'pass'),child:const Icon(Icons.close_rounded)),FloatingActionButton.large(heroTag:'like',backgroundColor:AppTheme.primary,foregroundColor:Colors.white,onPressed:()=>_react(p,'like'),child:const Icon(Icons.favorite_rounded))]) ]));}
}
