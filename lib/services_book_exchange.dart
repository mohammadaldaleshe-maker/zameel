import 'package:supabase_flutter/supabase_flutter.dart';

class ZameelBookExchangeService {
  static final SupabaseClient db = Supabase.instance.client;
  static String? get uid => db.auth.currentUser?.id;

  static Future<List<Map<String, dynamic>>> listBooks() async {
    if (uid == null) return [];
    final rows = await db
        .from('book_listings')
        .select('*, owner:users!book_listings_owner_id_fkey(id,name,profile_image)')
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
  }) async {
    final me = uid;
    if (me == null) throw Exception('Authentication required');
    await db.from('book_listings').insert({
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
    });
  }

  static Future<void> requestBook(Map<String, dynamic> book) async {
    final me = uid;
    final listingId = book['id']?.toString() ?? '';
    final ownerId = book['owner_id']?.toString() ?? '';
    if (me == null || listingId.isEmpty) throw Exception('Invalid listing');
    if (ownerId == me) throw Exception('لا يمكنك طلب كتابك');

    String? offeredId;
    if (_canonicalType(book['type_en']?.toString() ?? '') == 'exchange') {
      final mine = await db
          .from('book_listings')
          .select('id')
          .eq('owner_id', me)
          .eq('status', 'available')
          .neq('id', listingId)
          .limit(1);
      if (mine.isEmpty) {
        throw Exception('اعرض كتاباً لك أولاً حتى تتمكن من المبادلة');
      }
      offeredId = mine.first['id']?.toString();
    }

    await db.rpc('request_book_exchange', params: {
      'target_listing_id': listingId,
      'offered_listing_id': offeredId,
    });
  }

  static Future<List<Map<String, dynamic>>> incomingRequests() async {
    if (uid == null) return [];
    final rows = await db.rpc('get_incoming_book_requests');
    return List<Map<String, dynamic>>.from(rows as List? ?? const []);
  }

  static Future<void> respond(String requestId, {required bool accept}) async {
    await db.rpc('respond_book_exchange', params: {
      'target_request_id': requestId,
      'accept_request': accept,
    });
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
