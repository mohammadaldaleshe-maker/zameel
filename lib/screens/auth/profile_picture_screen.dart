import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/language_provider.dart';
import '../../main.dart';

// ============================================================
// COLORS
// ============================================================

const Color primaryColor = Color(0xFF6C63FF);
const Color gradientStart = Color(0xFF6C63FF);
const Color gradientEnd = Color(0xFF4A3B8A);

// ============================================================
// GLASS CONTAINER
// ============================================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x33FFFFFF),
            Color(0x1AFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0x66FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================
// PROFILE PICTURE SCREEN
// ============================================================

class ProfilePictureScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfilePictureScreen({
    super.key,
    required this.userData,
  });

  @override
  State<ProfilePictureScreen> createState() =>
      _ProfilePictureScreenState();
}

class _ProfilePictureScreenState
    extends State<ProfilePictureScreen> {
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSkipped = false;

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _isSkipped = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      Fluttertoast.showToast(
        msg: '❌ فشل اختيار الصورة',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      debugPrint(
        'Image picker error: $e',
      );
    }
  }

  // ============================================================
  // COMPLETE PROFILE SETUP
  // ============================================================

  Future<void> _completeRegistration() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // ========================================================
      // GET CURRENT AUTH USER
      // ========================================================

      final user = supabase.auth.currentUser;

      if (user == null) {
        throw const AuthException(
          'لم يتم العثور على المستخدم الحالي.',
        );
      }

      // ========================================================
      // PREPARE FULL NAME
      // ========================================================

      final rawFullName =
          widget.userData['fullName'];

      final Map<String, dynamic> fullName =
          rawFullName is Map
              ? Map<String, dynamic>.from(rawFullName)
              : <String, dynamic>{};

      final firstName =
          (fullName['firstName'] ?? '')
              .toString()
              .trim();

      final fatherName =
          (fullName['fatherName'] ?? '')
              .toString()
              .trim();

      final grandfatherName =
          (fullName['grandfatherName'] ?? '')
              .toString()
              .trim();

      final familyName =
          (fullName['familyName'] ?? '')
              .toString()
              .trim();

      final nameParts = [
        firstName,
        fatherName,
        grandfatherName,
        familyName,
      ].where(
        (part) => part.isNotEmpty,
      ).toList();

      final fullNameText =
          nameParts.isEmpty
              ? (
                  user.userMetadata?['name'] ??
                  'مستخدم'
                ).toString()
              : nameParts.join(' ');

      // ========================================================
      // SAVE USER PROFILE
      // ========================================================

      await supabase.from('users').upsert(
        {
          'id': user.id,
          'email': user.email ??
              (widget.userData['email'] ?? '')
                  .toString(),
          'name': fullNameText,
          'university':
              (widget.userData['university'] ?? '')
                  .toString(),
          'college':
              (widget.userData['college'] ?? '')
                  .toString(),
          'department':
              (widget.userData['department'] ?? '')
                  .toString(),
        },
        onConflict: 'id',
      );

      // ========================================================
      // PROFILE IMAGE
      // ========================================================
      //
      // اختيار الصورة يعمل حاليًا.
      // ربط Supabase Storage سيتم بعد تجهيز bucket والسياسات.
      //

      if (_selectedImage != null &&
          _selectedImageBytes != null &&
          !_isSkipped) {
        debugPrint(
          'Profile image selected: '
          '${_selectedImage!.name}',
        );

        // TODO:
        // رفع الصورة إلى Supabase Storage
        //
        // وبعد تجهيز bucket:
        //
        // final path =
        //     'profile_images/${user.id}.jpg';
        //
        // await supabase.storage
        //     .from('profiles')
        //     .uploadBinary(
        //       path,
        //       _selectedImageBytes!,
        //       fileOptions: const FileOptions(
        //         upsert: true,
        //       ),
        //     );
        //
        // final imageUrl = supabase.storage
        //     .from('profiles')
        //     .getPublicUrl(path);
        //
        // await supabase.from('users').update({
        //   'profile_image': imageUrl,
        // }).eq('id', user.id);
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) {
        return;
      }

      Fluttertoast.showToast(
        msg: '🎉 تم إكمال إعداد حسابك بنجاح!',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // ========================================================
      // GO TO AUTH GATE
      // ========================================================
      //
      // AuthGate موجود في main.dart ويقوم بقراءة
      // بيانات users ثم تحديد HomeFeedScreen.
      //
      // pushAndRemoveUntil يمنع الرجوع إلى:
      // PasswordScreen
      // EmailVerificationScreen
      // ProfilePictureScreen
      //

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      Fluttertoast.showToast(
        msg: '❌ ${e.message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      debugPrint(
        'Auth error in profile screen: ${e.message}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      Fluttertoast.showToast(
        msg: '❌ حدث خطأ أثناء إكمال إعداد الحساب.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      debugPrint(
        'Profile completion error: $e',
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(
      context,
    );

    final isArabic =
        languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // HEADER
                  // ==================================================

                  Text(
                    isArabic
                        ? '📸 أضف صورتك الشخصية'
                        : '📸 Add Your Profile Picture',
                    style:
                        GoogleFonts.cairo(
                      color:
                          Colors.white,
                      fontSize:
                          24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                    textAlign:
                        TextAlign.center,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    isArabic
                        ? 'اختر صورة شخصية لتظهر في ملفك الشخصي'
                        : 'Choose a profile picture to appear on your profile',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize:
                          14,
                    ),
                    textAlign:
                        TextAlign.center,
                  ),

                  const SizedBox(
                    height: 40,
                  ),

                  // ==================================================
                  // PROFILE IMAGE PREVIEW
                  // ==================================================

                  GestureDetector(
                    onTap: () {
                      _showImagePicker(
                        context,
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            border:
                                Border.all(
                              color:
                                  Colors.white,
                              width: 3,
                            ),
                            image:
                                _selectedImageBytes !=
                                        null
                                    ? DecorationImage(
                                        image:
                                            MemoryImage(
                                          _selectedImageBytes!,
                                        ),
                                        fit:
                                            BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child:
                              _selectedImageBytes ==
                                      null
                                  ? Icon(
                                      Icons
                                          .person_rounded,
                                      size: 70,
                                      color: Colors
                                          .white
                                          .withAlpha(
                                        128,
                                      ),
                                    )
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration:
                                const BoxDecoration(
                              color:
                                  Colors.white,
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .camera_alt_rounded,
                              color:
                                  primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    isArabic
                        ? '👆 اضغط لتغيير الصورة'
                        : '👆 Tap to change picture',
                    style:
                        TextStyle(
                      color: Colors.white
                          .withAlpha(179),
                      fontSize: 13,
                    ),
                  ),

                  const Spacer(),

                  // ==================================================
                  // START JOURNEY
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : _completeRegistration,
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            primaryColor,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 16,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            30,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(
                                color:
                                    primaryColor,
                                strokeWidth:
                                    2,
                              ),
                            )
                          : Text(
                              isArabic
                                  ? '🚀 ابدأ رحلتك'
                                  : '🚀 Start Your Journey',
                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // SKIP
                  // ==================================================

                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () async {
                                setState(
                                  () {
                                    _isSkipped =
                                        true;
                                  },
                                );

                                await _completeRegistration();
                              },
                    child: Text(
                      isArabic
                          ? '⏭ تخطي هذه الخطوة'
                          : '⏭ Skip this step',
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            14,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  void _showImagePicker(
    BuildContext context,
  ) {
    final isArabic =
        Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).isArabic;

    showModalBottomSheet(
      context: context,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Directionality(
          textDirection: isArabic
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Container(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  isArabic
                      ? 'اختر مصدر الصورة'
                      : 'Choose image source',
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,
                  children: [
                    _ImageSourceButton(
                      icon:
                          Icons.photo_library_rounded,
                      label: isArabic
                          ? 'المعرض'
                          : 'Gallery',
                      onTap: () {
                        Navigator.pop(
                          context,
                        );

                        _pickImage(
                          ImageSource
                              .gallery,
                        );
                      },
                    ),
                    _ImageSourceButton(
                      icon:
                          Icons.camera_alt_rounded,
                      label: isArabic
                          ? 'الكاميرا'
                          : 'Camera',
                      onTap: () {
                        Navigator.pop(
                          context,
                        );

                        _pickImage(
                          ImageSource
                              .camera,
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// IMAGE SOURCE BUTTON
// ============================================================

class _ImageSourceButton
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 80,
        decoration:
            BoxDecoration(
          color:
              Colors.grey.shade100,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(
              icon,
              size: 32,
              color:
                  primaryColor,
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              label,
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
