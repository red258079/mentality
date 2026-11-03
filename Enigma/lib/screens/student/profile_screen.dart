import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/workplace_service.dart';
import '../../core/utils/storage.dart';
import '../../models/user.dart';
import '../../state/app_state.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../settings_screen.dart';
import '../../widgets/app_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadProfileData();
    });
  }

  Future<void> _reloadProfileData() async {
    await Future.wait([
      context.read<AuthState>().refreshProfile(),
      WorkplaceService.instance.fetchProfile(),
    ]);
    if (mounted) {
      setState(() {});
    }
  }

  // ── Show Edit Profile Bottom Sheet ──────────────────────────────────────────
  void _showEditProfileSheet(BuildContext context, User user) {
    final nameCtrl = TextEditingController(text: user.name);
    final studentIdCtrl = TextEditingController(text: user.studentId ?? '');
    final universityCtrl = TextEditingController(text: user.university ?? '');
    final majorCtrl = TextEditingController(text: user.major ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.onSurfaceMuted(context).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Chỉnh sửa thông tin',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Họ và tên
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Họ và tên *',
                      prefixIcon: const Icon(Icons.person_rounded),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                  ),
                  const SizedBox(height: 14),

                  // Mã số sinh viên
                  TextFormField(
                    controller: studentIdCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mã số sinh viên (MSSV)',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Trường Đại học
                  TextFormField(
                    controller: universityCtrl,
                    decoration: InputDecoration(
                      labelText: 'Trường Đại học / Cao đẳng',
                      prefixIcon: const Icon(Icons.school_rounded),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Ngành học
                  TextFormField(
                    controller: majorCtrl,
                    decoration: InputDecoration(
                      labelText: 'Chuyên ngành học',
                      prefixIcon: const Icon(Icons.engineering_rounded),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.pop(sheetCtx);

                            final success = await context.read<AuthState>().updateProfile(
                                  name: nameCtrl.text,
                                  studentId: studentIdCtrl.text,
                                  university: universityCtrl.text,
                                  major: majorCtrl.text,
                                );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Đã cập nhật thông tin thành công!'
                                        : (context.read<AuthState>().error ?? 'Lỗi cập nhật'),
                                  ),
                                  backgroundColor: success ? AppTheme.accentMint : AppTheme.accentCoral,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Show Avatar Picker Sheet ────────────────────────────────────────────────
  void _showAvatarPickerSheet(BuildContext context, User user) {
    final List<String> presetAvatars = [
      'https://api.dicebear.com/7.x/bottts/png?seed=EnigmaBot',
      'https://api.dicebear.com/7.x/bottts/png?seed=CyberTech',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Alex',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Sam',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Taylor',
      'https://api.dicebear.com/7.x/fun-emoji/png?seed=Happy',
      'https://api.dicebear.com/7.x/fun-emoji/png?seed=Cool',
      'https://api.dicebear.com/7.x/thumbs/png?seed=Champion',
    ];

    String? selectedAvatar = user.avatarUrl;
    final urlCtrl = TextEditingController(text: user.avatarUrl ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.onSurfaceMuted(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_circle_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Đổi ảnh đại diện',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Avatar Preview
                Center(
                  child: AppAvatar(
                    avatarUrl: selectedAvatar,
                    initial: user.name,
                    size: 88,
                    showShadow: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Preset selector
                const Text(
                  'Chọn mẫu đại diện có sẵn:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: presetAvatars.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, idx) {
                      final pUrl = presetAvatars[idx];
                      final isSelected = selectedAvatar == pUrl;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedAvatar = pUrl;
                            urlCtrl.text = pUrl;
                          });
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.borderColor(context),
                              width: isSelected ? 3 : 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              pUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 120,
                              cacheHeight: 120,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Custom URL Input
                const Text(
                  'Hoặc dán liên kết ảnh đại diện (URL):',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/avatar.png',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: urlCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setModalState(() {
                                urlCtrl.clear();
                                selectedAvatar = null;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceAltColor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      selectedAvatar = val.trim().isNotEmpty ? val.trim() : null;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Reset to initials button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setModalState(() {
                        urlCtrl.clear();
                        selectedAvatar = '';
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Dùng chữ cái mặc định'),
                  ),
                ),
                const SizedBox(height: 12),

                // Save button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final finalAvatar = (selectedAvatar != null && selectedAvatar!.isNotEmpty)
                              ? selectedAvatar!
                              : '';

                          Navigator.pop(sheetCtx);

                          try {
                            final success = await context.read<AuthState>().updateProfile(
                                  name: user.name,
                                  studentId: user.studentId,
                                  university: user.university,
                                  major: user.major,
                                  avatarUrl: finalAvatar,
                                );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Đã cập nhật ảnh đại diện thành công!'
                                        : (context.read<AuthState>().error ?? 'Lỗi cập nhật ảnh đại diện'),
                                  ),
                                  backgroundColor: success ? AppTheme.accentMint : AppTheme.accentCoral,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi: $e'),
                                  backgroundColor: AppTheme.accentCoral,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Lưu ảnh', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Show Change Password Dialog ─────────────────────────────────────────────
  void _showChangePasswordDialog(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppTheme.borderColor(context)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: AppTheme.accentPurple, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Đổi mật khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu hiện tại' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới (≥6 ký tự)',
                      prefixIcon: const Icon(Icons.vpn_key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập mật khẩu mới';
                      if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) {
                      if (v != newPassCtrl.text) return 'Mật khẩu xác nhận không khớp';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      final success = await context.read<AuthState>().changePassword(
                            oldPassCtrl.text,
                            newPassCtrl.text,
                          );

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Đổi mật khẩu thành công!'
                                  : (context.read<AuthState>().error ?? 'Đổi mật khẩu thất bại'),
                            ),
                            backgroundColor: success ? AppTheme.accentMint : AppTheme.accentCoral,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Show Logout Confirmation ────────────────────────────────────────────────
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppTheme.accentCoral, size: 24),
            SizedBox(width: 10),
            Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng Enigma?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<AuthState>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final appState = context.watch<AppState>();
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông tin tài khoản')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined, size: 72, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text('Bạn chưa đăng nhập', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Đăng nhập ngay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final initialLetter = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    final cachedCompanyName = StorageUtil.getCachedUser()?.companyName;
    final workplaceCompanyName = WorkplaceService.instance.profile?.companyName;
    final String companyDisplayName = (user.companyName != null && user.companyName!.trim().isNotEmpty)
        ? user.companyName!
        : ((workplaceCompanyName != null && workplaceCompanyName.trim().isNotEmpty)
            ? workplaceCompanyName
            : ((cachedCompanyName != null && cachedCompanyName.trim().isNotEmpty)
                ? cachedCompanyName
                : 'Chưa cập nhật'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin tài khoản'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Chỉnh sửa thông tin',
            onPressed: () => _showEditProfileSheet(context, user),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Guest warning if applicable
            if (user.isGuest) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Bạn đang trải nghiệm dưới tài khoản Khách. Hãy đăng ký tài khoản chính thức để lưu tiến độ.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Đăng ký / Nhập', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],

            // ── Main User Hero Card ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.18),
                    AppTheme.accentPurple.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarPickerSheet(context, user),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AppAvatar(
                          avatarUrl: user.avatarUrl,
                          initial: initialLetter,
                          size: 84,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surfaceColor(context), width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceSecondary(context),
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildBadge(
                        icon: Icons.work_outline_rounded,
                        label: companyDisplayName,
                        color: AppTheme.primaryLight,
                      ),
                      _buildBadge(
                        icon: Icons.verified_user_outlined,
                        label: user.role == 'admin' ? 'Quản trị viên' : 'Thực tập sinh',
                        color: AppTheme.accentMint,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Activity Stats ───────────────────────────────────────────────
            Row(
              children: [
                _buildStatTile(
                  context,
                  title: '${appState.streakDays} ngày',
                  subtitle: 'Chuỗi liên tiếp',
                  icon: Icons.local_fire_department_rounded,
                  color: AppTheme.accentAmber,
                ),
                const SizedBox(width: 12),
                _buildStatTile(
                  context,
                  title: '${appState.todayTasks.where((t) => t.isCompleted).length} / ${appState.todayTasks.length}',
                  subtitle: 'Nhiệm vụ hôm nay',
                  icon: Icons.task_alt_rounded,
                  color: AppTheme.accentMint,
                ),
                const SizedBox(width: 12),
                _buildStatTile(
                  context,
                  title: '${appState.score.overall.round()}',
                  subtitle: 'Điểm sức khỏe',
                  icon: Icons.favorite_rounded,
                  color: AppTheme.accentPurple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section: Thông tin sinh viên chi tiết ─────────────────────────
            _buildSectionTitle(context, 'Hồ sơ & Học tập', Icons.school_rounded, AppTheme.primaryLight),
            const SizedBox(height: 10),

            _buildDetailTile(
              context,
              icon: Icons.badge_outlined,
              label: 'Mã số sinh viên (MSSV)',
              value: (user.studentId != null && user.studentId!.isNotEmpty) ? user.studentId! : 'Chưa cập nhật',
            ),
            _buildDetailTile(
              context,
              icon: Icons.school_outlined,
              label: 'Trường đào tạo',
              value: (user.university != null && user.university!.isNotEmpty) ? user.university! : 'Chưa cập nhật',
            ),
            _buildDetailTile(
              context,
              icon: Icons.engineering_outlined,
              label: 'Chuyên ngành',
              value: (user.major != null && user.major!.isNotEmpty) ? user.major! : 'Chưa cập nhật',
            ),
            _buildDetailTile(
              context,
              icon: Icons.business_outlined,
              label: 'Đơn vị thực tập',
              value: companyDisplayName,
            ),

            const SizedBox(height: 24),

            // ── Section: Bảo mật & Tài khoản ──────────────────────────────────
            _buildSectionTitle(context, 'Bảo mật & Quản trị', Icons.shield_outlined, AppTheme.accentMint),
            const SizedBox(height: 10),

            _buildActionMenuTile(
              context,
              icon: Icons.edit_note_rounded,
              iconColor: AppTheme.primary,
              title: 'Chỉnh sửa thông tin cá nhân',
              subtitle: 'Cập nhật tên, MSSV, trường & ngành học',
              onTap: () => _showEditProfileSheet(context, user),
            ),
            _buildActionMenuTile(
              context,
              icon: Icons.lock_reset_rounded,
              iconColor: AppTheme.accentPurple,
              title: 'Đổi mật khẩu',
              subtitle: 'Thay đổi mật khẩu đăng nhập tài khoản',
              onTap: () => _showChangePasswordDialog(context),
            ),
            _buildActionMenuTile(
              context,
              icon: Icons.settings_suggest_rounded,
              iconColor: AppTheme.secondary,
              title: 'Cài đặt hệ thống & Giao diện',
              subtitle: 'Chế độ Sáng / Tối, Sinh trắc học & Thông báo',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),

            const SizedBox(height: 28),

            // ── Logout Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, color: AppTheme.accentCoral, size: 20),
                label: const Text(
                  'Đăng xuất tài khoản',
                  style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.accentCoral.withValues(alpha: 0.4), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppTheme.accentCoral.withValues(alpha: 0.05),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: AppTheme.cardDecorationFor(context, borderRadius: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: AppTheme.onSurfaceMuted(context),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecorationFor(context, borderRadius: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.onSurfaceSecondary(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.onSurfaceMuted(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecorationFor(context, borderRadius: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.onSurfaceMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceMuted(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
