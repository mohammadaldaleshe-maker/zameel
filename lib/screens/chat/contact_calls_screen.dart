import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../meet/meet_screen.dart';
import '../../services/screen_awake_service.dart';
import '../../services/feature_control.dart';

class ContactCallsScreen extends StatefulWidget {
  const ContactCallsScreen({super.key});
  @override
  State<ContactCallsScreen> createState() => _ContactCallsScreenState();
}

class _ContactCallsScreenState extends State<ContactCallsScreen> {
  final _search = TextEditingController();
  List<_PhoneContact> _contacts = const [];
  bool _loading = true;
  bool _permissionDenied = false;

  String _hash(String phone) {
    var normalized=phone.replaceAll(RegExp(r'[^0-9]'),'');
    if(normalized.startsWith('00')) normalized=normalized.substring(2);
    if(normalized.length==10&&normalized.startsWith('0')) normalized='962${normalized.substring(1)}';
    if(normalized.length==9&&normalized.startsWith('7')) normalized='962$normalized';
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<void> _showHistory() async {
    try{
      final raw=await Supabase.instance.client.rpc('get_call_history');
      final rows=List<Map<String,dynamic>>.from(raw as List);
      if(!mounted)return;
      await showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>DraggableScrollableSheet(expand:false,initialChildSize:.78,maxChildSize:.95,builder:(_,controller)=>Column(children:[const Padding(padding:EdgeInsets.all(12),child:Text('سجل المكالمات',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),Expanded(child:rows.isEmpty?const Center(child:Text('لا توجد مكالمات بعد')):ListView.builder(controller:controller,itemCount:rows.length,itemBuilder:(_,i){final r=rows[i];final incoming=r['direction']=='incoming';final video=r['with_video']==true;final duration=(r['duration_seconds'] as num?)?.toInt()??0;final created=DateTime.tryParse(r['created_at']?.toString()??'')?.toLocal();return ListTile(onLongPress:()async{await Supabase.instance.client.rpc('hide_call_from_my_history',params:{'target_room_id':r['room_id']});if(ctx.mounted)Navigator.pop(ctx);},leading:CircleAvatar(backgroundImage:r['other_image']?.toString().isNotEmpty==true?NetworkImage(r['other_image'].toString()):null,child:r['other_image']?.toString().isNotEmpty==true?null:Icon(video?Icons.videocam:Icons.call)),title:Text(r['other_name']?.toString()??'زميل',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${incoming?'واردة':'صادرة'} • ${_statusLabel(r['status']?.toString()??'')} • ${duration~/60}:${(duration%60).toString().padLeft(2,'0')}'),if(created!=null)Text(DateFormat('yyyy/MM/dd • HH:mm').format(created),style:const TextStyle(fontSize:11)),Wrap(spacing:4,children:[TextButton(onPressed:()=>_recall(r,false),child:const Text('إعادة الاتصال: صوتي',style:TextStyle(fontSize:11))),TextButton(onPressed:()=>_recall(r,true),child:const Text('فيديو',style:TextStyle(fontSize:11)))])]),isThreeLine:true);}))])));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل سجل المكالمات: $e')));}
  }
  String _statusLabel(String v)=>{'ringing':'يرن','active':'جارية','ended':'مكتملة','declined':'مرفوضة','missed':'فائتة','cancelled':'ملغاة','failed':'فشلت'}[v]??v;
  Future<void> _recall(Map<String,dynamic> row,bool video) async{Navigator.pop(context);final contact=_PhoneContact(name:row['other_name']?.toString()??'زميل',phone:'',hash:'',photo:null)..zameel={'user_id':row['other_user_id'],'name':row['other_name'],'allow_calls':true};await _call(contact,video);}

  @override
  void initState() { super.initState(); ScreenAwakeService.enterPersistent(); _load(); }
  @override
  void dispose() { ScreenAwakeService.exitPersistent(); _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final allowed = await FlutterContacts.requestPermission(readonly: true);
      if (!allowed) { if (mounted) setState(() { _permissionDenied=true; _loading=false; }); return; }
      final raw = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
      final contacts = <_PhoneContact>[];
      final hashes = <String>[];
      for (final c in raw) {
        for (final p in c.phones) {
          if (p.number.trim().isEmpty) continue;
          final hash = _hash(p.number);
          hashes.add(hash);
          contacts.add(_PhoneContact(name: c.displayName.trim().isEmpty ? p.number : c.displayName, phone: p.number, hash: hash, photo: c.photo));
        }
      }
      final uniqueHashes = hashes.toSet().toList();
      final matches = <String, Map<String, dynamic>>{};
      for (var start = 0; start < uniqueHashes.length; start += 200) {
        final end = start + 200 < uniqueHashes.length ? start + 200 : uniqueHashes.length;
        final result = await Supabase.instance.client.rpc(
          'match_registered_contacts',
          params: {'contact_hashes': uniqueHashes.sublist(start, end)},
        );
        for (final row in List<Map<String, dynamic>>.from(result as List)) {
          matches[row['phone_hash'].toString()] = row;
        }
      }
      for (final c in contacts) { c.zameel = matches[c.hash]; }
      contacts.sort((a,b) { final ar=a.zameel!=null?0:1; final br=b.zameel!=null?0:1; return ar!=br ? ar.compareTo(br) : a.name.compareTo(b.name); });
      if (mounted) setState(() { _contacts=contacts; _loading=false; });
    } catch (e) {
      if (mounted) { setState(() => _loading=false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل جهات الاتصال: $e'))); }
    }
  }

  Future<void> _invite(_PhoneContact c) async {
    final share = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('هذا الشخص غير مسجل في زميل'),
      content: Text('الرقم ${c.phone} غير مرتبط بحساب زميل حتى الآن. يمكنك دعوة ${c.name} للانضمام والتواصل معك عبر التطبيق.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('لاحقًا')), FilledButton.icon(onPressed: () => Navigator.pop(ctx,true), icon: const Icon(Icons.ios_share), label: const Text('إرسال دعوة'))],
    ));
    if (share == true) await SharePlus.instance.share(ShareParams(text: 'انضم إليّ على تطبيق زميل، مجتمع الطلبة للتواصل والتعاون: https://zameel.app'));
  }

  Future<void> _call(_PhoneContact c, bool video) async {
    if (!await FeatureControl.instance.check(context, 'direct_calls')) return;
    final u=c.zameel; if (u==null) { await _invite(c); return; }
    if (u['allow_calls']==false) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا المستخدم لا يسمح بالمكالمات حاليًا.'))); return; }
    try {
      final id=u['user_id'].toString();
      final conversation=(await Supabase.instance.client.rpc('create_contact_conversation',params:{'other_user_id':id})).toString();
      final room='contact:$conversation:${DateTime.now().microsecondsSinceEpoch}';
      await Supabase.instance.client.rpc('start_contact_call',params:{'other_user_id':id,'target_conversation_id':conversation,'target_room_id':room,'with_video':video});
      if (!mounted) return;
      Navigator.push(context,MaterialPageRoute(builder:(_)=>MeetScreen(participantName:u['name']?.toString()??c.name,roomId:room,startImmediately:true,startWithVideo:video,isInitiator:true)));
    } on PostgrestException catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message.contains('calls_disabled')?'هذا المستخدم لا يسمح بالمكالمات حاليًا.':'تعذر بدء المكالمة: ${e.message}'))); }
  }

  @override
  Widget build(BuildContext context) {
    final q=_search.text.trim().toLowerCase();
    final shown=_contacts.where((c)=>c.name.toLowerCase().contains(q)||c.phone.contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('الاتصال عبر زميل'),actions:[IconButton(tooltip:'سجل المكالمات',onPressed:_showHistory,icon:const Icon(Icons.history_rounded))]),
      body: _loading ? const Center(child:CircularProgressIndicator()) : _permissionDenied ? Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.contacts_outlined,size:64),const SizedBox(height:12),const Text('يلزم السماح بالوصول إلى جهات الاتصال لعرض الأسماء والعثور على المسجلين في زميل.',textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:_load,child:const Text('السماح وإعادة المحاولة'))]))) : Column(children:[
        Padding(padding:const EdgeInsets.all(12),child:TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث بالاسم أو الرقم',border:OutlineInputBorder()))),
        Expanded(child:ListView.separated(itemCount:shown.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final c=shown[i];final registered=c.zameel!=null;return ListTile(
          leading:CircleAvatar(backgroundImage:c.photo!=null?MemoryImage(c.photo!):null,child:c.photo==null?const Icon(Icons.person):null),
          title:Text(c.name),subtitle:Text(registered?'مسجل في زميل • ${c.phone}':'غير مسجل • ${c.phone}'),
          trailing:Wrap(children:[IconButton(tooltip:'مكالمة صوتية',onPressed:()=>_call(c,false),icon:Icon(Icons.call,color:registered?Colors.green:null)),IconButton(tooltip:'مكالمة فيديو',onPressed:()=>_call(c,true),icon:Icon(Icons.videocam,color:registered?Colors.blue:null))]),
          onTap:registered?()=>_call(c,false):()=>_invite(c),
        );})),
      ]),
    );
  }
}

class _PhoneContact {
  final String name; final String phone; final String hash; final Uint8List? photo;
  Map<String,dynamic>? zameel;
  _PhoneContact({required this.name,required this.phone,required this.hash,required this.photo});
}
