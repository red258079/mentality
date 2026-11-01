import 'package:dio/dio.dart';
import '../utils/storage.dart';
import '../constants/app_constants.dart';
import '../../models/catalog_item.dart';

/// Dio HTTP Client với JWT Auto-refresh Interceptor.
///
/// Luồng xử lý 401:
///  1. Request đầu tiên thất bại với HTTP 401 (access token hết hạn).
///  2. Interceptor tự động gọi POST /auth/refresh với refresh_token.
///  3. Nếu refresh thành công → lưu access_token mới → retry request gốc.
///  4. Nếu refresh thất bại (refresh token hết hạn) → xóa tất cả token
///     → broadcast sự kiện để navigator đưa người dùng về màn Login.
class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
    headers: {'Content-Type': 'application/json'},
  ));

  // Callback để trigger navigation tới LoginScreen từ ngoài context
  static void Function()? onUnauthorized;

  static void init() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        // ── Attach access token ────────────────────────────────────────────
        onRequest: (options, handler) async {
          final token = await StorageUtil.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        onResponse: (response, handler) => handler.next(response),

        // ── Auto-refresh on 401 ────────────────────────────────────────────
        onError: (DioException e, handler) async {
          if (e.response?.statusCode != 401) {
            return handler.next(e);
          }

          // Tránh vòng lặp vô hạn: không retry chính endpoint /auth/refresh
          final path = e.requestOptions.path;
          if (path.contains('/auth/refresh') || path.contains('/auth/login')) {
            await StorageUtil.clearAllTokens();
            onUnauthorized?.call();
            return handler.next(e);
          }

          // Thử dùng refresh token lấy access token mới
          final refreshToken = await StorageUtil.getRefreshToken();
          if (refreshToken == null) {
            await StorageUtil.clearAllTokens();
            onUnauthorized?.call();
            return handler.next(e);
          }

          try {
            final refreshResp = await _dio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
              options: Options(headers: {}), // không attach cũ token
            );

            final newAccessToken = refreshResp.data['access_token'] as String;
            await StorageUtil.saveToken(newAccessToken);

            // Retry request gốc với token mới
            final retryOpts = e.requestOptions;
            retryOpts.headers['Authorization'] = 'Bearer $newAccessToken';
            final retryResp = await _dio.fetch(retryOpts);
            return handler.resolve(retryResp);
          } catch (_) {
            // Refresh thất bại → bắt buộc đăng nhập lại
            await StorageUtil.clearAllTokens();
            onUnauthorized?.call();
            return handler.next(e);
          }
        },
      ),
    );
  }

  static Dio get instance => _dio;

  /// Tìm kiếm trường đại học trong Catalog (GET /catalog/universities?q=&limit=20)
  static Future<List<CatalogItem>> searchUniversities(String q, {int limit = 20}) async {
    final response = await _dio.get(
      '/catalog/universities',
      queryParameters: {'q': q, 'limit': limit},
    );
    if (response.data is List) {
      return (response.data as List)
          .map((item) => CatalogItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  /// Tìm kiếm công ty thực tập trong Catalog (GET /catalog/companies?q=&limit=20)
  static Future<List<CatalogItem>> searchCompanies(String q, {int limit = 20}) async {
    final response = await _dio.get(
      '/catalog/companies',
      queryParameters: {'q': q, 'limit': limit},
    );
    if (response.data is List) {
      return (response.data as List)
          .map((item) => CatalogItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  /// Cập nhật trường học và công ty thực tập theo Catalog (PUT /me/profile)
  static Future<Map<String, dynamic>> updateCatalogProfile({
    String? universityId,
    String? companyId,
    String? otherUniversityName,
    String? otherCompanyName,
  }) async {
    final payload = <String, dynamic>{};
    if (universityId != null && universityId.isNotEmpty) {
      payload['university_id'] = universityId;
    }
    if (companyId != null && companyId.isNotEmpty) {
      payload['company_id'] = companyId;
    }
    if (otherUniversityName != null && otherUniversityName.isNotEmpty) {
      payload['other_university_name'] = otherUniversityName;
    }
    if (otherCompanyName != null && otherCompanyName.isNotEmpty) {
      payload['other_company_name'] = otherCompanyName;
    }

    final response = await _dio.put('/me/profile', data: payload);
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : Map<String, dynamic>.from(response.data as Map);
  }
}
