import 'package:supabase_flutter/supabase_flutter.dart';

class ZameelBookExchangeService {
  static final SupabaseClient db = Supabase.instance.client;
  static String? get uid => db.auth.currentUser?.id;

  static Future<List<Map<String, dynamic>>> listBooks() async {
    if (uid == null) return [];
    final rows = await db
        .from('book_listings')
        .select('*, owner:users!book_listings_owner_id_fkey(id,name,profile_image,university,college,department)')
        .eq('status', 'available')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows).map(_toUiBook).toList();
  }

  static Future<void> createBook({
    required String title,
    required String author,
    required String subject,
    required String university,
    required String college,
    required String department,
    required String offerType,
    required String condition,
    required String description,
    String price = '',
    String contactPhone = '',
  }) async {
    final me = uid;
    if (me == null) throw Exception('Authentication required');
    final listing = await db.from('book_listings').insert({
      'owner_id': me,
      'title': title,
      'author': author,
      'subject': subject,
      'university': university,
      'college': college,
      'department': department,
      'offer_type': _canonicalType(offerType),
      'book_condition': condition,
      'description': description,
      'price_label': price,
    }).select('id').single();
    if (contactPhone.trim().isNotEmpty) {
      await db.from('book_listing_contacts').insert({
        'listing_id': listing['id'],
        'owner_id': me,
        'phone': contactPhone.trim(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> myAvailableBooks() async {
    final me = uid;
    if (me == null) return [];
    final rows = await db.from('book_listings').select('id,title,author').eq('owner_id', me).eq('status', 'available').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> requestBook(Map<String, dynamic> book, {required String message}) async {
    final me = uid;
    final listingId = book['id']?.toString() ?? '';
    final ownerId = book['owner_id']?.toString() ?? '';
    if (me == null || listingId.isEmpty) throw Exception('Invalid listing');
    if (ownerId == me) throw Exception('لا يمكنك طلب كتابك');

    if (message.trim().isEmpty) throw Exception('اكتب رسالة لصاحب الكتاب');
    await db.rpc('request_book_simple', params: {
      'target_listing_id': listingId,
      'initial_message': message.trim(),
    });
  }

  static Future<List<Map<String, dynamic>>> myLibrary() async {
    if (uid == null) return [];
    final rows = await db.rpc('get_my_book_library');
    return List<Map<String, dynamic>>.from(rows as List? ?? const []);
  }

  static Future<Map<String, dynamic>> myLibrarySummary() async {
    if (uid == null) return <String, dynamic>{};
    final rows = await db.rpc('get_my_book_library_summary');
    if (rows is List && rows.isNotEmpty) return Map<String, dynamic>.from(rows.first as Map);
    return <String, dynamic>{};
  }

  static Future<void> addOwnedOrReadBook({required String title, required bool read}) async {
    if (title.trim().isEmpty) throw Exception('book_title_required');
    await db.rpc('add_personal_book', params: {'book_title': title.trim(), 'is_read': read});
  }

  static Future<void> removeLibraryBook(String entryId) async {
    await db.rpc('remove_my_library_book', params: {'target_entry_id': entryId});
  }

  static Future<void> withdrawBook(String listingId) async {
    await db.rpc('withdraw_my_book_listing', params: {'target_listing_id': listingId});
  }

  static Future<List<Map<String, dynamic>>> bookRequests() async {
    if (uid == null) return [];
    final rows = await db.rpc('get_book_requests');
    return List<Map<String, dynamic>>.from(rows as List? ?? const []);
  }

  static Future<void> respond(String requestId, {required bool accept}) async {
    await db.rpc('respond_book_exchange', params: {
      'target_request_id': requestId,
      'accept_request': accept,
    });
  }

  static Future<Map<String, dynamic>> openAcceptedConversation(String requestId) async {
    final rows = await db.rpc('get_or_create_book_conversation', params: {
      'target_request_id': requestId,
    });
    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    throw Exception('accepted_book_conversation_unavailable');
  }

  static Future<List<Map<String, dynamic>>> requestMessages(String requestId) async {
    final rows = await db.rpc('get_book_request_messages', params: {'target_request_id': requestId});
    return List<Map<String, dynamic>>.from(rows as List? ?? const []);
  }

  static Future<void> sendRequestMessage(String requestId, String message) async {
    if (message.trim().isEmpty) return;
    await db.rpc('send_book_request_message', params: {
      'target_request_id': requestId,
      'message_text': message.trim(),
    });
  }

  static Future<Map<String, dynamic>> requestContact(String requestId) async {
    final rows = await db.rpc('get_book_request_contact', params: {'target_request_id': requestId});
    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return <String, dynamic>{};
  }

  static Future<void> completeRequest(String requestId) async {
    await db.rpc('complete_book_exchange', params: {'target_request_id': requestId});
  }

  static Map<String, dynamic> _toUiBook(Map<String, dynamic> row) => {
        ...row,
        'title_ar': row['title'],
        'title_en': row['title'],
        'author_ar': row['author'],
        'author_en': row['author'],
        'subject_ar': row['subject'],
        'subject_en': row['subject'],
        'university_ar': row['university'],
        'university_en': row['university'],
        'college_ar': row['college'],
        'college_en': row['college'],
        'department_ar': row['department'],
        'department_en': row['department'],
        'type_ar': _arabicType(row['offer_type']?.toString() ?? ''),
        'type_en': _englishType(row['offer_type']?.toString() ?? ''),
        'condition_ar': row['book_condition'],
        'condition_en': row['book_condition'],
        'description_ar': row['description']?.toString().isNotEmpty == true ? row['description'] : 'لا يوجد وصف',
        'description_en': row['description']?.toString().isNotEmpty == true ? row['description'] : 'No description',
        'price': row['price_label']?.toString() ?? '',
        'owner_name': (row['owner'] as Map?)?['name']?.toString() ?? 'زميل',
        'owner_image': (row['owner'] as Map?)?['profile_image']?.toString() ?? '',
        'owner_university': (row['owner'] as Map?)?['university']?.toString() ?? '',
        'owner_college': (row['owner'] as Map?)?['college']?.toString() ?? '',
      };

  static String _canonicalType(String value) {
    if (value == 'مبادلة' || value.toLowerCase() == 'exchange') return 'exchange';
    if (value == 'إعارة' || value.toLowerCase() == 'lend') return 'lend';
    if (value == 'تبرع' || value.toLowerCase() == 'donate') return 'donate';
    return 'sale';
  }

  static String _arabicType(String value) => switch (value) {
        'exchange' => 'مبادلة',
        'lend' => 'إعارة',
        'donate' => 'تبرع',
        _ => 'بيع',
      };

  static String _englishType(String value) => switch (value) {
        'exchange' => 'Exchange',
        'lend' => 'Lend',
        'donate' => 'Donate',
        _ => 'Sale',
      };
}
