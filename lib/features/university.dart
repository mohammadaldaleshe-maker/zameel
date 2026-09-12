part of '../main.dart';

class University {
  final String name;
  final String type;
  final String city;
  final List<College> colleges;

  const University({
    required this.name,
    required this.type,
    required this.city,
    required this.colleges,
  });
}

class College {
  final String name;
  final List<String> departments;

  const College({
    required this.name,
    required this.departments,
  });
}

// ============================================================
// ✅ جميع الجامعات الأردنية (حكومية + خاصة)
// ============================================================

const List<University> universities = [
  // ============================================================
  // الجامعات الحكومية
  // ============================================================

  // 1. الجامعة الأردنية
  University(
    name: 'الجامعة الأردنية',
    type: 'حكومية',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
          'الجراحة العامة',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
          'الصيدلة السريرية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
          'التمريض الصحي',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'الهندسة الصناعية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
          'نظم المعلومات الإدارية',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
          'اللغات الحديثة',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
      College(
        name: 'كلية التربية',
        departments: [
          'المناهج',
          'الإدارة التربوية',
          'علم النفس',
        ],
      ),
      College(
        name: 'كلية الإعلام',
        departments: [
          'الصحافة',
          'الإذاعة والتلفزيون',
          'العلاقات العامة',
        ],
      ),
      College(
        name: 'كلية الآثار والسياحة',
        departments: [
          'إدارة المواقع الأثرية',
          'السياحة',
        ],
      ),
    ],
  ),

  // 2. جامعة العلوم والتكنولوجيا الأردنية
  University(
    name: 'جامعة العلوم والتكنولوجيا الأردنية',
    type: 'حكومية',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
          'الجراحة العامة',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
          'الصيدلة السريرية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية العلوم الطبية المساندة',
        departments: [
          'المختبرات الطبية',
          'الأشعة',
          'العلاج الطبيعي',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الحاسوب',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
          'علم البيانات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
    ],
  ),

  // 3. جامعة اليرموك
  University(
    name: 'جامعة اليرموك',
    type: 'حكومية',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'الهندسة الصناعية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
      College(
        name: 'كلية التربية',
        departments: [
          'المناهج',
          'الإدارة التربوية',
          'علم النفس',
        ],
      ),
      College(
        name: 'كلية الإعلام',
        departments: [
          'الصحافة',
          'الإذاعة والتلفزيون',
        ],
      ),
      College(
        name: 'كلية الآثار والسياحة',
        departments: [
          'إدارة المواقع الأثرية',
          'السياحة',
        ],
      ),
    ],
  ),

  // 4. الجامعة الهاشمية
  University(
    name: 'الجامعة الهاشمية',
    type: 'حكومية',
    city: 'الزرقاء',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 5. جامعة مؤتة
  University(
    name: 'جامعة مؤتة',
    type: 'حكومية',
    city: 'الكرك',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
    ],
  ),

  // 6. جامعة آل البيت
  University(
    name: 'جامعة آل البيت',
    type: 'حكومية',
    city: 'المفرق',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 7. جامعة البلقاء التطبيقية
  University(
    name: 'جامعة البلقاء التطبيقية',
    type: 'حكومية',
    city: 'السلط',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 8. جامعة الحسين بن طلال
  University(
    name: 'جامعة الحسين بن طلال',
    type: 'حكومية',
    city: 'معان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
    ],
  ),

  // 9. جامعة الطفيلة التقنية
  University(
    name: 'جامعة الطفيلة التقنية',
    type: 'حكومية',
    city: 'الطفيلة',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
    ],
  ),

  // 10. الجامعة الألمانية الأردنية
  University(
    name: 'الجامعة الألمانية الأردنية',
    type: 'حكومية',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الحاسوب',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة الإنجليزية',
          'اللغات الحديثة',
        ],
      ),
    ],
  ),

  // 11. جامعة الأميرة سمية للتكنولوجيا
  University(
    name: 'جامعة الأميرة سمية للتكنولوجيا',
    type: 'حكومية',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الحاسوب',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
          'علم البيانات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التمويل',
        ],
      ),
    ],
  ),

  // ============================================================
  // الجامعات الخاصة
  // ============================================================

  // 12. جامعة عمان الأهلية
  University(
    name: 'جامعة عمان الأهلية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 13. جامعة الزيتونة الأردنية
  University(
    name: 'جامعة الزيتونة الأردنية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 14. جامعة العلوم التطبيقية الخاصة
  University(
    name: 'جامعة العلوم التطبيقية الخاصة',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الطب',
        departments: [
          'الطب العام',
        ],
      ),
      College(
        name: 'كلية طب الأسنان',
        departments: [
          'جراحة الفم والأسنان',
        ],
      ),
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية التمريض',
        departments: [
          'التمريض العام',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 15. جامعة فيلادلفيا
  University(
    name: 'جامعة فيلادلفيا',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 16. جامعة الشرق الأوسط
  University(
    name: 'جامعة الشرق الأوسط',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الذكاء الاصطناعي',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
          'التمويل',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 17. جامعة عمان العربية
  University(
    name: 'جامعة عمان العربية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 18. جامعة الزرقاء
  University(
    name: 'جامعة الزرقاء',
    type: 'خاصة',
    city: 'الزرقاء',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 19. جامعة جدارا
  University(
    name: 'جامعة جدارا',
    type: 'خاصة',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 20. جامعة إربد الأهلية
  University(
    name: 'جامعة إربد الأهلية',
    type: 'خاصة',
    city: 'إربد',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 21. جامعة جرش
  University(
    name: 'جامعة جرش',
    type: 'خاصة',
    city: 'جرش',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 22. جامعة البترا
  University(
    name: 'جامعة البترا',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الصيدلة',
        departments: [
          'العلوم الصيدلانية',
        ],
      ),
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 23. جامعة الإسراء
  University(
    name: 'جامعة الإسراء',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'الهندسة الكهربائية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 24. جامعة العلوم الإسلامية العالمية
  University(
    name: 'جامعة العلوم الإسلامية العالمية',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الشريعة الإسلامية',
        departments: [
          'الفقه الإسلامي',
          'أصول الدين',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية القانون',
        departments: [
          'القانون العام',
          'القانون الخاص',
        ],
      ),
    ],
  ),

  // 25. الجامعة العربية المفتوحة
  University(
    name: 'الجامعة العربية المفتوحة',
    type: 'خاصة',
    city: 'عمّان',
    colleges: [
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 26. جامعة عجلون الوطنية
  University(
    name: 'جامعة عجلون الوطنية',
    type: 'خاصة',
    city: 'عجلون',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 27. الجامعة الأمريكية في مادبا
  University(
    name: 'الجامعة الأمريكية في مادبا',
    type: 'خاصة',
    city: 'مادبا',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة المعمارية',
          'هندسة البرمجيات',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التسويق',
        ],
      ),
      College(
        name: 'كلية اللغات',
        departments: [
          'اللغة العربية وآدابها',
          'اللغة الإنجليزية',
        ],
      ),
    ],
  ),

  // 28. جامعة العقبة للتكنولوجيا
  University(
    name: 'جامعة العقبة للتكنولوجيا',
    type: 'خاصة',
    city: 'العقبة',
    colleges: [
      College(
        name: 'كلية الهندسة',
        departments: [
          'الهندسة المدنية',
          'الهندسة الكهربائية',
          'الهندسة الميكانيكية',
          'هندسة البرمجيات',
          'هندسة الطاقة المتجددة',
        ],
      ),
      College(
        name: 'كلية تكنولوجيا المعلومات',
        departments: [
          'علوم الحاسوب',
          'تكنولوجيا المعلومات',
          'الأمن السيبراني',
        ],
      ),
      College(
        name: 'كلية الأعمال',
        departments: [
          'إدارة الأعمال',
          'المحاسبة',
          'التمويل',
        ],
      ),
    ],
  ),
];

// ============================================================
// UNIVERSITY SCREEN (مع زر رجوع)
// ============================================================

class UniversityScreen extends StatefulWidget {
  const UniversityScreen({super.key});

  @override
  State<UniversityScreen> createState() => _UniversityScreenState();
}

class _UniversityScreenState extends State<UniversityScreen> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    final filtered = universities.where((u) {
      return u.name.contains(search) || u.city.contains(search);
    }).toList();

    final government = filtered
        .where((u) => u.type == 'حكومية')
        .toList();

    final private = filtered
        .where((u) => u.type == 'خاصة')
        .toList();

    return Directionality(
      textDirection: languageProvider.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            Translations.translate(
              'university_title',
              languageProvider.currentLanguage,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: Translations.translate(
                      'university_search',
                      languageProvider.currentLanguage,
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor: AppTheme.glassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              if (government.isNotEmpty) ...[
                Text(
                  Translations.translate(
                    'university_government',
                    languageProvider.currentLanguage,
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...government.map(
                  (u) => _UniversityCard(
                    university: u,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (private.isNotEmpty) ...[
                Text(
                  Translations.translate(
                    'university_private',
                    languageProvider.currentLanguage,
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...private.map(
                  (u) => _UniversityCard(
                    university: u,
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

class _UniversityCard extends StatelessWidget {
  final University university;

  const _UniversityCard({
    required this.university,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.white.withAlpha(51),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
          ),
        ),
        title: Text(
          translateText(
            university.name,
            languageProvider.currentLanguage,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          isArabic
              ? '📍 ${university.city} - ${university.type}'
              : '📍 ${university.city} - ${university.type}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.white70,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollegeScreen(
                university: university,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// COLLEGE SCREEN (مع زر رجوع)
// ============================================================

class CollegeScreen extends StatelessWidget {
  final University university;

  const CollegeScreen({
    super.key,
    required this.university,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            Translations.translate(
              'college_title',
              languageProvider.currentLanguage,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                child: Text(
                  translateText(
                    university.name,
                    languageProvider.currentLanguage,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...university.colleges.map(
                (college) => GlassContainer(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withAlpha(51),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      translateText(
                        college.name,
                        languageProvider.currentLanguage,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DepartmentScreen(
                            university: university,
                            college: college,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DEPARTMENT SCREEN (مع زر رجوع)
// ============================================================

class DepartmentScreen extends StatelessWidget {
  final University university;
  final College college;

  const DepartmentScreen({
    super.key,
    required this.university,
    required this.college,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            Translations.translate(
              'department_title',
              languageProvider.currentLanguage,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                child: Text(
                  translateText(
                    college.name,
                    languageProvider.currentLanguage,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...college.departments.map(
                (department) => GlassContainer(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withAlpha(51),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      translateText(
                        department,
                        languageProvider.currentLanguage,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),

                    // حفظ الجامعة والكلية والتخصص ثم الانتقال للرئيسية
                    onTap: () async {
                      final user =
                          Supabase.instance.client.auth.currentUser;

                      if (user == null) {
                        return;
                      }

                      try {
                        await Supabase.instance.client
                            .from('users')
                            .update({
                          'university': university.name,
                          'college': college.name,
                          'department': department,
                        }).eq('id', user.id);

                        if (!context.mounted) return;

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeFeedScreen(
                              university: university,
                              college: college,
                              department: department,
                            ),
                          ),
                        );
                      } catch (e) {
                        debugPrint(
                          'Error saving university/college/department: $e',
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'حدث خطأ أثناء حفظ بيانات الجامعة والتخصص: $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME FEED SCREEN (معدل بالكامل)
// ============================================================

