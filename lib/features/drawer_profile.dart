part of '../main.dart';

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (isSelected ? Colors.white : Colors.white70),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
      tileColor: isSelected ? Colors.white.withAlpha(25) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ============================================================
// PROFILE AVATAR
// ============================================================

class _ProfileAvatar extends StatelessWidget {
  final File? image;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final double radius;
  final bool showEdit;

  const _ProfileAvatar({
    this.image,
    this.imageBytes,
    this.imageUrl,
    required this.radius,
    this.showEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasBytes = imageBytes != null && imageBytes!.isNotEmpty;
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white.withAlpha(51),
          backgroundImage: hasBytes
              ? null
              : (image != null && !kIsWeb
                  ? FileImage(image!)
                  : (imageUrl != null && imageUrl!.isNotEmpty
                      ? NetworkImage(imageUrl!)
                      : null)),
          child: hasBytes
              ? ClipOval(
                  child: Image.memory(
                    imageBytes!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      size: radius * 1.05,
                      color: Colors.white70,
                    ),
                  ),
                )
              : (image == null && (imageUrl == null || imageUrl!.isEmpty))
                  ? ClipOval(
                      child: Image.asset(
                        'assets/branding/zameel_mark.png',
                        width: radius * 1.7,
                        height: radius * 1.7,
                        fit: BoxFit.contain,
                      ),
                    )
                  : null,
        ),
        if (showEdit)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 23,
              height: 23,
              decoration: const BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// CREATE ACTION
// ============================================================

class _CreateAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _CreateAction({
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE OPTION
// ============================================================

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.white.withAlpha(51),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: iconColor ?? Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ============================================================
// USER PROFILE NAVIGATION
// ============================================================

void _openUserProfile(BuildContext context, String? userId) {
  final id = userId?.trim();
  if (id == null || id.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الملف الشخصي لهذا المستخدم')),
    );
    return;
  }

  final demoIndex = _demoUsers.indexWhere((u) => u['id']?.toString() == id);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => demoIndex >= 0
          ? DemoProfileScreen(user: _demoUsers[demoIndex])
          : ProfileScreen(userId: id),
    ),
  );
}

class DemoProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const DemoProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final name = user['name']?.toString() ?? (ar ? 'مستخدم تجريبي' : 'Demo user');
    final role = user['role']?.toString() ?? 'student';
    final department = user['department']?.toString() ?? '';
    final myPosts = _demoPosts.where((p) => p['user_id'] == user['id']).toList();
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const SizedBox.shrink()),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(children: [
                CircleAvatar(radius: 42, backgroundColor: Colors.white.withValues(alpha: .92), child: Text(name.isNotEmpty ? name.substring(0, 1) : 'ز', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryDark))),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(department, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)), child: Text(role == 'company' ? 'نشاط تجاري تجريبي' : 'حساب تجريبي', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: Text(ar ? 'منشورات المستخدم' : 'User posts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ...myPosts.map((post) => Card(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Padding(padding: const EdgeInsets.all(16), child: Text(ar ? post['text_ar'].toString() : post['text_en'].toString(), style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600))))) ,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// POST CARD
// ============================================================

class _PostOwnerAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  const _PostOwnerAvatar({this.imageUrl, this.radius = 22});
  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return CircleAvatar(radius: radius, backgroundColor: Colors.white24, backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty) ? const Icon(Icons.person, color: Colors.white70) : null);
  }
}

