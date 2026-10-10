import '../../services/jordan_phone.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart' show University, College, universities;
import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import 'contact_verification_screen.dart';

/// Account type describes the member, never an administrative permission.
class OpenRegistrationScreen extends StatefulWidget {
  const OpenRegistrationScreen({super.key});
  @override
  State<OpenRegistrationScreen> createState() => _OpenRegistrationScreenState();
}

class _OpenRegistrationScreenState extends State<OpenRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _father = TextEditingController();
  final _family = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _number = TextEditingController();
  final _password = TextEditingController();
  String _kind = 'general';
  String _gender = 'male';
  String _format = 'first_family';

  String _degree = 'bachelor';
  University? _university;
  College? _college;
  String? _major;
  bool get _resume => Supabase.instance.client.auth.currentUser != null;
  bool get _ar => context.read<LanguageProvider>().isArabic;
  String _t(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final saved = user?.userMetadata?['registration'];
    if (saved is Map) {
      final names = saved['fullName'];
      if (names is Map) {
        _first.text = '${names['firstName'] ?? ''}';
        _father.text = '${names['fatherName'] ?? ''}';
        _family.text = '${names['familyName'] ?? ''}';
      }
      _kind = saved['accountType'] == 'student' ? 'student' : 'general';
      _gender = saved['gender'] == 'female' ? 'female' : 'male';
      _format = [
        'first_family',
        'first_father',
        'full_three',
      ].contains(saved['displayNameFormat'])
          ? saved['displayNameFormat'].toString()
          : 'first_family';
      _degree = [
        'bachelor',
        'master',
        'doctorate',
        'diploma',
        'higher_diploma',
        'associate_first',
        'associate_second'
      ].contains(saved['academicDegree'])
          ? saved['academicDegree'].toString()
          : 'bachelor';
      _number.text = '${saved['studentNumber'] ?? ''}';
      _phone.text = '${saved['phone'] ?? ''}';
      _email.text = '${saved['email'] ?? ''}';
      for (final u in universities) {
        if (u.name != saved['university']) continue;
        _university = u;
        for (final c in u.colleges) {
          if (c.name != saved['college']) continue;
          _college = c;
          if (c.departments.contains(saved['department']))
            _major = saved['department'].toString();
        }
      }
    }
    if (user?.email?.isNotEmpty == true) {
      _email.text = user!.email!;
    } else if (user?.phone?.isNotEmpty == true) {
      _phone.text = '+${user!.phone!.replaceAll('+', '')}';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _first,
      _father,
      _family,
      _email,
      _phone,
      _number,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool secret = false,
    bool readOnly = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          obscureText: secret,
          readOnly: readOnly,
          keyboardType: keyboard,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: validator ??
              (v) => (v?.trim().length ?? 0) < 2
                  ? _t('أدخل الحقل بصورة صحيحة', 'Enter a valid value')
                  : null,
        ),
      );

  Widget _select(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> changed,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: choices.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => changed(v));
          },
        ),
      );

  void _next() {
    if (!_form.currentState!.validate()) return;
    final names = {
      'firstName': _first.text.trim(),
      'fatherName': _father.text.trim(),
      'familyName': _family.text.trim(),
    };
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContactVerificationScreen(
          userData: {
            'fullName': names,
            'fullDisplayName': names.values.join(' '),
            'role': _kind == 'student' ? 'student' : 'visitor',
            'accountType': _kind,
            'gender': _gender,
            'displayNameFormat': _format,
            'verificationMethod': 'email',
            'phone': _phone.text.trim(),
            'email': _email.text.trim().toLowerCase(),
            'password': _password.text,
            'university': _kind == 'student' ? _university?.name : null,
            'college': _kind == 'student' ? _college?.name : null,
            'department': _kind == 'student' ? _major : null,
            'academicDegree': _kind == 'student' ? _degree : null,
            'studentNumber': _kind == 'student' ? _number.text.trim() : null,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final ar = _ar;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t(
              _resume ? 'إكمال التسجيل' : 'إنشاء حساب',
              _resume ? 'Complete registration' : 'Create account',
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.signatureGradient),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          Text(
                            _t('زميل متاح للجميع', 'Zameel welcomes everyone'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          _select(
                              _t('نوع الحساب', 'Account type'),
                              _kind,
                              {
                                'general': _t('عضو مجتمع', 'Community member'),
                                'student': _t('طالب', 'Student'),
                              },
                              (v) => _kind = v),
                          _field(_first, _t('الاسم الأول', 'First name')),
                          _field(_father, _t('اسم الأب', 'Father name')),
                          _field(_family, _t('اسم العائلة', 'Family name')),
                          _select(
                              _t('الاسم الظاهر', 'Display name'),
                              _format,
                              {
                                'first_family': _t(
                                  'الأول والعائلة',
                                  'First and family',
                                ),
                                'first_father': _t(
                                  'الأول والأب',
                                  'First and father',
                                ),
                                'full_three': _t('الاسم الثلاثي', 'Full name'),
                              },
                              (v) => _format = v),
                          _select(
                              _t('الجنس', 'Gender'),
                              _gender,
                              {
                                'male': _t('ذكر', 'Male'),
                                'female': _t('أنثى', 'Female'),
                              },
                              (v) => _gender = v),
                          if (_kind == 'student') ...[
                            DropdownButtonFormField<University>(
                              initialValue: _university,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _t('الجامعة', 'University'),
                              ),
                              items: universities
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u.name),
                                    ),
                                  )
                                  .toList(),
                              validator: (v) => v == null
                                  ? _t('اختر الجامعة', 'Choose a university')
                                  : null,
                              onChanged: (v) => setState(() {
                                _university = v;
                                _college = null;
                                _major = null;
                              }),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<College>(
                              key: ValueKey(_university?.name),
                              initialValue: _college,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _t('الكلية', 'College'),
                              ),
                              items: (_university?.colleges ?? <College>[])
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              validator: (v) => v == null
                                  ? _t('اختر الكلية', 'Choose a college')
                                  : null,
                              onChanged: (v) => setState(() {
                                _college = v;
                                _major = null;
                              }),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                '${_university?.name}:${_college?.name}',
                              ),
                              initialValue: _major,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _t('التخصص', 'Major'),
                              ),
                              items: (_college?.departments ?? <String>[])
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                              validator: (v) => v == null
                                  ? _t('اختر التخصص', 'Choose a major')
                                  : null,
                              onChanged: (v) => setState(() => _major = v),
                            ),
                            const SizedBox(height: 14),
                            _select(
                                _t('الدرجة', 'Degree'),
                                _degree,
                                {
                                  'bachelor': _t('بكالوريوس', 'Bachelor'),
                                  'master': _t('ماجستير', 'Master'),
                                  'doctorate': _t('دكتوراه', 'Doctorate'),
                                  'diploma': _t('دبلوم متوسط / فني / بيرسون',
                                      'Intermediate / technical / Pearson diploma'),
                                  'higher_diploma':
                                      _t('دبلوم عالٍ', 'Higher diploma'),
                                  'associate_first': _t(
                                      'الدرجة الجامعية المتوسطة الأولى',
                                      'First associate degree'),
                                  'associate_second': _t(
                                      'الدرجة الجامعية المتوسطة الثانية',
                                      'Second associate degree'),
                                },
                                (v) => _degree = v),
                            _field(
                              _number,
                              _t('الرقم الجامعي', 'Student number'),
                            ),
                          ],
                          _field(
                            _email,
                            _t('البريد الإلكتروني', 'Email'),
                            keyboard: TextInputType.emailAddress,
                            readOnly: _resume &&
                                Supabase.instance.client.auth.currentUser?.email
                                        ?.isNotEmpty ==
                                    true,
                            validator: (v) =>
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(v?.trim() ?? '')
                                    ? null
                                    : _t(
                                        'أدخل بريدًا صحيحًا',
                                        'Enter a valid email',
                                      ),
                          ),
                          _field(
                            _phone,
                            _t('رقم الهاتف الأردني', 'Jordanian phone'),
                            keyboard: TextInputType.phone,
                            readOnly: _resume &&
                                Supabase.instance.client.auth.currentUser?.phone
                                        ?.isNotEmpty ==
                                    true,
                            validator: (v) => normalizeJordanMobile(v ?? '') !=
                                    null
                                ? null
                                : _t('مثال: 0791234567', 'Example: 0791234567'),
                          ),
                          if (!_resume) ...[
                            _field(
                              _password,
                              _t('كلمة المرور', 'Password'),
                              secret: true,
                              validator: (v) => (v?.length ?? 0) < 8
                                  ? _t(
                                      '8 أحرف على الأقل',
                                      'At least 8 characters',
                                    )
                                  : null,
                            ),
                          ],
                          Text(
                            _t(
                              'التحقق بالبريد الإلكتروني فقط. رقم الهاتف مطلوب دون إرسال رمز إليه.',
                              'Email verification only. A phone number is required without phone verification.',
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _next,
                              child: Text(
                                _t('متابعة والتحقق', 'Continue and verify'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
