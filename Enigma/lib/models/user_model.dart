class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? studentId;
  final String? university;
  final String? major;
  final String? avatarUrl;
  final bool isActive;
  final String? companyName;
  final String? currentPhase;
  final String? universityId;
  final String? universityName;
  final bool? universityIsPending;
  final String? companyId;
  final bool? companyIsPending;
  final bool? isPending;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.studentId,
    this.university,
    this.major,
    this.avatarUrl,
    this.isActive = true,
    this.companyName = 'LG Display',
    this.currentPhase = 'adaptation',
    this.universityId,
    this.universityName,
    this.universityIsPending,
    this.companyId,
    this.companyIsPending,
    this.isPending,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? 'Sinh viên Enigma',
      role: json['role'] ?? 'student',
      studentId: json['student_id'],
      university: json['university'],
      major: json['major'],
      avatarUrl: json['avatar_url'],
      isActive: json['is_active'] ?? true,
      companyName: json['company_name'] ?? 'LG Display',
      currentPhase: json['current_phase'] ?? 'adaptation',
      universityId: json['university_id']?.toString(),
      universityName: json['university_name'],
      universityIsPending: json['university_is_pending'] as bool?,
      companyId: json['company_id']?.toString(),
      companyIsPending: json['company_is_pending'] as bool?,
      isPending: json['is_pending'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'student_id': studentId,
      'university': university,
      'major': major,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'company_name': companyName,
      'current_phase': currentPhase,
      'university_id': universityId,
      'university_name': universityName,
      'university_is_pending': universityIsPending,
      'company_id': companyId,
      'company_is_pending': companyIsPending,
      'is_pending': isPending,
    };
  }

  String get phaseDisplay {
    switch (currentPhase) {
      case 'preparation':
        return 'Chặng 1: Chuẩn bị hành trang';
      case 'adaptation':
        return 'Chặng 2: Hòa nhập tháng đầu';
      case 'sustain':
        return 'Chặng 3: Duy trì & Bứt phá';
      default:
        return 'Chặng 2: Hòa nhập tháng đầu';
    }
  }
}
