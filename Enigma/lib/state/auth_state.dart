import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../core/utils/storage.dart';
import '../core/constants/app_constants.dart';
import '../core/api/api_client.dart';
import '../core/services/sync_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/onboarding/services/feature_onboarding_service.dart';
import 'package:dio/dio.dart';

class AuthState extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isOfflineMode = false;
  String? _error;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConstants.googleServerClientId,
  );

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _user?.isGuest ?? false;
  bool get isLoading => _isLoading;
  bool get isOfflineMode => _isOfflineMode;
  String? get error => _error;

  // ── Guest Mode / Bỏ qua đăng nhập ─────────────────────────────────────────
  void continueAsGuest() {
    _user = User(
      id: 'guest',
      email: 'khach@enigma.vn',
      name: 'Khách',
      role: 'student',
      studentId: 'Khách trải nghiệm',
    );
    _error = null;
    FeatureOnboardingService.instance.initForUser('guest');
    notifyListeners();
  }

  // ── Startup: check stored token (Offline-First) ───────────────────────────
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await StorageUtil.getToken();
      final cachedUser = StorageUtil.getCachedUser();

      if (token != null) {
        if (AppConstants.useMockApi) {
          await Future.delayed(const Duration(seconds: 1));
          _user = cachedUser ?? User(
            id: 'u1',
            email: 'student@example.com',
            name: 'Nguyễn Văn A',
            role: 'student',
            studentId: 'SV123456',
          );
          if (cachedUser == null) {
            await StorageUtil.saveCachedUser(_user!);
          }
          _isOfflineMode = false;
        } else {
          try {
            final response = await ApiClient.instance.get('/auth/me');
            _user = User.fromJson(response.data);
            await StorageUtil.saveCachedUser(_user!);
            _isOfflineMode = false;
          } on DioException catch (dioErr) {
            final isNetworkError = dioErr.type == DioExceptionType.connectionError ||
                dioErr.type == DioExceptionType.connectionTimeout ||
                dioErr.type == DioExceptionType.sendTimeout ||
                dioErr.type == DioExceptionType.receiveTimeout ||
                dioErr.type == DioExceptionType.unknown;

            if (isNetworkError) {
              // Ngoại tuyến: KHÔNG xóa token! Dùng dữ liệu cachedUser đã lưu
              debugPrint('[AuthState] Không có mạng khi checkAuth. Chuyển sang chế độ ngoại tuyến.');
              if (cachedUser != null) {
                _user = cachedUser;
                _isOfflineMode = true;
              }
            } else if (dioErr.response?.statusCode == 401 || dioErr.response?.statusCode == 403) {
              // Token thực sự hết hạn / bị thu hồi
              _user = null;
              await StorageUtil.clearAllTokens();
              await StorageUtil.clearCachedUser();
              await _tryAutoLogin();
            } else {
              // Lỗi server khác (500...): ưu tiên dùng cachedUser
              if (cachedUser != null) {
                _user = cachedUser;
                _isOfflineMode = true;
              }
            }
          }
        }
      }

      // Nếu chưa có user, thử tự động đăng nhập lại bằng credentials đã ghi nhớ
      if (_user == null) {
        await _tryAutoLogin();
      }

      // Nếu vẫn chưa có nhưng trên máy còn cachedUser:
      if (_user == null && cachedUser != null) {
        _user = cachedUser;
        _isOfflineMode = true;
      }
    } catch (e) {
      debugPrint('[AuthState] checkAuth exception: $e');
      final cachedUser = StorageUtil.getCachedUser();
      if (cachedUser != null) {
        _user = cachedUser;
        _isOfflineMode = true;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      // Nếu có mạng và đã đăng nhập, kích hoạt đồng bộ dữ liệu chờ
      if (isAuthenticated) {
        FeatureOnboardingService.instance.initForUser(_user?.id);
        if (!_isOfflineMode) {
          SyncService.instance.syncPendingData();
        }
      }
    }
  }

  /// Tự động đăng nhập lại bằng credentials đã lưu (tính năng "Ghi nhớ đăng nhập")
  Future<void> _tryAutoLogin() async {
    try {
      final credentials = await StorageUtil.getRememberCredentials();
      if (credentials != null) {
        final email = credentials['email']!;
        final password = credentials['password']!;

        if (AppConstants.useMockApi) {
          await Future.delayed(const Duration(seconds: 1));
          if (email == 'admin@enigma.com') {
            _user = User(id: 'a1', email: email, name: 'Admin', role: 'admin');
          } else {
            _user = User(id: 'u1', email: email, name: 'Nguyễn Văn A', role: 'student', studentId: 'SV123456');
          }
          await StorageUtil.saveToken('mock_access_token_123');
          await StorageUtil.saveRefreshToken('mock_refresh_token_123');
          await StorageUtil.saveCachedUser(_user!);
          _isOfflineMode = false;
        } else {
          final response = await ApiClient.instance.post('/auth/login', data: {
            'email': email,
            'password': password,
          });

          await StorageUtil.saveToken(response.data['access_token']);
          await StorageUtil.saveRefreshToken(response.data['refresh_token']);
          _user = User.fromJson(response.data['user']);
          await StorageUtil.saveCachedUser(_user!);
          _isOfflineMode = false;
          PushNotificationService.syncTokenWithBackend();
        }
      }
    } on DioException catch (dioErr) {
      final isNetworkError = dioErr.type == DioExceptionType.connectionError ||
          dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout;

      if (isNetworkError) {
        // Mất mạng: KHÔNG xóa credentials! Dùng profile đã lưu
        debugPrint('[AuthState] Mất mạng khi auto-login. Giữ nguyên thông tin đăng nhập.');
        final cached = StorageUtil.getCachedUser();
        if (cached != null) {
          _user = cached;
          _isOfflineMode = true;
        }
      } else {
        // Sai mật khẩu thật hoặc tài khoản bị khóa -> xóa credentials
        debugPrint('Auto-login failed with server reject: $dioErr');
        await StorageUtil.clearRememberCredentials();
        _user = null;
      }
    } catch (e) {
      debugPrint('Auto-login exception: $e');
      final cached = StorageUtil.getCachedUser();
      if (cached != null) {
        _user = cached;
        _isOfflineMode = true;
      }
    }
  }

  // ── Login (Hỗ trợ cả Online và Offline) ────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi) {
        await Future.delayed(const Duration(seconds: 1));
        if (email == 'admin@enigma.com') {
          _user = User(id: 'a1', email: email, name: 'Admin', role: 'admin');
        } else {
          _user = User(id: 'u1', email: email, name: 'Nguyễn Văn A', role: 'student', studentId: 'SV123456');
        }
        await StorageUtil.saveToken('mock_access_token_123');
        await StorageUtil.saveRefreshToken('mock_refresh_token_123');
        await StorageUtil.saveCachedUser(_user!);
        _isOfflineMode = false;
      } else {
        final response = await ApiClient.instance.post('/auth/login', data: {
          'email': email,
          'password': password,
        });

        await StorageUtil.saveToken(response.data['access_token']);
        await StorageUtil.saveRefreshToken(response.data['refresh_token']);
        _user = User.fromJson(response.data['user']);
        await StorageUtil.saveCachedUser(_user!);
        _isOfflineMode = false;
        FeatureOnboardingService.instance.initForUser(_user?.id);
        SyncService.instance.syncPendingData();
        PushNotificationService.syncTokenWithBackend();
      }
      return true;
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown;

      if (isNetworkError) {
        // Kiểm tra xem thiết bị đã từng đăng nhập tài khoản này trước đó chưa
        final cachedUser = StorageUtil.getCachedUser();
        final rememberCreds = await StorageUtil.getRememberCredentials();
        final bioCreds = await StorageUtil.getBiometricCredentials();

        final matchCached = cachedUser != null &&
            cachedUser.email.trim().toLowerCase() == email.trim().toLowerCase();
        final matchRemember = rememberCreds != null &&
            rememberCreds['email']?.trim().toLowerCase() == email.trim().toLowerCase();
        final matchBio = bioCreds != null &&
            bioCreds['email']?.trim().toLowerCase() == email.trim().toLowerCase();

        if (matchCached || matchRemember || matchBio) {
          // Cho phép vào app ngoại tuyến bằng tài khoản đã lưu
          _user = cachedUser ?? User(
            id: 'offline_user',
            email: email.trim(),
            name: email.split('@').first,
            role: 'student',
          );
          _isOfflineMode = true;
          _error = null;
          return true;
        } else {
          _error = 'Không có kết nối mạng. Hãy đăng nhập ít nhất một lần khi có mạng để sử dụng ngoại tuyến.';
          return false;
        }
      }

      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        final detail = e.response?.data['detail'];
        _error = detail is List ? detail.map((d) => d['msg']).join('\n') : detail.toString();
      } else {
        _error = 'Đăng nhập thất bại. Vui lòng kiểm tra lại email/mật khẩu.';
      }
      return false;
    } catch (e, stack) {
      debugPrint('Login exception: $e\n$stack');
      _error = 'Đã có lỗi xảy ra: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Google Sign-In (Login / Auto-Register) ──────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi) {
        await Future.delayed(const Duration(seconds: 2));
        _user = User(
          id: 'u_gg_mock',
          email: 'google_student@gmail.com',
          name: 'Google Student',
          role: 'student',
          studentId: 'SV999888',
        );
        await StorageUtil.saveToken('mock_google_access_token');
        await StorageUtil.saveRefreshToken('mock_google_refresh_token');
        return true;
      }

      // Đăng xuất phiên cũ nếu có để cho phép user chọn tài khoản
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        // Người dùng tự đóng popup đăng nhập
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleAccount.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception("Không nhận được idToken từ Google. Vui lòng thử lại.");
      }

      final response = await ApiClient.instance.post('/auth/google', data: {
        'id_token': idToken,
      });

      await StorageUtil.saveToken(response.data['access_token']);
      await StorageUtil.saveRefreshToken(response.data['refresh_token']);
      _user = User.fromJson(response.data['user']);
      await StorageUtil.saveCachedUser(_user!);
      _isOfflineMode = false;
      FeatureOnboardingService.instance.initForUser(_user?.id);
      SyncService.instance.syncPendingData();
      PushNotificationService.syncTokenWithBackend();
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        final detail = e.response?.data['detail'];
        _error = detail is List ? detail.map((d) => d['msg']).join('\n') : detail.toString();
      } else if (e.type == DioExceptionType.connectionError) {
        _error = 'Không thể kết nối tới server backend.';
      } else {
        _error = 'Đăng nhập Google thất bại: ${e.message}';
      }
      return false;
    } catch (e, stack) {
      debugPrint('Google Sign-In exception: $e\n$stack');
      _error = 'Lỗi đăng nhập Google: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<bool> register(
    String name,
    String studentId,
    String email,
    String password, {
    String? university,
    String? major,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi) {
        await Future.delayed(const Duration(seconds: 2));
        _user = User(id: 'u2', email: email, name: name, role: 'student', studentId: studentId);
        await StorageUtil.saveToken('mock_access_token_456');
        await StorageUtil.saveRefreshToken('mock_refresh_token_456');
      } else {
        final response = await ApiClient.instance.post('/auth/register', data: {
          'full_name':  name,
          'email':      email,
          'password':   password,
          'student_id': studentId.isEmpty ? null : studentId,
          'university': university,
          'major':      major,
        });

        await StorageUtil.saveToken(response.data['access_token']);
        await StorageUtil.saveRefreshToken(response.data['refresh_token']);
        _user = User.fromJson(response.data['user']);
        await StorageUtil.saveCachedUser(_user!);
        _isOfflineMode = false;
        FeatureOnboardingService.instance.initForUser(_user?.id);
        SyncService.instance.syncPendingData();
        PushNotificationService.syncTokenWithBackend();
      }
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        final detail = e.response?.data['detail'];
        _error = detail is List ? detail.map((d) => d['msg']).join('\n') : detail.toString();
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        _error = 'Hết thời gian kết nối máy chủ. Vui lòng thử lại.';
      } else if (e.type == DioExceptionType.connectionError) {
        _error = 'Không thể kết nối tới máy chủ backend. Vui lòng kiểm tra server.';
      } else {
        _error = e.message ?? 'Đăng ký thất bại. Vui lòng thử lại.';
      }
      return false;
    } catch (e, stack) {
      debugPrint('Register exception: $e\n$stack');
      _error = 'Đã có lỗi xảy ra: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final refreshToken = await StorageUtil.getRefreshToken();
    // Gọi API logout để thu hồi refresh token (best-effort, ignore lỗi)
    if (!AppConstants.useMockApi && refreshToken != null) {
      try {
        await ApiClient.instance.post('/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {}
    }
    await StorageUtil.clearAllTokens();
    await StorageUtil.clearCachedUser();
    _isOfflineMode = false;
    _user = null;
    FeatureOnboardingService.instance.initForUser(null);
    notifyListeners();
  }

  /// Gọi khi Dio interceptor phát hiện cả refresh token hết hạn
  void forceLogout() {
    StorageUtil.clearCachedUser();
    _isOfflineMode = false;
    _user = null;
    FeatureOnboardingService.instance.initForUser(null);
    notifyListeners();
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi) {
        await Future.delayed(const Duration(seconds: 1));
        return true; // Mock: luôn thành công
      }
      await ApiClient.instance.post('/auth/forgot-password', data: {'email': email});
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        _error = e.response?.data['detail'].toString();
      } else {
        _error = 'Không thể gửi mã xác nhận. Vui lòng thử lại.';
      }
      return false;
    } catch (e) {
      _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────────
  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi) {
        await Future.delayed(const Duration(seconds: 1));
        if (otp == '123456') return true; // Mock: OTP test
        _error = 'Mã xác nhận không đúng.';
        return false;
      }
      await ApiClient.instance.post('/auth/reset-password', data: {
        'email':        email,
        'otp':          otp,
        'new_password': newPassword,
      });
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        _error = e.response?.data['detail'].toString();
      } else {
        _error = 'Mã xác nhận không đúng hoặc đã hết hạn.';
      }
      return false;
    } catch (e) {
      _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Refresh Profile from Server ──────────────────────────────────────────
  Future<void> refreshProfile() async {
    if (_user == null || _user!.isGuest) return;
    try {
      if (!AppConstants.useMockApi) {
        final response = await ApiClient.instance.get('/users/me');
        _user = User.fromJson(response.data);
        await StorageUtil.saveCachedUser(_user!);
        notifyListeners();
      }
    } catch (_) {
      final cached = StorageUtil.getCachedUser();
      if (cached != null) {
        _user = cached;
        notifyListeners();
      }
    }
  }

  /// Đồng bộ công ty vừa cập nhật từ WorkplaceService sang AuthState & StorageUtil
  Future<void> syncWorkplaceCompany({
    String? companyId,
    required String companyName,
  }) async {
    if (_user == null) return;
    _user = _user!.copyWith(
      companyId: companyId,
      companyName: companyName,
    );
    await StorageUtil.saveCachedUser(_user!);
    notifyListeners();
  }

  // ── Update Profile ───────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String name,
    String? studentId,
    String? university,
    String? major,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi || isGuest) {
        await Future.delayed(const Duration(milliseconds: 500));
        _user = _user?.copyWith(
          name: name,
          studentId: studentId,
          university: university,
          major: major,
          avatarUrl: avatarUrl ?? _user?.avatarUrl,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final Map<String, dynamic> data = {
        'full_name': name.trim(),
        'student_id': studentId?.trim(),
        'university': university?.trim(),
        'major': major?.trim(),
      };
      if (avatarUrl != null) {
        data['avatar_url'] = avatarUrl;
      }

      // Optimistic UI update
      if (_user != null) {
        _user = _user!.copyWith(
          name: name,
          studentId: studentId,
          university: university,
          major: major,
          avatarUrl: avatarUrl ?? _user?.avatarUrl,
        );
        await StorageUtil.saveCachedUser(_user!);
        notifyListeners();
      }

      final response = await ApiClient.instance.put('/users/me', data: data);

      _user = User.fromJson(response.data);
      await StorageUtil.saveCachedUser(_user!);
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        _error = e.response?.data['detail'].toString();
      } else {
        _error = 'Cập nhật thất bại. Vui lòng thử lại sau.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Đã có lỗi xảy ra: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConstants.useMockApi || isGuest) {
        await Future.delayed(const Duration(milliseconds: 600));
        _isLoading = false;
        notifyListeners();
        return true;
      }

      await ApiClient.instance.post('/users/change-password', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        _error = e.response?.data['detail'].toString();
      } else {
        _error = 'Đổi mật khẩu thất bại. Vui lòng kiểm tra lại mật khẩu cũ.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Đã có lỗi xảy ra: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
