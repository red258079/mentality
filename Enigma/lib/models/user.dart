class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'student' or 'admin'
  final String? studentId;
  final String? university;
  final String? major;
  final String? avatarUrl;
  final String? universityId;
  final String? universityName;
  final bool? universityIsPending;
  final String? companyId;
  final String? companyName;
  final bool? companyIsPending;
  final bool? isPending;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.studentId,
    this.university,
    this.major,
    this.avatarUrl,
    this.universityId,
    this.universityName,
    this.universityIsPending,
    this.companyId,
    this.companyName,
    this.companyIsPending,
    this.isPending,
  });

  bool get isGuest => id == 'guest';

  String get displayUniversity {
    if (universityName != null && universityName!.trim().isNotEmpty) return universityName!;
    if (university != null && university!.trim().isNotEmpty) return university!;
    return 'Chưa cập nhật';
  }

  String get displayCompany {
    if (companyName != null && companyName!.trim().isNotEmpty) return companyName!;
    return 'Chưa cập nhật';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawUni = json['university']?.toString();
    final rawUniName = json['university_name']?.toString();
    final resolvedUni = (rawUniName != null && rawUniName.trim().isNotEmpty)
        ? rawUniName.trim()
        : ((rawUni != null && rawUni.trim().isNotEmpty) ? rawUni.trim() : null);

    final rawComp = json['company_name']?.toString() ?? json['company']?.toString();

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['full_name'] ?? json['name'] ?? '',
      role: json['role'] ?? 'student',
      studentId: json['student_id'] ?? json['studentId'],
      university: resolvedUni,
      major: json['major'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      universityId: json['university_id']?.toString(),
      universityName: resolvedUni,
      universityIsPending: json['university_is_pending'] as bool?,
      companyId: json['company_id']?.toString(),
      companyName: rawComp,
      companyIsPending: json['company_is_pending'] as bool?,
      isPending: json['is_pending'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'studentId': studentId,
      'university': university,
      'major': major,
      'avatarUrl': avatarUrl,
      'university_id': universityId,
      'university_name': universityName,
      'university_is_pending': universityIsPending,
      'company_id': companyId,
      'company_name': companyName,
      'company_is_pending': companyIsPending,
      'is_pending': isPending,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? studentId,
    String? university,
    String? major,
    String? avatarUrl,
    String? universityId,
    String? universityName,
    bool? universityIsPending,
    String? companyId,
    String? companyName,
    bool? companyIsPending,
    bool? isPending,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      university: university ?? this.university,
      major: major ?? this.major,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      universityId: universityId ?? this.universityId,
      universityName: universityName ?? this.universityName,
      universityIsPending: universityIsPending ?? this.universityIsPending,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyIsPending: companyIsPending ?? this.companyIsPending,
      isPending: isPending ?? this.isPending,
    );
  }
}

