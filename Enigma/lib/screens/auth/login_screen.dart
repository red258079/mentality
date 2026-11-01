import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/auth_state.dart';
import '../../navigation/student_nav.dart';
import '../../theme/app_theme.dart';
import '../../core/services/biometric_service.dart';
import '../../core/utils/storage.dart';
import '../student/complete_profile_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword  = true;
  bool _rememberMe       = true; // Default: nhớ đăng nhập
  bool _isBiometricSupported = false;
  String _biometricName = 'Vân tay / Face ID';

  static const _keyRememberMe    = 'remember_me';
  static const _keyRememberedEmail = 'remembered_email';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isBiometricAvailable();
    final name = await BiometricService.getBiometricDisplayName();
    if (mounted) {
      setState(() {
        _isBiometricSupported = available;
        _biometricName = name;
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_keyRememberMe) ?? true;
    final email    = prefs.getString(_keyRememberedEmail) ?? '';
    if (mounted) {
      setState(() {
        _rememberMe = remember;
        if (remember && email.isNotEmpty) {
          _emailController.text = email;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthState>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await authState.login(email, password);

    if (!mounted) return;

    if (success) {
      // Lưu hoặc xóa credentials tuỳ theo checkbox "Ghi nhớ đăng nhập"
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, _rememberMe);
      if (_rememberMe) {
        await prefs.setString(_keyRememberedEmail, email);
        // Lưu credentials vào secure storage để tự động đăng nhập khi mở lại app
        await StorageUtil.saveRememberCredentials(email, password);
      } else {
        await prefs.remove(_keyRememberedEmail);
        await StorageUtil.clearRememberCredentials();
      }

      // Lưu mật khẩu cho sinh trắc học nếu sinh trắc học đang bật
      if (StorageUtil.isBiometricEnabled) {
        await StorageUtil.saveBiometricCredentials(email, password);
      }

      if (!mounted) return;
      final user = authState.user;
      final shouldShowCompleteProfile = (user?.universityId == null || user!.universityId!.isEmpty) &&
          !StorageUtil.hasSkippedCompleteProfile;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => shouldShowCompleteProfile
              ? const CompleteProfileScreen(isFromAuth: true)
              : const StudentNav(),
        ),
      );
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _loginWithBiometrics() async {
    final authenticated = await BiometricService.authenticate(
      reason: 'Quét $_biometricName để đăng nhập Enigma',
    );

    if (!authenticated || !mounted) return;

    // Lấy thông tin đăng nhập đã lưu
    final credentials = await StorageUtil.getBiometricCredentials();
    if (!mounted) return;
    if (credentials != null) {
      final authState = context.read<AuthState>();
      final success = await authState.login(
        credentials['email']!,
        credentials['password']!,
      );

      if (!mounted) return;
      if (success) {
        final user = authState.user;
        final shouldShowCompleteProfile = (user?.universityId == null || user!.universityId!.isEmpty) &&
            !StorageUtil.hasSkippedCompleteProfile;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => shouldShowCompleteProfile
                ? const CompleteProfileScreen(isFromAuth: true)
                : const StudentNav(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error ?? 'Đăng nhập sinh trắc học không thành công'),
            backgroundColor: AppTheme.accentCoral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      // Chưa lưu credentials: nếu form đã có email + password thì tự lưu luôn
      if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
        await _login();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập bằng mật khẩu 1 lần đầu để kích hoạt sinh trắc học.'),
            backgroundColor: AppTheme.accentPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    final authState = context.read<AuthState>();
    final success = await authState.loginWithGoogle();
    if (!mounted) return;

    if (success) {
      final user = authState.user;
      final shouldShowCompleteProfile = (user?.universityId == null || user!.universityId!.isEmpty) &&
          !StorageUtil.hasSkippedCompleteProfile;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => shouldShowCompleteProfile
              ? const CompleteProfileScreen(isFromAuth: true)
              : const StudentNav(),
        ),
      );
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _skipLogin() {
    final authState = context.read<AuthState>();
    authState.continueAsGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StudentNav()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.bgDark, Color(0xFF1a1040), AppTheme.bgDark],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    // ── Logo ──────────────────────────────────────────────
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.accentPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.spa_rounded, size: 44, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Title ─────────────────────────────────────────────
                    Text(
                      'Chào mừng trở lại',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,           // FIX: màu trắng, không bị mờ
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Đăng nhập để tiếp tục hành trình của bạn',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // ── Email field ───────────────────────────────────────
                    _buildField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                        if (!v.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Password field ────────────────────────────────────
                    _buildField(
                      controller: _passwordController,
                      label: 'Mật khẩu',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                        if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                        return null;
                      },
                    ),

                    const SizedBox(height: 4),

                    // ── Remember me + Forgot password ─────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Checkbox nhớ đăng nhập
                        GestureDetector(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24, height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                  activeColor: AppTheme.primary,
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ghi nhớ đăng nhập',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        // Quên mật khẩu
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Login button & Biometric Quick Login ──────────────
                    Row(
                      children: [
                        Expanded(
                          child: _GradientButton(
                            onPressed: authState.isLoading ? null : _login,
                            isLoading: authState.isLoading,
                            label: 'Đăng nhập',
                          ),
                        ),
                        if (_isBiometricSupported) ...[
                          const SizedBox(width: 12),
                          _BiometricIconButton(
                            onPressed: authState.isLoading ? null : _loginWithBiometrics,
                            biometricName: _biometricName,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Or Divider ────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: AppTheme.cardBorder)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'HOẶC',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: AppTheme.cardBorder)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Google Sign In Button ─────────────────────────────
                    OutlinedButton(
                      onPressed: authState.isLoading ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: AppTheme.bgSurface,
                        side: const BorderSide(color: AppTheme.cardBorder, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                            height: 22,
                            width: 22,
                            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tiếp tục với Google',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Register link ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Nút Bỏ qua đăng nhập ở cuối form ──────────────────
                    Center(
                      child: TextButton.icon(
                        onPressed: authState.isLoading ? null : _skipLogin,
                        icon: const Icon(
                          Icons.explore_outlined,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        label: Text(
                          'Bỏ qua và khám phá ứng dụng',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.textSecondary.withOpacity(0.4),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),
            ),
          ),

          // ── Nút "Bỏ qua" góc trên bên phải ───────────────────────────
          Positioned(
            top: 10,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: authState.isLoading ? null : _skipLogin,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bỏ qua',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppTheme.textSecondary.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.15),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.bgSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentCoral, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ── Gradient CTA Button ──────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const _GradientButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(colors: [AppTheme.bgSurfaceLight, AppTheme.bgSurfaceLight])
              : const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accentPurple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Biometric Icon Quick Button ──────────────────────────────────────────────
class _BiometricIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String biometricName;

  const _BiometricIconButton({
    required this.onPressed,
    required this.biometricName,
  });

  @override
  Widget build(BuildContext context) {
    final isFace = biometricName.toLowerCase().contains('face');

    return Tooltip(
      message: 'Đăng nhập nhanh bằng $biometricName',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.25),
                  AppTheme.accentMint.withOpacity(0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.accentMint.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentMint.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isFace ? Icons.face_rounded : Icons.fingerprint_rounded,
                color: AppTheme.accentMint,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

