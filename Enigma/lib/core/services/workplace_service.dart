import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';
import '../utils/storage.dart';

enum WorkplaceStatus {
  atWorkplace, // Đang ở trong khuôn viên công ty / tủ đồ
  atDorm,      // Đang ở phòng trọ / KTX
  outside,     // Đang di chuyển ngoài
  unknown,     // Chưa xác định được vị trí
}

class WorkplaceCompany {
  final String id;
  final String name;
  final String shortName;
  final String address;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final String workplaceType;
  final String workplaceTypeLabel;
  final List<Map<String, dynamic>> availableShifts;
  final String defaultShift;

  WorkplaceCompany({
    required this.id,
    required this.name,
    required this.shortName,
    required this.address,
    this.latitude,
    this.longitude,
    required this.radiusMeters,
    required this.workplaceType,
    required this.workplaceTypeLabel,
    required this.availableShifts,
    required this.defaultShift,
  });

  factory WorkplaceCompany.fromJson(Map<String, dynamic> json) {
    return WorkplaceCompany(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      shortName: json['short_name'] ?? json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      radiusMeters: json['radius_meters'] ?? 500,
      workplaceType: json['workplace_type'] ?? 'factory_locker',
      workplaceTypeLabel: json['workplace_type_label'] ?? '',
      availableShifts: List<Map<String, dynamic>>.from(json['available_shifts'] ?? []),
      defaultShift: json['default_shift'] ?? 'day_12h',
    );
  }
}

class WorkplaceProfile {
  final String? companyId;
  final String companyName;
  final String department;
  final double? companyLat;
  final double? companyLng;
  final int companyRadius;
  final String workplaceType;
  final String workShift;
  final double? dormLat;
  final double? dormLng;

  WorkplaceProfile({
    this.companyId,
    required this.companyName,
    required this.department,
    this.companyLat,
    this.companyLng,
    required this.companyRadius,
    required this.workplaceType,
    required this.workShift,
    this.dormLat,
    this.dormLng,
  });

  factory WorkplaceProfile.fromJson(Map<String, dynamic> json) {
    return WorkplaceProfile(
      companyId: json['company_id']?.toString(),
      companyName: json['company_name'] ?? '',
      department: json['department'] ?? 'Khối Sản xuất Module',
      companyLat: json['company_lat'] != null ? (json['company_lat'] as num).toDouble() : null,
      companyLng: json['company_lng'] != null ? (json['company_lng'] as num).toDouble() : null,
      companyRadius: json['company_radius'] ?? 600,
      workplaceType: json['workplace_type'] ?? 'factory_locker',
      workShift: json['work_shift'] ?? 'day_12h',
      dormLat: json['dorm_lat'] != null ? (json['dorm_lat'] as num).toDouble() : null,
      dormLng: json['dorm_lng'] != null ? (json['dorm_lng'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'department': department,
      'company_lat': companyLat,
      'company_lng': companyLng,
      'company_radius': companyRadius,
      'workplace_type': workplaceType,
      'work_shift': workShift,
      'dorm_lat': dormLat,
      'dorm_lng': dormLng,
    };
  }
}

class WorkplaceService {
  static final WorkplaceService instance = WorkplaceService._();
  WorkplaceService._();

  static final List<WorkplaceCompany> defaultCompanies = [
    WorkplaceCompany(
      id: 'lg_display_hp',
      name: 'LG Display Hải Phòng',
      shortName: 'LG Display',
      address: 'Lô E, KCN Tràng Duệ, An Dương, Hải Phòng',
      latitude: 20.8865,
      longitude: 106.5821,
      radiusMeters: 600,
      workplaceType: 'factory_locker',
      workplaceTypeLabel: 'Nhà máy phòng sạch (Cất điện thoại tủ đồ)',
      availableShifts: [
        {'id': 'day_12h', 'label': 'Ca ngày (08:00 – 20:00)', 'start_time': '08:00', 'end_time': '20:00', 'is_night': false},
        {'id': 'night_12h', 'label': 'Ca đêm (20:00 – 08:00)', 'start_time': '20:00', 'end_time': '08:00', 'is_night': true},
      ],
      defaultShift: 'day_12h',
    ),
    WorkplaceCompany(
      id: 'samsung_sevt_tn',
      name: 'Samsung Electronics Thái Nguyên (SEVT)',
      shortName: 'Samsung SEVT',
      address: 'KCN Yên Bình, Phổ Yên, Thái Nguyên',
      latitude: 21.4650,
      longitude: 105.8690,
      radiusMeters: 800,
      workplaceType: 'factory_locker',
      workplaceTypeLabel: 'Nhà máy sản xuất (Cất điện thoại tủ đồ)',
      availableShifts: [
        {'id': 'day_12h', 'label': 'Ca ngày (08:00 – 20:00)', 'start_time': '08:00', 'end_time': '20:00', 'is_night': false},
        {'id': 'night_12h', 'label': 'Ca đêm (20:00 – 08:00)', 'start_time': '20:00', 'end_time': '08:00', 'is_night': true},
      ],
      defaultShift: 'day_12h',
    ),
    WorkplaceCompany(
      id: 'samsung_sdv_bn',
      name: 'Samsung Display Bắc Ninh (SDV)',
      shortName: 'Samsung SDV',
      address: 'KCN Yên Phong, Yên Phong, Bắc Ninh',
      latitude: 21.2035,
      longitude: 105.9754,
      radiusMeters: 800,
      workplaceType: 'factory_locker',
      workplaceTypeLabel: 'Nhà máy sản xuất (Cất điện thoại tủ đồ)',
      availableShifts: [
        {'id': 'day_12h', 'label': 'Ca ngày (08:00 – 20:00)', 'start_time': '08:00', 'end_time': '20:00', 'is_night': false},
        {'id': 'night_12h', 'label': 'Ca đêm (20:00 – 08:00)', 'start_time': '20:00', 'end_time': '08:00', 'is_night': true},
      ],
      defaultShift: 'day_12h',
    ),
    WorkplaceCompany(
      id: 'fpt_software_hl',
      name: 'FPT Software Hòa Lạc (F-Ville)',
      shortName: 'FPT Software',
      address: 'Khu Công nghệ cao Hòa Lạc, Thạch Thất, Hà Nội',
      latitude: 21.0131,
      longitude: 105.5273,
      radiusMeters: 500,
      workplaceType: 'office',
      workplaceTypeLabel: 'Văn phòng CNTT (Được dùng điện thoại)',
      availableShifts: [
        {'id': 'office_8h', 'label': 'Ca hành chính (08:30 – 17:30)', 'start_time': '08:30', 'end_time': '17:30', 'is_night': false},
      ],
      defaultShift: 'office_8h',
    ),
    WorkplaceCompany(
      id: 'vinfast_hp',
      name: 'Tổ hợp Nhà máy VinFast Hải Phòng',
      shortName: 'VinFast',
      address: 'KCN Đình Vũ - Cát Hải, Cát Hải, Hải Phòng',
      latitude: 20.8350,
      longitude: 106.9320,
      radiusMeters: 1000,
      workplaceType: 'factory_locker',
      workplaceTypeLabel: 'Nhà máy lắp ráp (Cất điện thoại tủ đồ)',
      availableShifts: [
        {'id': 'day_12h', 'label': 'Ca ngày (08:00 – 20:00)', 'start_time': '08:00', 'end_time': '20:00', 'is_night': false},
        {'id': 'night_12h', 'label': 'Ca đêm (20:00 – 08:00)', 'start_time': '20:00', 'end_time': '08:00', 'is_night': true},
      ],
      defaultShift: 'day_12h',
    ),
    WorkplaceCompany(
      id: 'custom',
      name: 'Công ty khác (Tự định vị / Văn phòng)',
      shortName: 'Công ty khác',
      address: 'Tùy chỉnh theo sinh viên',
      radiusMeters: 300,
      workplaceType: 'custom',
      workplaceTypeLabel: 'Tự thiết lập tọa độ và ca làm',
      availableShifts: [
        {'id': 'office_8h', 'label': 'Ca hành chính (08:00 – 17:00)', 'start_time': '08:00', 'end_time': '17:00', 'is_night': false},
        {'id': 'day_12h', 'label': 'Ca ngày (08:00 – 20:00)', 'start_time': '08:00', 'end_time': '20:00', 'is_night': false},
        {'id': 'night_12h', 'label': 'Ca đêm (20:00 – 08:00)', 'start_time': '20:00', 'end_time': '08:00', 'is_night': true},
      ],
      defaultShift: 'office_8h',
    ),
  ];

  List<WorkplaceCompany> _companies = List.from(defaultCompanies);
  WorkplaceProfile? _profile;
  Position? _currentPosition;
  WorkplaceStatus _status = WorkplaceStatus.unknown;
  double? _distanceToCompanyMeters;
  String? _lastError;

  List<WorkplaceCompany> get companies => _companies.isNotEmpty ? _companies : defaultCompanies;
  WorkplaceProfile? get profile => _profile;
  WorkplaceStatus get status => _status;
  Position? get currentPosition => _currentPosition;
  double? get distanceToCompanyMeters => _distanceToCompanyMeters;
  String? get lastError => _lastError;

  Future<void> _syncLocalCacheFromProfile(WorkplaceProfile prof) async {
    await StorageUtil.saveCachedWorkplaceProfile(prof.toJson());
    final cachedUser = StorageUtil.getCachedUser();
    if (cachedUser != null && prof.companyName.isNotEmpty) {
      await StorageUtil.saveCachedUser(
        cachedUser.copyWith(
          companyId: prof.companyId,
          companyName: prof.companyName,
        ),
      );
    }
  }

  /// Tải danh mục công ty từ backend
  Future<List<WorkplaceCompany>> fetchCompanies() async {
    try {
      final response = await ApiClient.instance.get('/workplace/companies');
      if (response.data is List && (response.data as List).isNotEmpty) {
        final list = (response.data as List)
            .map((item) => WorkplaceCompany.fromJson(item))
            .toList();
        _companies = list;
        return list;
      }
    } catch (e) {
      debugPrint('[WorkplaceService] Lỗi tải danh mục công ty: $e');
    }
    return defaultCompanies;
  }

  /// Tải thông tin hồ sơ thực tập & vị trí của sinh viên
  Future<WorkplaceProfile?> fetchProfile() async {
    try {
      final response = await ApiClient.instance.get('/workplace/profile');
      if (response.data is Map<String, dynamic>) {
        _profile = WorkplaceProfile.fromJson(response.data as Map<String, dynamic>);
        await _syncLocalCacheFromProfile(_profile!);
      }
      await evaluateCurrentLocation();
      return _profile;
    } catch (e) {
      debugPrint('[WorkplaceService] Lỗi tải hồ sơ thực tập: $e');
      final cached = StorageUtil.getCachedWorkplaceProfile();
      if (cached != null) {
        _profile = WorkplaceProfile.fromJson(cached);
      }
      return _profile;
    }
  }

  /// Cập nhật công ty và ca làm việc
  Future<bool> updateProfile({
    String? companyId,
    required String companyName,
    String? workShift,
    String? workplaceType,
    double? dormLat,
    double? dormLng,
  }) async {
    _lastError = null;
    try {
      final payload = {
        if (companyId != null && companyId.isNotEmpty) 'company_id': companyId,
        'company_name': companyName.trim(),
        if (workShift != null) 'work_shift': workShift,
        if (workplaceType != null) 'workplace_type': workplaceType,
        if (dormLat != null) 'dorm_lat': dormLat,
        if (dormLng != null) 'dorm_lng': dormLng,
      };

      final response = await ApiClient.instance.put('/workplace/profile', data: payload);
      if (response.data is Map<String, dynamic>) {
        _profile = WorkplaceProfile.fromJson(response.data as Map<String, dynamic>);
        await _syncLocalCacheFromProfile(_profile!);
      }
      await evaluateCurrentLocation();
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        _lastError = e.response?.data['detail'].toString();
      } else {
        _lastError = 'Không thể cập nhật công ty thực tập. Vui lòng thử lại.';
      }
      debugPrint('[WorkplaceService] Lỗi cập nhật hồ sơ thực tập: $_lastError');
      return false;
    } catch (e) {
      _lastError = 'Đã có lỗi xảy ra khi cập nhật công ty: $e';
      debugPrint('[WorkplaceService] Lỗi cập nhật hồ sơ thực tập: $e');
      return false;
    }
  }

  /// Đánh giá vị trí hiện tại so với công ty và phòng trọ
  Future<WorkplaceStatus> evaluateCurrentLocation({bool promptPermission = false}) async {
    try {
      // 1. Kiểm tra GPS trên thiết bị
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _status = WorkplaceStatus.unknown;
        return _status;
      }

      // 2. Kiểm tra quyền định vị
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && promptPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _status = WorkplaceStatus.unknown;
        return _status;
      }

      // 3. Lấy vị trí nhanh gần nhất
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        _status = WorkplaceStatus.unknown;
        return _status;
      }

      _currentPosition = pos;

      if (_profile != null && _profile!.companyLat != null && _profile!.companyLng != null) {
        final distToComp = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          _profile!.companyLat!,
          _profile!.companyLng!,
        );
        _distanceToCompanyMeters = distToComp;

        // Nếu nằm trong bán kính công ty
        if (distToComp <= _profile!.companyRadius) {
          _status = WorkplaceStatus.atWorkplace;
          return _status;
        }

        // Nếu có tọa độ phòng trọ
        if (_profile!.dormLat != null && _profile!.dormLng != null) {
          final distToDorm = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            _profile!.dormLat!,
            _profile!.dormLng!,
          );
          if (distToDorm <= 250) {
            _status = WorkplaceStatus.atDorm;
            return _status;
          }
        }

        _status = WorkplaceStatus.outside;
        return _status;
      }
    } catch (e) {
      debugPrint('[WorkplaceService] Lỗi định vị: $e');
    }

    _status = WorkplaceStatus.unknown;
    return _status;
  }

  /// Tính số giờ ngủ ước tính thông minh dựa trên chu kỳ ca kíp
  double calculateEstimatedSleepHours() {
    // Nếu sinh viên đi ca đêm (20h - 8h): giờ ngủ thường là 09:30 - 16:30 (khoảng 7.0 tiếng)
    if (_profile?.workShift == 'night_12h') {
      return 6.5;
    }
    // Ca ngày hoặc hành chính: giờ ngủ thông thường 23:30 - 06:45 (khoảng 7.2 tiếng)
    return 7.0;
  }

  String getStatusLabel() {
    switch (_status) {
      case WorkplaceStatus.atWorkplace:
        return 'Khuôn viên ${_profile?.companyName ?? "Công ty"}';
      case WorkplaceStatus.atDorm:
        return 'Phòng trọ / Ký túc xá';
      case WorkplaceStatus.outside:
        return 'Đang di chuyển ngoài';
      case WorkplaceStatus.unknown:
        return 'Chưa bật định vị';
    }
  }
}
